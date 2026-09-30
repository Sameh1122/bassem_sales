import XLSX from 'xlsx';
import { dbStore, cleanStr, parseCoords } from './_db.js';

export function parseExcelBuffer(buffer) {
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
