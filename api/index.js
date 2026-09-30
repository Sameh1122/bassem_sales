import express from 'express';
import cors from 'cors';
import multer from 'multer';
import XLSXModule from 'xlsx';
import fs from 'fs';

const XLSX = XLSXModule.default || XLSXModule;

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

const storage = multer.memoryStorage();
const upload = multer({ storage });


// Default Columns Definitions
const DEFAULT_COLUMNS = [
  { id: 1, key_name: 'Branch', display_label: 'Branch', data_type: 'string', is_required: 0, is_active: 1, display_order: 1 },
  { id: 2, key_name: 'Received Date', display_label: 'Received Date', data_type: 'date', is_required: 0, is_active: 1, display_order: 2 },
  { id: 3, key_name: 'Chiller Type', display_label: 'Chiller Type', data_type: 'string', is_required: 0, is_active: 1, display_order: 3 },
  { id: 4, key_name: 'Chiller Configuration', display_label: 'Chiller Configuration', data_type: 'string', is_required: 0, is_active: 1, display_order: 4 },
  { id: 5, key_name: 'Chiller Code', display_label: 'Chiller Code', data_type: 'string', is_required: 1, is_active: 1, display_order: 5 },
  { id: 6, key_name: 'Chiller Status', display_label: 'Chiller Status', data_type: 'string', is_required: 0, is_active: 1, display_order: 6 },
  { id: 7, key_name: 'Condiiton', display_label: 'Condition', data_type: 'string', is_required: 0, is_active: 1, display_order: 7 },
  { id: 8, key_name: 'Action Date', display_label: 'Action Date', data_type: 'date', is_required: 0, is_active: 1, display_order: 8 },
  { id: 9, key_name: 'Serial Number', display_label: 'Serial Number', data_type: 'string', is_required: 0, is_active: 1, display_order: 9 },
  { id: 10, key_name: 'Longitude', display_label: 'Longitude', data_type: 'coords', is_required: 1, is_active: 1, display_order: 10 },
  { id: 11, key_name: 'Latitude', display_label: 'Latitude', data_type: 'coords', is_required: 1, is_active: 1, display_order: 11 },
  { id: 12, key_name: 'Truck Code', display_label: 'Truck Code', data_type: 'string', is_required: 0, is_active: 1, display_order: 12 },
  { id: 13, key_name: 'SR Name', display_label: 'SR Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 13 },
  { id: 14, key_name: 'SSV Name', display_label: 'SSV Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 14 },
  { id: 15, key_name: 'Customer Type', display_label: 'Customer Type', data_type: 'string', is_required: 1, is_active: 1, display_order: 15 },
  { id: 16, key_name: 'Visit Day', display_label: 'Visit Day', data_type: 'string', is_required: 0, is_active: 1, display_order: 16 },
  { id: 17, key_name: 'Customer Code', display_label: 'Customer Code', data_type: 'string', is_required: 0, is_active: 1, display_order: 17 },
  { id: 18, key_name: 'Customer Name', display_label: 'Customer Name', data_type: 'string', is_required: 0, is_active: 1, display_order: 18 },
  { id: 19, key_name: 'Customer Address', display_label: 'Customer Address', data_type: 'string', is_required: 0, is_active: 1, display_order: 19 },
  { id: 20, key_name: 'Mobile Number', display_label: 'Mobile Number', data_type: 'string', is_required: 0, is_active: 1, display_order: 20 },
  { id: 21, key_name: 'Jan 2026 Invoice', display_label: 'Jan 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 21 },
  { id: 22, key_name: 'Feb 2026 Invoice', display_label: 'Feb 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 22 },
  { id: 23, key_name: 'Mar 2026 Invoice', display_label: 'Mar 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 23 },
  { id: 24, key_name: 'Apr 2026 Invoice', display_label: 'Apr 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 24 },
  { id: 25, key_name: 'May 2026 Invoice', display_label: 'May 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 25 },
  { id: 26, key_name: 'June 2026 Invoice', display_label: 'June 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 26 },
  { id: 27, key_name: 'July 2026 Invoice', display_label: 'July 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 27 },
  { id: 28, key_name: 'Aug 2026 Invoice', display_label: 'Aug 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 28 },
  { id: 29, key_name: 'Sep 2026 Invoice', display_label: 'Sep 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 29 },
  { id: 30, key_name: 'Oct 2026 Invoice', display_label: 'Oct 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 30 },
  { id: 31, key_name: 'Nov 2026 Invoice', display_label: 'Nov 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 31 },
  { id: 32, key_name: 'Dec 2026 Invoice', display_label: 'Dec 2026 Invoice', data_type: 'number', is_required: 0, is_active: 1, display_order: 32 },
  { id: 33, key_name: 'YTD', display_label: 'YTD', data_type: 'number', is_required: 0, is_active: 1, display_order: 33 },
  { id: 34, key_name: 'Average / Month', display_label: 'Average / Month', data_type: 'number', is_required: 0, is_active: 1, display_order: 34 },
  { id: 35, key_name: 'Month Ach. Status', display_label: 'Efficiency (Month Ach. Status)', data_type: 'string', is_required: 1, is_active: 1, display_order: 35 },
  { id: 36, key_name: 'Notes', display_label: 'Notes', data_type: 'string', is_required: 0, is_active: 1, display_order: 36 }
];

let dbStore = {
  columns: [...DEFAULT_COLUMNS],
  batches: [],
  chillers: [],
  history: []
};

function cleanStr(val) {
  if (val === null || val === undefined) return '';
  const s = String(val).trim();
  if (s === '-' || s === 'None' || s === 'null' || s === 'undefined' || s === '#N/A') return '';
  return s;
}

function parseCoords(latColVal, lngColVal) {
  let num1 = parseFloat(cleanStr(latColVal));
  let num2 = parseFloat(cleanStr(lngColVal));

  if (isNaN(num1) || isNaN(num2)) {
    return { lat: null, lng: null, isValid: false, reason: 'Invalid or missing numbers' };
  }

  let lat, lng;
  if (num1 > num2) {
    lat = num2; // Cairo Lat (~30.09° N)
    lng = num1; // Cairo Lng (~31.32° E)
  } else {
    lat = num2; // Alex Lat (~31.32° N)
    lng = num1; // Alex Lng (~30.09° E)
  }

  if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
    return { lat, lng, isValid: true };
  }

  return { lat: null, lng: null, isValid: false, reason: 'Coordinates out of bounds' };
}

function parseExcelBuffer(buffer) {
  const workbook = XLSX.read(buffer, { type: 'buffer', cellDates: true, cellText: false });
  const activeColumns = dbStore.columns.filter(c => c.is_active === 1);
  const requiredKeys = activeColumns.filter(c => c.is_required === 1).map(c => c.key_name);

  let sheetName = workbook.SheetNames.find(s => s === 'CE_Database' || s === 'CW_Database') || workbook.SheetNames[0];
  const worksheet = workbook.Sheets[sheetName];
  const rawRows = XLSX.utils.sheet_to_json(worksheet, { defval: null });

  const parsedRows = [];
  let validCount = 0;
  let invalidCount = 0;

  rawRows.forEach((row, idx) => {
    const rowObj = {};
    const missingFields = [];
    const errors = [];

    Object.keys(row).forEach(key => {
      if (key && !key.startsWith('__EMPTY')) {
        const val = row[key];
        rowObj[key] = val instanceof Date ? val.toISOString().split('T')[0] : (val !== null && val !== undefined ? String(val).trim() : '');
      }
    });

    for (const reqKey of requiredKeys) {
      const cellVal = cleanStr(rowObj[reqKey]);
      if (!cellVal) {
        missingFields.push(reqKey);
        errors.push(`Missing required field: '${reqKey}'`);
      }
    }

    for (const col of activeColumns) {
      const cellVal = cleanStr(rowObj[col.key_name]);
      if (!cellVal && !missingFields.includes(col.key_name)) {
        missingFields.push(col.key_name);
      }
    }

    const latColVal = rowObj['Latitude'] || rowObj['lat'] || rowObj['LATITUDE'];
    const lngColVal = rowObj['Longitude'] || rowObj['lng'] || rowObj['LONGITUDE'];
    const coordCheck = parseCoords(latColVal, lngColVal);

    if (!coordCheck.isValid) {
      errors.push('Missing or invalid GPS Latitude/Longitude coordinates');
    }

    const isValid = errors.length === 0;
    if (isValid) validCount++;
    else invalidCount++;

    parsedRows.push({
      rowIndex: idx + 2,
      chillerCode: rowObj['Chiller Code'] || `CH-${idx + 1}`,
      latitude: coordCheck.lat,
      longitude: coordCheck.lng,
      customerType: rowObj['Customer Type'] || 'Retail',
      efficiency: rowObj['Month Ach. Status'] || 'Non-Performing',
      branch: rowObj['Branch'] || '',
      chillerType: rowObj['Chiller Type'] || '',
      chillerStatus: rowObj['Chiller Status'] || '',
      condition: rowObj['Condiiton'] || rowObj['Condition'] || '',
      customerName: rowObj['Customer Name'] || '',
      customerAddress: rowObj['Customer Address'] || '',
      mobileNumber: rowObj['Mobile Number'] || '',
      rowObj,
      isValid,
      missingFields,
      errors
    });
  });

  return {
    sheetName,
    totalRows: parsedRows.length,
    validCount,
    invalidCount,
    rows: parsedRows
  };
}

const router = express.Router();

router.get('/columns', (req, res) => {
  res.json({ success: true, columns: dbStore.columns });
});

router.post('/columns', (req, res) => {
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
  res.json({ success: true, message: `Column '${display_label}' added successfully` });
});

router.post('/columns/toggle', (req, res) => {
  const { id, is_active, is_required } = req.body;
  const col = dbStore.columns.find(c => c.id === id);
  if (col) {
    if (is_active !== undefined) col.is_active = is_active ? 1 : 0;
    if (is_required !== undefined) col.is_required = is_required ? 1 : 0;
  }
  res.json({ success: true, message: 'Column updated successfully' });
});

router.post('/excel/parse', (req, res) => {
  upload.single('file')(req, res, (err) => {
    try {
      let buffer = null;
      let filename = 'Uploaded_Sheet.xlsx';

      if (req.file) {
        filename = req.file.originalname;
        buffer = req.file.buffer || (req.file.path && fs.existsSync(req.file.path) ? fs.readFileSync(req.file.path) : null);
      } else if (req.body && req.body.fileBase64) {
        buffer = Buffer.from(req.body.fileBase64, 'base64');
        if (req.body.filename) filename = req.body.filename;
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

router.get('/excel/scratch-sample', (req, res) => {
  try {
    const scratchPath = 'C:\\Users\\skamal\\.gemini\\antigravity\\scratch\\Bassem\\Chillers Database_V1.xlsx';
    if (fs.existsSync(scratchPath)) {
      const buffer = fs.readFileSync(scratchPath);
      const result = parseExcelBuffer(buffer);
      return res.json({ success: true, filename: 'Chillers Database_V1.xlsx', ...result });
    }
    res.status(404).json({ success: false, error: 'Sample file not available on cloud instance. Please upload custom .xlsx file.' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/excel/confirm', (req, res) => {
  const { filename = 'Uploaded_Sheet.xlsx', rows = [], bypassValidation = false } = req.body;
  const rowsToSave = bypassValidation ? rows : rows.filter(r => r.isValid);
  const batchId = dbStore.batches.length + 1;

  dbStore.batches.push({
    id: batchId,
    filename,
    total_rows: rows.length,
    valid_rows: rows.filter(r => r.isValid).length,
    invalid_rows: rows.length - rows.filter(r => r.isValid).length,
    bypassed_validation: bypassValidation ? 1 : 0,
    uploaded_at: new Date().toISOString()
  });

  for (const r of rowsToSave) {
    const code = r.chillerCode || `CH-${Math.random().toString(36).substring(7)}`;
    const existingIdx = dbStore.chillers.findIndex(c => c.chiller_code === code);
    const item = {
      id: existingIdx >= 0 ? dbStore.chillers[existingIdx].id : dbStore.chillers.length + 1,
      chiller_code: code,
      batch_id: batchId,
      latitude: r.latitude,
      longitude: r.longitude,
      customer_type: r.customerType,
      efficiency: r.efficiency,
      branch: r.branch,
      chiller_type: r.chillerType,
      chiller_status: r.chillerStatus,
      condition: r.condition,
      customer_name: r.customerName,
      raw_data_json: JSON.stringify(r.rowObj || {}),
      updated_at: new Date().toISOString()
    };
    if (existingIdx >= 0) dbStore.chillers[existingIdx] = item;
    else dbStore.chillers.push(item);

    dbStore.history.push({ ...item, id: dbStore.history.length + 1, snapshot_time: new Date().toISOString() });
  }

  res.json({
    success: true,
    batchId,
    savedRowsCount: rowsToSave.length,
    message: `Successfully saved ${rowsToSave.length} records into database.`
  });
});

router.get('/chillers', (req, res) => {
  const { efficiency, customerType, search } = req.query;
  let rows = [...dbStore.chillers];

  if (efficiency && efficiency !== 'All') {
    rows = rows.filter(r => (r.efficiency || '').toLowerCase() === efficiency.toLowerCase());
  }

  if (customerType && customerType !== 'All') {
    rows = rows.filter(r => (r.customer_type || '').toLowerCase() === customerType.toLowerCase());
  }

  if (search) {
    const term = search.toLowerCase();
    rows = rows.filter(r =>
      (r.chiller_code || '').toLowerCase().includes(term) ||
      (r.customer_name || '').toLowerCase().includes(term) ||
      (r.branch || '').toLowerCase().includes(term)
    );
  }

  const chillers = rows.map(r => ({
    id: r.id,
    chillerCode: r.chiller_code,
    batchId: r.batch_id,
    latitude: r.latitude,
    longitude: r.longitude,
    customerType: r.customer_type,
    efficiency: r.efficiency,
    branch: r.branch,
    chillerType: r.chiller_type,
    chillerStatus: r.chiller_status,
    condition: r.condition,
    customerName: r.customer_name,
    rawData: JSON.parse(r.raw_data_json || '{}')
  }));

  res.json({ success: true, count: chillers.length, chillers });
});

router.delete('/chillers/clear', (req, res) => {
  dbStore.chillers = [];
  res.json({ success: true, message: 'All active database records cleared' });
});

router.get('/batches', (req, res) => {
  res.json({ success: true, batches: [...dbStore.batches].reverse() });
});

router.get('/delta', (req, res) => {
  const { startBatchId, endBatchId } = req.query;
  const startId = parseInt(startBatchId);
  const endId = parseInt(endBatchId);

  const startSnapshot = dbStore.history.filter(h => h.batch_id === startId);
  const endSnapshot = dbStore.history.filter(h => h.batch_id === endId);

  const startMap = new Map(startSnapshot.map(item => [item.chiller_code, item]));
  const endMap = new Map(endSnapshot.map(item => [item.chiller_code, item]));

  const added = [];
  const removed = [];
  const modified = [];

  for (const [code, item] of endMap.entries()) {
    if (!startMap.has(code)) {
      added.push(item);
    } else {
      const prev = startMap.get(code);
      if (prev.efficiency !== item.efficiency || prev.latitude !== item.latitude || prev.longitude !== item.longitude || prev.branch !== item.branch) {
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

import path from 'path';

app.use(express.static('public'));
app.use(express.static('frontend/build/web'));

app.use('/api', router);
app.use('/', router);

app.use((req, res) => {
  res.status(404).json({ success: false, error: `API endpoint '${req.url}' not found` });
});

export default (req, res) => {
  return app(req, res);
};



