import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { requireAuth, requireAdmin } from '../middleware/auth.js';
import { upload, parseExcelBuffer } from '../services/excel.js';
import {
  dbStore,
  saveDbStore,
  persistToBlobIfConfigured,
  isCloudStorageConfigured,
  getHasSyncedWithCloud,
  syncWithCloudStorage,
  ensureFreshCloudSync
} from '../services/storage.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

router.post('/excel/parse', requireAdmin, (req, res) => {
  upload.single('file')(req, res, (err) => {
    try {
      if (err) {
        return res.status(400).json({ success: false, error: err.message || 'File upload error' });
      }

      let buffer = null;
      let filename = 'Uploaded_Sheet.xlsx';

      if (req.file) {
        filename = path.basename(req.file.originalname).replace(/[^a-zA-Z0-9_\-\.\u0600-\u06FF]/g, '_');
        buffer = req.file.buffer || (req.file.path && fs.existsSync(req.file.path) ? fs.readFileSync(req.file.path) : null);
      } else if (req.body && req.body.fileBase64) {
        buffer = Buffer.from(req.body.fileBase64, 'base64');
        if (req.body.filename) {
          filename = path.basename(req.body.filename).replace(/[^a-zA-Z0-9_\-\.\u0600-\u06FF]/g, '_');
        }
      }

      if (!buffer) {
        return res.status(400).json({ success: false, error: 'No Excel file provided' });
      }

      const result = parseExcelBuffer(buffer);
      res.json({ success: true, filename, ...result });
    } catch (e) {
      res.status(500).json({ success: false, error: e.message });
    }
  });
});

