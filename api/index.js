import express from 'express';
import cors from 'cors';
import multer from 'multer';
import XLSXModule from 'xlsx';
import fs from 'fs';
import path from 'path';

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

import os from 'os';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DB_FILE = process.env.VERCEL ? '/tmp/chillers_db.json' : path.resolve(os.tmpdir(), 'chillers_db.json');

function loadDbStore() {
  try {
    if (fs.existsSync(DB_FILE)) {
      const content = fs.readFileSync(DB_FILE, 'utf8');
      const parsed = JSON.parse(content);
      if (parsed && Array.isArray(parsed.chillers) && parsed.chillers.length > 0) {
        if (!Array.isArray(parsed.agents) || parsed.agents.length === 0) {
          parsed.agents = [
            { id: 1, name: 'Ahmed Hassan', area: 'Cairo East (Nasr City, New Cairo)', phone: '+20 100 123 4567', email: 'ahmed.hassan@example.com', created_at: new Date().toISOString() },
            { id: 2, name: 'Mahmoud Ali', area: 'Giza & 6th of October', phone: '+20 101 234 5678', email: 'mahmoud.ali@example.com', created_at: new Date().toISOString() },
            { id: 3, name: 'Karim Mostafa', area: 'Alexandria & Coastal', phone: '+20 102 345 6789', email: 'karim.m@example.com', created_at: new Date().toISOString() },
            { id: 4, name: 'Tarek Ibrahim', area: 'Delta (Delta/Tanta)', phone: '+20 103 456 7890', email: 'tarek.i@example.com', created_at: new Date().toISOString() }
          ];
        }
        if (!Array.isArray(parsed.assignments)) {
          parsed.assignments = [];
        }
        return parsed;
      }
    }
  } catch (e) {
    console.warn('⚠️ Error reading persistent DB file:', e.message);
  }

  let store = {
    columns: [...DEFAULT_COLUMNS],
    batches: [],
    chillers: [],
    history: [],
    agents: [
      { id: 1, name: 'Ahmed Hassan', area: 'Cairo East (Nasr City, New Cairo)', phone: '+20 100 123 4567', email: 'ahmed.hassan@example.com', created_at: new Date().toISOString() },
      { id: 2, name: 'Mahmoud Ali', area: 'Giza & 6th of October', phone: '+20 101 234 5678', email: 'mahmoud.ali@example.com', created_at: new Date().toISOString() },
      { id: 3, name: 'Karim Mostafa', area: 'Alexandria & Coastal', phone: '+20 102 345 6789', email: 'karim.m@example.com', created_at: new Date().toISOString() },
      { id: 4, name: 'Tarek Ibrahim', area: 'Delta (Tanta, Mansoura)', phone: '+20 103 456 7890', email: 'tarek.i@example.com', created_at: new Date().toISOString() }
    ],
    assignments: []
  };

  try {
    const candidateSeedPaths = [
      path.join(__dirname, 'seedData.json'),
      path.resolve('api/seedData.json'),
      path.resolve('seedData.json'),
      path.join(process.cwd(), 'api/seedData.json')
    ];
    const seedPath = candidateSeedPaths.find(p => fs.existsSync(p));
    if (seedPath) {
      console.log('📦 Loading seedData from:', seedPath);
      const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
      if (seed.columns && seed.columns.length > 0) store.columns = seed.columns;
      if (seed.batches && seed.batches.length > 0) store.batches = seed.batches;
      if (seed.chillers && seed.chillers.length > 0) store.chillers = seed.chillers;
      if (seed.history && seed.history.length > 0) store.history = seed.history;
      if (seed.agents && seed.agents.length > 0) store.agents = seed.agents;
      if (seed.assignments && seed.assignments.length > 0) store.assignments = seed.assignments;
      console.log(`✅ Loaded ${store.chillers.length} initial chillers from seedData`);
    }
  } catch (err) {
    console.warn('⚠️ Could not load seedData:', err.message);
  }

  if (!Array.isArray(store.agents)) {
    store.agents = [
      { id: 1, name: 'Ahmed Hassan', area: 'Cairo East (Nasr City, New Cairo)', phone: '+20 100 123 4567', email: 'ahmed.hassan@example.com', created_at: new Date().toISOString() },
      { id: 2, name: 'Mahmoud Ali', area: 'Giza & 6th of October', phone: '+20 101 234 5678', email: 'mahmoud.ali@example.com', created_at: new Date().toISOString() },
      { id: 3, name: 'Karim Mostafa', area: 'Alexandria & Coastal', phone: '+20 102 345 6789', email: 'karim.m@example.com', created_at: new Date().toISOString() },
      { id: 4, name: 'Tarek Ibrahim', area: 'Delta (Tanta, Mansoura)', phone: '+20 103 456 7890', email: 'tarek.i@example.com', created_at: new Date().toISOString() }
    ];
  }
  if (!Array.isArray(store.assignments)) {
    store.assignments = [];
  }

  return store;
}

