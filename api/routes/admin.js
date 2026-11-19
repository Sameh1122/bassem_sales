import express from 'express';
import auditLogger from '../audit_logger.js';
import { requireAuth, requireAdmin, requireOwner } from '../middleware/auth.js';
import { getClientIp } from '../utils/security.js';
import {
  dbStore,
  saveDbStore,
  persistToBlobIfConfigured,
  isCloudStorageConfigured,
  getHasSyncedWithCloud,
  getLastCloudSyncTime,
  syncWithCloudStorage,
  reconcileMasterDataset
} from '../services/storage.js';

const router = express.Router();

// ==========================================
// System Audit Logs Endpoints (Owner only)
// ==========================================

router.get('/logs/status', requireOwner, (req, res) => {
  res.json({
    success: true,
    enabled: auditLogger.isEnabled()
  });
});

router.post('/logs/toggle', requireOwner, (req, res) => {
  const { enabled } = req.body;
  if (typeof enabled !== 'boolean') {
    return res.status(400).json({ success: false, error: 'Field "enabled" must be a boolean (true/false)' });
  }

  const newState = auditLogger.setEnabled(enabled);

  // Force-log this configuration change so Owner action is permanently registered
  auditLogger.log({
    level: 'WARN',
    category: 'system',
    action: newState ? 'LOGGING_STARTED' : 'LOGGING_STOPPED',
    actor: {
      id: req.user.id,
      email: req.user.email,
      username: req.user.username,
      role: req.user.role,
      ip: getClientIp(req)
    },
    method: 'POST',
    endpoint: '/api/logs/toggle',
    statusCode: 200,
    details: `System Action Logging ${newState ? 'STARTED / RESUMED' : 'STOPPED / PAUSED'} by Owner (${req.user.email})`,
    force: true
  });

  res.json({
    success: true,
    enabled: newState,
    message: `System action logging ${newState ? 'resumed' : 'paused'} successfully`
  });
});

router.get('/logs', requireOwner, (req, res) => {
  const { level, category, search, statusCode, page = 1, limit = 50 } = req.query;
  const result = auditLogger.getLogs({
    level,
    category,
    search,
    statusCode,
    page: parseInt(page) || 1,
    limit: parseInt(limit) || 50
  });
  res.json({
    success: true,
    loggingEnabled: auditLogger.isEnabled(),
    ...result
  });
});

router.delete('/logs', requireOwner, (req, res) => {
  auditLogger.clear();
  auditLogger.log({
    level: 'WARN',
    category: 'system',
    action: 'CLEAR_AUDIT_LOGS',
    actor: {
      id: req.user.id,
      email: req.user.email,
      username: req.user.username,
      role: req.user.role,
      ip: getClientIp(req)
    },
    method: 'DELETE',
    endpoint: '/api/logs',
    statusCode: 200,
    details: `Audit logs cleared by Owner (${req.user.email})`
  });
  res.json({ success: true, message: 'All system logs cleared successfully' });
});

router.get('/logs/export', requireOwner, (req, res) => {
  const format = req.query.format === 'csv' ? 'csv' : 'json';
  const exported = auditLogger.export(format);
  if (format === 'csv') {
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="audit_logs_${Date.now()}.csv"`);
    return res.send(exported);
  }
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename="audit_logs_${Date.now()}.json"`);
  res.send(exported);
});

// ==========================================
// Health & Diagnostics
// ==========================================

router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '2.5.0',
    storage: {
      type: isCloudStorageConfigured() ? 'Vercel Blob (Persistent Cloud)' : 'Local Disk',
      cloudSync: getHasSyncedWithCloud(),
      lastSync: getLastCloudSyncTime() ? new Date(getLastCloudSyncTime()).toISOString() : null,
      chillersCount: (dbStore.chillers || []).length,
      batchesCount: (dbStore.batches || []).length,
      blobConfigured: isCloudStorageConfigured()
    },
    timestamp: new Date().toISOString()
  });
});

router.get('/admin/diagnostics', requireAdmin, (req, res) => {
  res.json({
    status: 'ok',
    version: '2.5.0',
    storage: {
      type: isCloudStorageConfigured() ? 'Vercel Blob (Persistent Cloud)' : 'Local Disk',
      cloudSync: getHasSyncedWithCloud(),
      lastSync: getLastCloudSyncTime() ? new Date(getLastCloudSyncTime()).toISOString() : null,
      chillersCount: (dbStore.chillers || []).length,
      batchesCount: (dbStore.batches || []).length,
      blobConfigured: isCloudStorageConfigured(),
      hasBlobToken: Boolean(process.env.BLOB_READ_WRITE_TOKEN)
    },
    usersCount: (dbStore.users || []).length,
    users: (dbStore.users || []).map(u => ({ email: u.email, role: u.role, name: u.name, username: u.username })),
    timestamp: new Date().toISOString()
  });
});

// ==========================================
// Columns Management
// ==========================================

router.get('/columns', requireAuth, (req, res) => {
  res.json({ success: true, columns: dbStore.columns });
});

router.post('/columns', requireAdmin, async (req, res) => {
  const { key_name, display_label, data_type = 'string', is_required = 0, is_active = 1 } = req.body;
  const newCol = {
    id: dbStore.columns.length + 1,
    key_name,
    display_label,
    data_type,
    is_required: is_required ? 1 : 0,
    is_active: is_active ? 1 : 0,
    display_order: dbStore.columns.length + 1
  };
  dbStore.columns.push(newCol);
  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);
  res.json({ success: true, message: `Column '${display_label}' added successfully` });
});

router.post('/columns/toggle', requireAdmin, async (req, res) => {
  const { id, is_active, is_required } = req.body;
  const col = dbStore.columns.find(c => c.id === id);
  if (col) {
    if (is_active !== undefined) col.is_active = is_active ? 1 : 0;
    if (is_required !== undefined) col.is_required = is_required ? 1 : 0;
    saveDbStore(dbStore);
    await persistToBlobIfConfigured(dbStore);
  }
  res.json({ success: true, message: 'Column updated successfully' });
});

// ==========================================
// Master Dataset Recovery
// ==========================================

router.post('/admin/restore-master-dataset', requireAdmin, async (req, res) => {
  if (isCloudStorageConfigured() && !getHasSyncedWithCloud()) {
    try {
      await syncWithCloudStorage();
    } catch (_) {}
  }
  const restored = reconcileMasterDataset(dbStore);
  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);
  res.json({
    success: true,
    restored,
    chillersCount: dbStore.chillers.length,
    message: `Master dataset contains ${dbStore.chillers.length} active chillers.`
  });
});

export default router;
