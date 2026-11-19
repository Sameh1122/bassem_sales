import express from 'express';
import { requireAuth, requireRoles, isAdminRole } from '../middleware/auth.js';
import {
  dbStore,
  saveDbStore,
  ensureFreshCloudSync,
  persistToBlobIfConfigured,
  ensureSyncStoreFields
} from '../services/storage.js';
import {
  filterRowsByTerritory,
  formatChillerRecord,
  getSupervisedAgentIdSet,
  canUserAccessChiller
} from '../services/chillerHelpers.js';
import {
  processFormResponseSubmission,
  applyConditionUpdate
} from '../services/syncOperations.js';

const router = express.Router();
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;

function pruneIdempotencyKeys(store, nowMs = Date.now()) {
  ensureSyncStoreFields(store);
  store.idempotency_keys = store.idempotency_keys.filter(entry => {
    const createdMs = Date.parse(entry?.createdAt || '');
    return Number.isFinite(createdMs) && (nowMs - createdMs) < IDEMPOTENCY_TTL_MS;
  });
}

function isAfterSince(timestampStr, sinceMs, isFullSync) {
  if (isFullSync) return true;
  if (!timestampStr) return true;
  const ts = Date.parse(timestampStr);
  if (Number.isNaN(ts)) return true;
  return ts > sinceMs;
}

// GET /api/sync/pull?since=<iso>
router.get('/pull', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();
  ensureSyncStoreFields(dbStore);

  const rawSince = typeof req.query.since === 'string' ? req.query.since.trim() : '';
  const isFullSync = rawSince.length === 0;
  let sinceMs = 0;
  let sinceIso = null;

  if (!isFullSync) {
    sinceMs = Date.parse(rawSince);
    if (Number.isNaN(sinceMs)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid since parameter: must be a valid ISO-8601 timestamp'
      });
    }
    sinceIso = new Date(sinceMs).toISOString();
  }

  // Capture cursor before filtering so clients never miss concurrent writes
  const serverTime = new Date().toISOString();

  const territoryChillers = filterRowsByTerritory(dbStore.chillers || [], req.user, dbStore);
  const chillers = territoryChillers
    .filter(r => isAfterSince(r.updated_at || r.condition_updated_at || r.created_at, sinceMs, isFullSync))
    .map(r => formatChillerRecord(r, dbStore));

  let forms = (dbStore.forms || []).filter(f => {
    if (req.user.role === 'agent') {
      const assigned = f.assigned_agent_ids || [];
      if (assigned.length > 0 && !assigned.includes(req.user.agentId)) {
        return false;
      }
    }
    return isAfterSince(f.updated_at || f.created_at, sinceMs, isFullSync);
  });

  let scopedAssignments = [];
  if (isAdminRole(req.user)) {
    scopedAssignments = dbStore.assignments || [];
  } else if (req.user.role === 'agent') {
    scopedAssignments = (dbStore.assignments || []).filter(as => as.agent_id === req.user.agentId);
  } else if (req.user.role === 'supervisor') {
    const supervisedSet = getSupervisedAgentIdSet(req.user);
    scopedAssignments = (dbStore.assignments || []).filter(as => {
      if (supervisedSet.has(Number(as.agent_id))) return true;
      const chiller = (dbStore.chillers || []).find(c =>
        (as.chiller_code && (c.chiller_code || c.chillerCode) === as.chiller_code) ||
        (as.customer_name && (c.customer_name || c.customerName || '').toLowerCase() === as.customer_name.toLowerCase())
      );
      return chiller ? canUserAccessChiller(chiller, req.user, dbStore) : false;
    });
  } else {
    scopedAssignments = [];
  }

  const assignments = scopedAssignments.filter(as =>
    isAfterSince(as.updated_at || as.assigned_at || as.created_at, sinceMs, isFullSync)
  );

  const tombstones = isFullSync
    ? { chillerCodes: [], formIds: [], assignmentIds: [] }
    : {
        chillerCodes: (dbStore.tombstones.chillers || [])
          .filter(t => isAfterSince(t.deletedAt, sinceMs, false))
          .map(t => t.id),
        formIds: (dbStore.tombstones.forms || [])
          .filter(t => isAfterSince(t.deletedAt, sinceMs, false))
          .map(t => t.id),
        assignmentIds: (dbStore.tombstones.assignments || [])
          .filter(t => isAfterSince(t.deletedAt, sinceMs, false))
          .map(t => t.id)
      };

  res.json({
    success: true,
    serverTime,
    since: sinceIso,
    isFullSync,
    counts: {
      chillers: chillers.length,
      forms: forms.length,
      assignments: assignments.length
    },
    chillers,
    forms,
    assignments,
    tombstones
  });
});

