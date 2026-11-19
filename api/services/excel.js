import multer from 'multer';
import path from 'path';
import XLSXModule from 'xlsx';
import {
  neutralizeFormula,
  ALLOWED_ATTACHMENT_EXTS,
  ALLOWED_ATTACHMENT_MIMES
} from '../utils/security.js';

const XLSX = XLSXModule.default || XLSXModule;

export const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 25 * 1024 * 1024, // 25 MB max to protect against memory exhaustion
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.xlsx' || ext === '.xls' || ext === '.csv') {
      cb(null, true);
    } else {
      cb(new Error('Only Excel (.xlsx, .xls) and CSV spreadsheet files are allowed'));
    }
  }
});

export const uploadAttach = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 15 * 1024 * 1024 // 15 MB for visit photos and attachments
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const mime = (file.mimetype || '').toLowerCase();
    if (ALLOWED_ATTACHMENT_EXTS.has(ext) && ALLOWED_ATTACHMENT_MIMES.has(mime)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPEG, PNG, WEBP images and PDF documents are allowed.'));
    }
  }
});

export function cleanStr(val) {
  if (val === null || val === undefined) return '';
  const s = String(val).trim();
  if (s === '-' || s === 'None' || s === 'null' || s === 'undefined' || s === '#N/A') return '';
  return neutralizeFormula(s);
}

export function findVal(row, aliases) {
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

export function parseCoords(rowObj) {
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

  const numLat = parseFloat(rawLat);
  const numLng = parseFloat(rawLng);

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

export function parseExcelBuffer(buffer) {
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
        rowObj[trimmedKey] = val instanceof Date
          ? val.toISOString().split('T')[0]
          : (val !== null && val !== undefined ? neutralizeFormula(String(val).trim()) : '');
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