function saveDbStore(store) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(store, null, 2), 'utf8');
  } catch (e) {
    console.error('⚠️ Error writing to persistent DB file:', e.message);
  }
}

let dbStore = loadDbStore();

function cleanStr(val) {
  if (val === null || val === undefined) return '';
  const s = String(val).trim();
  if (s === '-' || s === 'None' || s === 'null' || s === 'undefined' || s === '#N/A') return '';
  return s;
}

function findVal(row, aliases) {
  const keys = Object.keys(row);
  for (const alias of aliases) {
    const cleanAlias = alias.toLowerCase().replace(/[\s_\-\.]/g, '');
    for (const k of keys) {
      const cleanKey = k.toLowerCase().trim().replace(/[\s_\-\.]/g, '');
      if (cleanKey === cleanAlias) {
        const val = cleanStr(row[k]);
        if (val) return val;
      }
    }
  }
  return '';
}

function parseCoords(rowObj) {
  // Check common latitude aliases
  let rawLat = findVal(rowObj, ['latitude', 'lat', 'gps_lat', 'gps lat', 'lat (n)', 'y', 'خط العرض', 'خط_العرض']);
  // Check common longitude aliases
  let rawLng = findVal(rowObj, ['longitude', 'long', 'lng', 'gps_lng', 'gps lng', 'lng (e)', 'x', 'خط الطول', 'خط_الطول']);

  // Fallback to checking rawObj keys directly
  if (!rawLat) rawLat = cleanStr(rowObj['Latitude'] ?? rowObj['lat'] ?? rowObj['LATITUDE'] ?? rowObj['Lat']);
  if (!rawLng) rawLng = cleanStr(rowObj['Longitude'] ?? rowObj['long'] ?? rowObj['lng'] ?? rowObj['LONGITUDE'] ?? rowObj['Lng']);

  // Handle potential comma as decimal separator (e.g. 30,0906)
  if (typeof rawLat === 'string') rawLat = rawLat.replace(',', '.');
  if (typeof rawLng === 'string') rawLng = rawLng.replace(',', '.');

  let numLat = parseFloat(rawLat);
  let numLng = parseFloat(rawLng);

  if (isNaN(numLat) || isNaN(numLng)) {
    return { lat: null, lng: null, isValid: false, reason: 'Invalid or missing numbers' };
  }

  // Detect header inverted Cairo coordinates (where "Latitude" is ~31.32 and "Longitude" is ~30.09)
  if (numLat >= 31.25 && numLat <= 32.5 && numLng >= 29.8 && numLng <= 30.5) {
    return { lat: numLng, lng: numLat, isValid: true };
  }

  // Standard coordinates check
  if (numLat >= -90 && numLat <= 90 && numLng >= -180 && numLng <= 180) {
    return { lat: numLat, lng: numLng, isValid: true };
  }

  return { lat: null, lng: null, isValid: false, reason: 'Coordinates out of bounds' };
}