// POST /api/sync/batch
router.post(
  '/batch',
  requireAuth,
  requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'agent', 'technician'),
  async (req, res) => {
    await ensureFreshCloudSync();
    const nowMs = Date.now();
    pruneIdempotencyKeys(dbStore, nowMs);

    const headerKeyRaw = req.get('Idempotency-Key');
    const headerKey = typeof headerKeyRaw === 'string' && headerKeyRaw.trim()
      ? headerKeyRaw.trim().slice(0, 128)
      : null;

    if (headerKey) {
      const batchCompositeKey = `batch:${req.user.id}:${headerKey}`;
      const existingBatch = dbStore.idempotency_keys.find(
        k => k.key === batchCompositeKey && Number(k.userId) === Number(req.user.id)
      );
      if (existingBatch && existingBatch.result) {
        return res.status(existingBatch.statusCode || 200).json({
          ...existingBatch.result,
          deduplicated: true
        });
      }
    }

    const operations = req.body?.operations;
    if (!Array.isArray(operations) || operations.length === 0 || operations.length > 50) {
      return res.status(400).json({
        success: false,
        error: 'operations must be a non-empty array with 1 to 50 items'
      });
    }

    const results = [];
    let succeededCount = 0;
    let duplicateCount = 0;
    let failedCount = 0;

    for (let index = 0; index < operations.length; index++) {
      const op = operations[index];
      const rawType = typeof op?.type === 'string' ? op.type.trim().toLowerCase() : '';
      const itemKey = typeof op?.idempotencyKey === 'string' ? op.idempotencyKey.trim() : '';

      if (!itemKey || itemKey.length > 128) {
        failedCount++;
        results.push({
          index,
          type: rawType || 'unknown',
          idempotencyKey: itemKey || null,
          status: 'error',
          statusCode: 400,
          error: 'idempotencyKey is required (1..128 chars)'
        });
        continue;
      }

      const itemCompositeKey = `item:${req.user.id}:${itemKey}`;
      const existingItem = dbStore.idempotency_keys.find(
        k => k.key === itemCompositeKey && Number(k.userId) === Number(req.user.id)
      );
      if (existingItem) {
        duplicateCount++;
        results.push({
          index,
          type: rawType || existingItem.result?.type || 'unknown',
          idempotencyKey: itemKey,
          status: 'duplicate',
          statusCode: 200,
          resourceId: existingItem.result?.resourceId ?? null
        });
        continue;
      }

      if (rawType === 'form_response' || rawType === 'form-responses' || rawType === 'form-response') {
        const outcome = processFormResponseSubmission(dbStore, req.user, op.payload);
        if (outcome.ok) {
          succeededCount++;
          const itemResult = {
            index,
            type: 'form_response',
            idempotencyKey: itemKey,
            status: 'created',
            statusCode: 201,
            resourceId: outcome.response.id,
            checkInDistanceM: outcome.response.checkInDistanceM,
            geofenceVerified: outcome.response.geofenceVerified
          };
          results.push(itemResult);
          dbStore.idempotency_keys.push({
            key: itemCompositeKey,
            userId: req.user.id,
            createdAt: new Date().toISOString(),
            statusCode: 201,
            result: { type: 'form_response', resourceId: outcome.response.id }
          });
        } else {
          failedCount++;
          results.push({
            index,
            type: 'form_response',
            idempotencyKey: itemKey,
            status: 'error',
            statusCode: outcome.statusCode,
            error: outcome.error
          });
        }
      } else if (rawType === 'condition') {
        const targetId = op.payload?.chillerId ?? op.payload?.chiller_code ?? op.payload?.id;
        const outcome = applyConditionUpdate(dbStore, req.user, targetId, op.payload);
        if (outcome.ok) {
          succeededCount++;
          const resourceId = outcome.chiller.chiller_code || outcome.chiller.chillerCode || String(outcome.chiller.id);
          const itemResult = {
            index,
            type: 'condition',
            idempotencyKey: itemKey,
            status: 'updated',
            statusCode: 200,
            resourceId
          };
          results.push(itemResult);
          dbStore.idempotency_keys.push({
            key: itemCompositeKey,
            userId: req.user.id,
            createdAt: new Date().toISOString(),
            statusCode: 200,
            result: { type: 'condition', resourceId }
          });
        } else {
          failedCount++;
          results.push({
            index,
            type: 'condition',
            idempotencyKey: itemKey,
            status: 'error',
            statusCode: outcome.statusCode,
            error: outcome.error
          });
        }
      } else {
        failedCount++;
        results.push({
          index,
          type: rawType || 'unknown',
          idempotencyKey: itemKey,
          status: 'error',
          statusCode: 400,
          error: `Unsupported operation type: '${rawType || 'empty'}'`
        });
      }
    }

    const responseBody = {
      success: true,
      deduplicated: false,
      serverTime: new Date().toISOString(),
      processedCount: operations.length,
      succeededCount,
      duplicateCount,
      failedCount,
      results
    };

    if (headerKey) {
      dbStore.idempotency_keys.push({
        key: `batch:${req.user.id}:${headerKey}`,
        userId: req.user.id,
        createdAt: new Date().toISOString(),
        statusCode: 200,
        result: responseBody
      });
    }

    if (succeededCount > 0 || headerKey) {
      saveDbStore(dbStore);
      await persistToBlobIfConfigured(dbStore);
    }

    res.status(200).json(responseBody);
  }
);

export default router;
