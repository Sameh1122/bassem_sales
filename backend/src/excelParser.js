import XLSX from 'xlsx';
import { query } from './db.js';

// Clean string helpers
function cleanStr(val) {
  if (val === null || val === undefined) return '';
  const s = String(val).trim();
  if (s === '-' || s === 'None' || s === 'null' || s === 'undefined' || s === '#N/A') return '';
  return s;
}

// Coordinate parser with bounds check [-90..90] and [-180..180]
function parseCoords(latVal, lngVal) {
  let lat = parseFloat(cleanStr(latVal));
  let lng = parseFloat(cleanStr(lngVal));

  if (isNaN(lat) || isNaN(lng)) {
    return { lat: null, lng: null, isValid: false, reason: 'Invalid or missing numbers' };
  }

  // Validate global bounds [-90..90] and [-180..180]
  if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
    return { lat, lng, isValid: true };
  }

  return { lat: null, lng: null, isValid: false, reason: 'Coordinates out of bounds' };
}

export async function parseExcelData(fileInput) {
  let workbook;
  if (typeof fileInput === 'string') {
    workbook = XLSX.readFile(fileInput, { cellDates: true, cellText: false });
  } else if (Buffer.isBuffer(fileInput)) {
    workbook = XLSX.read(fileInput, { type: 'buffer', cellDates: true, cellText: false });
  } else {
    throw new Error('Invalid file input for Excel parser');
  }

  // Get active column definitions from database
  const columns = await query(`SELECT * FROM column_definitions WHERE is_active = 1 ORDER BY display_order ASC`);
  const requiredKeys = columns.filter(c => c.is_required === 1).map(c => c.key_name);

  // Pick target sheet: preference to 'CE_Database', 'CW_Database', or active/first sheet
  let sheetName = workbook.SheetNames.find(s => s === 'CE_Database' || s === 'CW_Database') || workbook.SheetNames[0];
  const worksheet = workbook.Sheets[sheetName];
  
  // Convert sheet to JSON rows
  const rawRows = XLSX.utils.sheet_to_json(worksheet, { defval: null });

  const parsedRows = [];
  let validCount = 0;
  let invalidCount = 0;

  rawRows.forEach((row, idx) => {
    const rowObj = {};
    const missingFields = [];
    const errors = [];

    // Extract all fields present in the Excel sheet
    Object.keys(row).forEach(key => {
      if (key && !key.startsWith('__EMPTY')) {
        const val = row[key];
        rowObj[key] = val instanceof Date ? val.toISOString().split('T')[0] : (val !== null && val !== undefined ? String(val).trim() : '');
      }
    });

    // Check required columns according to Schema Manager
    for (const reqKey of requiredKeys) {
      const cellVal = cleanStr(rowObj[reqKey]);
      if (!cellVal) {
        missingFields.push(reqKey);
        errors.push(`Missing required field: '${reqKey}'`);
      }
    }

    // Check for empty cells in active columns
    for (const col of columns) {
      const cellVal = cleanStr(rowObj[col.key_name]);
      if (!cellVal && !missingFields.includes(col.key_name)) {
        missingFields.push(col.key_name);
      }
    }

    // Extract raw coordinate values from Excel columns
    // In this dataset:
    // Column 'Longitude' holds Latitude values (~30.09 for Cairo, ~31.32 for Alexandria)
    // Column 'Latitude' holds Longitude values (~31.32 for Cairo, ~30.09 for Alexandria)
    const latVal = rowObj['Longitude'] || rowObj['lng'] || rowObj['LONGITUDE'];
    const lngVal = rowObj['Latitude'] || rowObj['lat'] || rowObj['LATITUDE'];

    const coordCheck = parseCoords(latVal, lngVal);

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