function parseExcelBuffer(buffer) {
  const workbook = XLSX.read(buffer, { type: 'buffer', cellDates: true, cellText: false });

  // Find best sheet: prefer CE_Database or CW_Database, else sheet with most rows
  let sheetName = workbook.SheetNames.find(s => s === 'CE_Database' || s === 'CW_Database');
  if (!sheetName) {
    let maxRows = -1;
    for (const name of workbook.SheetNames) {
      const sheet = workbook.Sheets[name];
      const range = XLSX.utils.decode_range(sheet['!ref'] || 'A1:A1');
      const rowCount = range.e.r - range.s.r + 1;
      if (rowCount > maxRows) {
        maxRows = rowCount;
        sheetName = name;
      }
    }
  }
  sheetName = sheetName || workbook.SheetNames[0];

  const worksheet = workbook.Sheets[sheetName];
  const rawRows = XLSX.utils.sheet_to_json(worksheet, { defval: null });

  const parsedRows = [];
  let validCount = 0;
  let invalidCount = 0;

  rawRows.forEach((row, idx) => {
    const rowObj = {};
    const missingFields = [];
    const errors = [];

    // Clean keys and values
    Object.keys(row).forEach(key => {
      const trimmedKey = key ? key.trim() : '';
      if (trimmedKey && !trimmedKey.startsWith('__EMPTY')) {
        const val = row[key];
        rowObj[trimmedKey] = val instanceof Date ? val.toISOString().split('T')[0] : (val !== null && val !== undefined ? String(val).trim() : '');
      }
    });

    // Smart field extraction with flexible aliases
    const code = findVal(rowObj, ['chiller code', 'chillercode', 'code', 'serial number', 'serial', 'chiller id', 'id', 'كود']) || `CH-${idx + 1}`;
    const branch = findVal(rowObj, ['branch', 'فرع']) || cleanStr(rowObj['Branch']);
    const customerType = findVal(rowObj, ['customer type', 'customertype', 'type', 'channel', 'نوع العميل']) || 'Retail';
    const efficiency = findVal(rowObj, ['month ach. status', 'month ach status', 'efficiency', 'status', 'ach. status', 'achievement', 'الكفاءة']) || 'Performing';
    const customerName = findVal(rowObj, ['customer name', 'customername', 'customer', 'client', 'name', 'اسم العميل']) || cleanStr(rowObj['Customer Name']);
    const chillerType = findVal(rowObj, ['chiller type', 'chillertype']) || cleanStr(rowObj['Chiller Type']);
    const chillerStatus = findVal(rowObj, ['chiller status', 'chillerstatus']) || cleanStr(rowObj['Chiller Status']);
    const condition = findVal(rowObj, ['condition', 'condiiton']) || cleanStr(rowObj['Condition'] || rowObj['Condiiton']);
    const customerAddress = findVal(rowObj, ['customer address', 'address', 'عنوان']) || cleanStr(rowObj['Customer Address']);
    const mobileNumber = findVal(rowObj, ['mobile number', 'mobile', 'phone', 'هاتف']) || cleanStr(rowObj['Mobile Number']);

    const coordCheck = parseCoords(rowObj);
    if (!coordCheck.isValid) {
      errors.push('Missing or invalid GPS Latitude/Longitude coordinates');
      missingFields.push('Latitude/Longitude');
    }

    const isValid = coordCheck.isValid && code.length > 0;
    if (isValid) validCount++;
    else invalidCount++;

    parsedRows.push({
      rowIndex: idx + 2,
      chillerCode: code,
      latitude: coordCheck.lat,
      longitude: coordCheck.lng,
      customerType,
      efficiency,
      branch,
      chillerType,
      chillerStatus,
      condition,
      customerName,
      customerAddress,
      mobileNumber,
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
    const candidatePaths = [
      path.resolve('api/sample_chillers.xlsx'),
      path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([a-zA-Z]:)/, '$1')), 'sample_chillers.xlsx'),
      path.resolve('data/sample_chillers.xlsx'),
      path.resolve('public/sample_chillers.xlsx'),
      path.resolve('backend/data/sample_chillers.xlsx'),
      path.resolve('sample_chillers.xlsx'),
      'C:\\Users\\skamal\\.gemini\\antigravity\\scratch\\Bassem\\Chillers Database_V1.xlsx'
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

router.post('/excel/confirm', (req, res) => {
  const dbStore = loadDbStore();
  const { filename = 'Uploaded_Sheet.xlsx', rows = [], bypassValidation = false } = req.body || {};
  const rowsToSave = bypassValidation 
    ? rows 
    : rows.filter(r => r.isValid !== false || (r.latitude != null && r.longitude != null));
    
  const batchId = dbStore.batches.length + 1;

  dbStore.batches.push({
    id: batchId,
    filename,
    total_rows: rows.length,
    valid_rows: rowsToSave.length,
    invalid_rows: rows.length - rowsToSave.length,
    bypassed_validation: bypassValidation ? 1 : 0,
    uploaded_at: new Date().toISOString()
  });

  for (const r of rowsToSave) {
    const code = r.chillerCode || `CH-${Math.random().toString(36).substring(7)}`;
    const existingIdx = dbStore.chillers.findIndex(c => (c.chiller_code || c.chillerCode) === code);
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
      raw_data_json: typeof (r.rowObj || r.rawData) === 'object' ? JSON.stringify(r.rowObj || r.rawData || {}) : String(r.rowObj || r.rawData || '{}'),
      updated_at: new Date().toISOString()
    };
    if (existingIdx >= 0) dbStore.chillers[existingIdx] = item;
    else dbStore.chillers.push(item);

    dbStore.history.push({ ...item, id: dbStore.history.length + 1, snapshot_time: new Date().toISOString() });
  }

  saveDbStore(dbStore);

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
    chillers: formattedChillers,
    message: `Successfully saved ${rowsToSave.length} records into database.`
  });
});