router.get('/excel/scratch-sample', requireAdmin, (req, res) => {
  try {
    const candidatePaths = [
      path.resolve('api/sample_chillers.xlsx'),
      path.join(__dirname, '..', 'sample_chillers.xlsx'),
      path.resolve('public/sample_chillers.xlsx'),
      path.resolve('sample_chillers.xlsx')
    ];
    const foundPath = candidatePaths.find(p => fs.existsSync(p));
    if (foundPath) {
      const buffer = fs.readFileSync(foundPath);
      const result = parseExcelBuffer(buffer);
      return res.json({ success: true, filename: 'sample_chillers.xlsx', ...result });
    }
    res.status(404).json({ success: false, error: 'Sample file not found. Please upload a custom .xlsx file.' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/excel/confirm', requireAdmin, async (req, res) => {
  if (isCloudStorageConfigured() && !getHasSyncedWithCloud()) {
    await syncWithCloudStorage();
  }
  const { filename = 'Uploaded_Sheet.xlsx', rows = [], bypassValidation = false, onlyThisBatch = false } = req.body || {};
  const rowsToSave = bypassValidation
    ? rows
    : rows.filter(r => r.isValid !== false || (r.latitude != null && r.longitude != null));

  const isOnlyBatch = Boolean(onlyThisBatch);
  const existingBatchIds = (dbStore.batches || []).map(b => Number(b.id) || 0);
  const batchId = existingBatchIds.length > 0 ? Math.max(...existingBatchIds) + 1 : 1;

  dbStore.batches.push({
    id: batchId,
    filename,
    total_rows: rows.length,
    valid_rows: rowsToSave.length,
    invalid_rows: rows.length - rowsToSave.length,
    bypassed_validation: bypassValidation ? 1 : 0,
    only_this_batch: isOnlyBatch ? 1 : 0,
    uploaded_at: new Date().toISOString()
  });

  if (isOnlyBatch) {
    dbStore.chillers = [];
  }

  // Master Dataset is incremental (UPSERT) unless onlyThisBatch is true
  let addedCount = 0;
  let updatedCount = 0;
  const maxChillerId = (dbStore.chillers || []).reduce((max, c) => Math.max(max, Number(c.id) || 0), 0);

  for (const r of rowsToSave) {
    const rawCode = (r.chillerCode || r['Chiller Code'] || '').toString().trim();
    const code = rawCode || `CH-${Math.random().toString(36).substring(7)}`;
    const lowerCode = code.toLowerCase();

    const existingIdx = dbStore.chillers.findIndex(c => {
      const existingCode = (c.chiller_code || c.chillerCode || '').toString().trim().toLowerCase();
      return existingCode === lowerCode;
    });

    const item = {
      id: existingIdx >= 0 ? dbStore.chillers[existingIdx].id : maxChillerId + addedCount + 1,
      chiller_code: code,
      batch_id: batchId,
      latitude: r.latitude != null ? Number(r.latitude) : (existingIdx >= 0 ? dbStore.chillers[existingIdx].latitude : null),
      longitude: r.longitude != null ? Number(r.longitude) : (existingIdx >= 0 ? dbStore.chillers[existingIdx].longitude : null),
      customer_type: r.customerType || (existingIdx >= 0 ? dbStore.chillers[existingIdx].customer_type : 'Retail'),
      efficiency: r.efficiency || (existingIdx >= 0 ? dbStore.chillers[existingIdx].efficiency : 'Performing'),
      branch: r.branch || (existingIdx >= 0 ? dbStore.chillers[existingIdx].branch : ''),
      chiller_type: r.chillerType || (existingIdx >= 0 ? dbStore.chillers[existingIdx].chiller_type : ''),
      chiller_status: r.chillerStatus || (existingIdx >= 0 ? dbStore.chillers[existingIdx].chiller_status : 'Deployed'),
      condition: r.condition || (existingIdx >= 0 ? dbStore.chillers[existingIdx].condition : ''),
      customer_name: r.customerName || (existingIdx >= 0 ? dbStore.chillers[existingIdx].customer_name : ''),
      customer_address: r.customerAddress || (existingIdx >= 0 ? (dbStore.chillers[existingIdx].customer_address || '') : ''),
      mobile_number: r.mobileNumber || (existingIdx >= 0 ? (dbStore.chillers[existingIdx].mobile_number || '') : ''),
      raw_data_json: typeof (r.rowObj || r.rawData) === 'object' ? JSON.stringify(r.rowObj || r.rawData || {}) : String(r.rowObj || r.rawData || '{}'),
      updated_at: new Date().toISOString()
    };

    if (existingIdx >= 0) {
      dbStore.chillers[existingIdx] = { ...dbStore.chillers[existingIdx], ...item };
      updatedCount++;
    } else {
      dbStore.chillers.push(item);
      addedCount++;
    }

    dbStore.history.push({ ...item, id: dbStore.history.length + 1, snapshot_time: new Date().toISOString() });
  }

  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);

  const formattedChillers = dbStore.chillers.map(r => ({
    id: r.id,
    chillerCode: r.chiller_code || r.chillerCode,
    batchId: r.batch_id || r.batchId,
    latitude: r.latitude,
    longitude: r.longitude,
    customerType: r.customer_type || r.customerType,
    efficiency: r.efficiency,
    branch: r.branch,
    chillerType: r.chiller_type || r.chillerType,
    chillerStatus: r.chiller_status || r.chillerStatus,
    condition: r.condition,
    customerName: r.customer_name || r.customerName,
    rawData: typeof r.raw_data_json === 'string' ? JSON.parse(r.raw_data_json || '{}') : (r.rawData || r.raw_data_json || {})
  }));

  res.json({
    success: true,
    batchId,
    savedRowsCount: rowsToSave.length,
    addedCount,
    updatedCount,
    totalActiveChillers: dbStore.chillers.length,
    chillers: formattedChillers,
    message: `Master dataset successfully incremented: ${addedCount} new chillers added, ${updatedCount} chillers updated. Total active chillers: ${dbStore.chillers.length}.`
  });
});

// POST /admin/clear-all-batches - Wipe all uploaded batches, chillers, and history
router.post(['/admin/clear-all-batches', '/batches/clear-all'], requireAdmin, async (req, res) => {
  if (isCloudStorageConfigured() && !getHasSyncedWithCloud()) {
    try {
      await syncWithCloudStorage();
    } catch (_) {}
  }
  const deletedBatches = (dbStore.batches || []).length;
  const deletedChillers = (dbStore.chillers || []).length;
  dbStore.batches = [];
  dbStore.chillers = [];
  dbStore.history = [];
  saveDbStore(dbStore);
  await persistToBlobIfConfigured(dbStore);
  res.json({
    success: true,
    message: `Database successfully cleared of all uploaded batches (${deletedBatches}) and chillers (${deletedChillers}).`,
    batchesCount: 0,
    chillersCount: 0
  });
});

router.get('/batches', requireAuth, async (req, res) => {
  await ensureFreshCloudSync();
  const batches = dbStore.batches || [];
  res.json({ success: true, batches: [...batches].reverse() });
});

// Permanently disable batch deletion
router.delete('/batches/:id', requireAdmin, (req, res) => {
  return res.status(403).json({
    success: false,
    error: 'Batch deletion is permanently disabled. Uploaded batches cannot be deleted.'
  });
});

router.get('/delta', requireAdmin, (req, res) => {
  const { startBatchId, endBatchId } = req.query;
  if (startBatchId === undefined || startBatchId === null || endBatchId === undefined || endBatchId === null) {
    return res.status(400).json({ success: false, error: 'startBatchId and endBatchId query parameters are required' });
  }

  const startId = parseInt(startBatchId);
  const endId = parseInt(endBatchId);
  if (isNaN(startId) || isNaN(endId)) {
    return res.status(400).json({ success: false, error: 'startBatchId and endBatchId must be valid integers' });
  }

  const startBatch = (dbStore.batches || []).find(b => b.id === startId);
  const endBatch = (dbStore.batches || []).find(b => b.id === endId);
  if (!startBatch || !endBatch) {
    const missing = [];
    if (!startBatch) missing.push(`startBatchId (${startId})`);
    if (!endBatch) missing.push(`endBatchId (${endId})`);
    return res.status(404).json({ success: false, error: `Batch not found: ${missing.join(', ')}` });
  }

  const startSnapshot = (dbStore.history || []).filter(h => (h.batch_id || h.batchId) === startId);
  const endSnapshot = (dbStore.history || []).filter(h => (h.batch_id || h.batchId) === endId);

  const startMap = new Map(startSnapshot.map(item => [item.chiller_code || item.chillerCode, item]));
  const endMap = new Map(endSnapshot.map(item => [item.chiller_code || item.chillerCode, item]));

  const added = [];
  const removed = [];
  const modified = [];

  for (const [code, item] of endMap.entries()) {
    if (!startMap.has(code)) {
      added.push(item);
    } else {
      const prev = startMap.get(code);
      const isModified =
        prev.efficiency !== item.efficiency ||
        prev.latitude !== item.latitude ||
        prev.longitude !== item.longitude ||
        prev.branch !== item.branch ||
        (prev.customer_name || prev.customerName || '') !== (item.customer_name || item.customerName || '') ||
        (prev.customer_type || prev.customerType || '') !== (item.customer_type || item.customerType || '') ||
        (prev.condition || '') !== (item.condition || '') ||
        (prev.chiller_status || prev.chillerStatus || '') !== (item.chiller_status || item.chillerStatus || '') ||
        (prev.customer_address || prev.customerAddress || '') !== (item.customer_address || item.customerAddress || '') ||
        (prev.mobile_number || prev.mobileNumber || '') !== (item.mobile_number || item.mobileNumber || '') ||
        JSON.stringify(prev.raw_data_json || prev.rawData || {}) !== JSON.stringify(item.raw_data_json || item.rawData || {});

      if (isModified) {
        modified.push({ previous: prev, current: item });
      }
    }
  }

  for (const [code, item] of startMap.entries()) {
    if (!endMap.has(code)) {
      removed.push(item);
    }
  }

  res.json({
    success: true,
    startBatchId: startId,
    endBatchId: endId,
    summary: {
      added: added.length,
      removed: removed.length,
      modified: modified.length
    },
    added,
    removed,
    modified
  });
});

export default router;