router.get('/chillers', (req, res) => {
  const dbStore = loadDbStore();
  const { efficiency, customerType, search, batchId } = req.query;
  let rows = [...dbStore.chillers];

  if (batchId && batchId !== 'All' && batchId !== 'all') {
    const bId = parseInt(batchId);
    if (!isNaN(bId)) {
      // Check if batch exists in history snapshots for exact point-in-time state
      const historicalRows = dbStore.history.filter(h => (h.batch_id || h.batchId) === bId);
      if (historicalRows.length > 0) {
        rows = historicalRows;
      } else {
        rows = rows.filter(r => (r.batch_id || r.batchId) === bId);
      }
    }
  }

  if (efficiency && efficiency !== 'All') {
    rows = rows.filter(r => (r.efficiency || '').toLowerCase() === efficiency.toLowerCase());
  }

  if (customerType && customerType !== 'All') {
    rows = rows.filter(r => (r.customer_type || r.customerType || '').toLowerCase() === customerType.toLowerCase());
  }

  if (search) {
    const term = search.toLowerCase();
    rows = rows.filter(r =>
      (r.chiller_code || r.chillerCode || '').toLowerCase().includes(term) ||
      (r.customer_name || r.customerName || '').toLowerCase().includes(term) ||
      (r.branch || '').toLowerCase().includes(term)
    );
  }

  const chillers = rows.map(r => ({
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

  res.json({ success: true, count: chillers.length, chillers });
});

router.delete('/chillers/clear', (req, res) => {
  dbStore.chillers = [];
  res.json({ success: true, message: 'All active database records cleared' });
});

router.get('/batches', (req, res) => {
  res.json({ success: true, batches: [...dbStore.batches].reverse() });
});

router.delete('/batches/:id', (req, res) => {
  const batchId = parseInt(req.params.id);
  if (isNaN(batchId)) {
    return res.status(400).json({ success: false, error: 'Invalid batch ID' });
  }

  const batchIdx = dbStore.batches.findIndex(b => b.id === batchId);
  if (batchIdx === -1) {
    return res.status(404).json({ success: false, error: `Batch #${batchId} not found` });
  }

  const deletedBatch = dbStore.batches.splice(batchIdx, 1)[0];

  // Remove chillers belonging directly to this batch
  const initialChillersCount = dbStore.chillers.length;
  dbStore.chillers = dbStore.chillers.filter(c => (c.batch_id || c.batchId) !== batchId);
  const deletedChillersCount = initialChillersCount - dbStore.chillers.length;

  // Remove history snapshots for this batch
  dbStore.history = dbStore.history.filter(h => (h.batch_id || h.batchId) !== batchId);

  saveDbStore(dbStore);

  res.json({
    success: true,
    message: `Batch #${batchId} ('${deletedBatch.filename}') deleted successfully. Removed ${deletedChillersCount} chiller records.`,
    deletedBatchId: batchId
  });
});


router.get('/delta', (req, res) => {
  const { startBatchId, endBatchId } = req.query;
  const startId = parseInt(startBatchId);
  const endId = parseInt(endBatchId);

  const startSnapshot = dbStore.history.filter(h => (h.batch_id || h.batchId) === startId);
  const endSnapshot = dbStore.history.filter(h => (h.batch_id || h.batchId) === endId);

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

// ==========================================
// Sales Agents & Assignments Endpoints
// ==========================================

// GET all sales agents
router.get('/agents', (req, res) => {
  const agents = (dbStore.agents || []).map(a => {
    // calculate how many customers/chillers assigned
    const assignedCount = (dbStore.assignments || []).filter(as => as.agent_id === a.id).length;
    return { ...a, assigned_count: assignedCount };
  });
  res.json({ success: true, count: agents.length, agents });
});

// POST create new sales agent
router.post('/agents', (req, res) => {
  const { name, area, phone = '', email = '' } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: 'Agent name is required' });
  }

  const newId = (dbStore.agents && dbStore.agents.length > 0)
    ? Math.max(...dbStore.agents.map(a => a.id || 0)) + 1
    : 1;

  const newAgent = {
    id: newId,
    name: name.trim(),
    area: (area || '').trim(),
    phone: (phone || '').trim(),
    email: (email || '').trim(),
    created_at: new Date().toISOString()
  };

  dbStore.agents.push(newAgent);
  saveDbStore(dbStore);
  res.json({ success: true, message: `Agent '${newAgent.name}' created successfully`, agent: newAgent });
});

// PUT update existing sales agent
router.put('/agents/:id', (req, res) => {
  const agentId = parseInt(req.params.id);
  const agent = (dbStore.agents || []).find(a => a.id === agentId);
  if (!agent) {
    return res.status(404).json({ success: false, error: `Agent #${agentId} not found` });
  }

  const { name, area, phone, email } = req.body;
  if (name !== undefined) agent.name = name.trim();
  if (area !== undefined) agent.area = (area || '').trim();
  if (phone !== undefined) agent.phone = (phone || '').trim();
  if (email !== undefined) agent.email = (email || '').trim();

  // Also update agent_name across assignments
  if (name !== undefined && dbStore.assignments) {
    dbStore.assignments.forEach(as => {
      if (as.agent_id === agentId) {
        as.agent_name = agent.name;
        as.agent_area = agent.area;
      }
    });
  }

  saveDbStore(dbStore);
  res.json({ success: true, message: `Agent #${agentId} updated successfully`, agent });
});

// DELETE sales agent
router.delete('/agents/:id', (req, res) => {
  const agentId = parseInt(req.params.id);
  const idx = (dbStore.agents || []).findIndex(a => a.id === agentId);
  if (idx === -1) {
    return res.status(404).json({ success: false, error: `Agent #${agentId} not found` });
  }

  const removed = dbStore.agents.splice(idx, 1)[0];
  // Unassign any customers previously assigned to this agent
  if (dbStore.assignments) {
    dbStore.assignments = dbStore.assignments.filter(as => as.agent_id !== agentId);
  }

  saveDbStore(dbStore);
  res.json({ success: true, message: `Agent '${removed.name}' deleted successfully`, deletedId: agentId });
});

// GET assignments
router.get('/assignments', (req, res) => {
  res.json({ success: true, count: (dbStore.assignments || []).length, assignments: dbStore.assignments || [] });
});

// POST assign location(s) / customer(s) to an agent
router.post('/assignments', (req, res) => {
  const { agent_id, chiller_codes, chiller_ids, customer_names } = req.body;
  const agentId = parseInt(agent_id);
  const agent = (dbStore.agents || []).find(a => a.id === agentId);

  if (!agent) {
    return res.status(400).json({ success: false, error: 'Valid sales agent ID is required' });
  }

  if (!Array.isArray(dbStore.assignments)) {
    dbStore.assignments = [];
  }

  let assignedCount = 0;

  // Support assigning by customer_names or chiller_codes
  if (Array.isArray(customer_names) && customer_names.length > 0) {
    for (const cName of customer_names) {
      if (!cName) continue;
      // Remove any existing assignment for this customer name
      dbStore.assignments = dbStore.assignments.filter(as => as.customer_name?.toLowerCase() !== cName.toLowerCase());
      dbStore.assignments.push({
        id: Date.now() + Math.floor(Math.random() * 1000),
        customer_name: cName,
        agent_id: agent.id,
        agent_name: agent.name,
        agent_area: agent.area,
        assigned_at: new Date().toISOString()
      });
      assignedCount++;
    }
  } else if (Array.isArray(chiller_codes) && chiller_codes.length > 0) {
    for (const code of chiller_codes) {
      if (!code) continue;
      // find chiller info
      const ch = dbStore.chillers.find(c => (c.chiller_code || c.chillerCode) === code);
      const custName = ch ? (ch.customer_name || ch.customerName) : '';

      dbStore.assignments = dbStore.assignments.filter(as => as.chiller_code !== code);
      dbStore.assignments.push({
        id: Date.now() + Math.floor(Math.random() * 1000),
        chiller_code: code,
        chiller_id: ch?.id,
        customer_name: custName,
        agent_id: agent.id,
        agent_name: agent.name,
        agent_area: agent.area,
        assigned_at: new Date().toISOString()
      });
      assignedCount++;
    }
  } else {
    return res.status(400).json({ success: false, error: 'Please provide chiller_codes or customer_names to assign' });
  }

  saveDbStore(dbStore);
  res.json({
    success: true,
    message: `Successfully assigned ${assignedCount} location(s) to ${agent.name}`,
    assignedCount,
    agent
  });
});

// DELETE unassign
router.delete('/assignments', (req, res) => {
  const { customer_name, chiller_code } = req.body;
  if (!customer_name && !chiller_code) {
    return res.status(400).json({ success: false, error: 'customer_name or chiller_code required' });
  }

  const initialCount = (dbStore.assignments || []).length;
  if (customer_name) {
    dbStore.assignments = dbStore.assignments.filter(as => as.customer_name?.toLowerCase() !== customer_name.toLowerCase());
  } else if (chiller_code) {
    dbStore.assignments = dbStore.assignments.filter(as => as.chiller_code !== chiller_code);
  }

  const removedCount = initialCount - dbStore.assignments.length;
  saveDbStore(dbStore);
  res.json({ success: true, message: `Removed ${removedCount} assignment(s)`, removedCount });
});

// GET latest batch chillers with assignment info and customer search
router.get('/chillers/latest-batch', (req, res) => {
  const { search, agentId, assignmentStatus } = req.query;

  // Determine latest batch
  let latestBatchId = null;
  if (dbStore.batches && dbStore.batches.length > 0) {
    const sorted = [...dbStore.batches].sort((a, b) => (b.id || 0) - (a.id || 0));
    latestBatchId = sorted[0].id;
  }

  let rows = [];
  if (latestBatchId) {
    const historicalRows = dbStore.history.filter(h => (h.batch_id || h.batchId) === latestBatchId);
    if (historicalRows.length > 0) {
      rows = historicalRows;
    } else {
      rows = dbStore.chillers.filter(r => (r.batch_id || r.batchId) === latestBatchId);
    }
  } else {
    rows = [...dbStore.chillers];
  }

  // Create assignments lookup map
  const assignmentMap = new Map();
  (dbStore.assignments || []).forEach(as => {
    if (as.chiller_code) assignmentMap.set(as.chiller_code, as);
    if (as.customer_name) assignmentMap.set(as.customer_name.toLowerCase(), as);
  });

  let chillers = rows.map(r => {
    const code = r.chiller_code || r.chillerCode;
    const custName = r.customer_name || r.customerName || '';
    const assignment = assignmentMap.get(code) || (custName ? assignmentMap.get(custName.toLowerCase()) : null);

    return {
      id: r.id,
      chillerCode: code,
      batchId: r.batch_id || r.batchId,
      latitude: r.latitude,
      longitude: r.longitude,
      customerType: r.customer_type || r.customerType,
      efficiency: r.efficiency,
      branch: r.branch,
      chillerType: r.chiller_type || r.chillerType,
      chillerStatus: r.chiller_status || r.chillerStatus,
      condition: r.condition,
      customerName: custName,
      customerAddress: r.customer_address || r.customerAddress || '',
      mobileNumber: r.mobile_number || r.mobileNumber || '',
      assignedAgentId: assignment?.agent_id || null,
      assignedAgentName: assignment?.agent_name || null,
      assignedAgentArea: assignment?.agent_area || null,
      assignedAt: assignment?.assigned_at || null,
      rawData: typeof r.raw_data_json === 'string' ? JSON.parse(r.raw_data_json || '{}') : (r.rawData || r.raw_data_json || {})
    };
  });

  // Filter by customer name / general search
  if (search && search.trim()) {
    const term = search.trim().toLowerCase();
    chillers = chillers.filter(c =>
      (c.customerName || '').toLowerCase().includes(term) ||
      (c.chillerCode || '').toLowerCase().includes(term) ||
      (c.branch || '').toLowerCase().includes(term) ||
      (c.customerAddress || '').toLowerCase().includes(term)
    );
  }

  // Filter by assignment status
  if (assignmentStatus === 'assigned') {
    chillers = chillers.filter(c => c.assignedAgentId !== null);
  } else if (assignmentStatus === 'unassigned') {
    chillers = chillers.filter(c => c.assignedAgentId === null);
  }

  // Filter by specific agent
  if (agentId && agentId !== 'All') {
    const aId = parseInt(agentId);
    chillers = chillers.filter(c => c.assignedAgentId === aId);
  }

  const latestBatch = dbStore.batches.find(b => b.id === latestBatchId) || null;

  res.json({
    success: true,
    latestBatchId,
    latestBatch,
    count: chillers.length,
    chillers
  });
});

app.get(['/', '/index.html'], (req, res) => {
  const publicIndex = path.resolve('public/index.html');
  if (fs.existsSync(publicIndex)) {
    return res.sendFile(publicIndex);
  }
  res.setHeader('Content-Type', 'text/html');
  res.send('<!DOCTYPE html><html><head><title>Bassem Sales Platform</title><base href="/"><meta charset="UTF-8"><meta content="IE=Edge" http-equiv="X-UA-Compatible"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body><script src="flutter_bootstrap.js" async></script></body></html>');
});

app.use('/api', router);
app.use('/', router);

app.use((req, res, next) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, error: `API endpoint '${req.url}' not found` });
  }
  next();
});

// Auto-start listener if executed directly with node api/index.js
const isMain = process.argv[1]?.endsWith('api/index.js') || process.argv[1]?.endsWith('api\\index.js');
if (isMain) {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`🚀 API Server listening at http://localhost:${PORT}`);
  });
}

export { app };
export default (req, res) => {
  return app(req, res);
};
