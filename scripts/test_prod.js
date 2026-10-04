import XLSX from 'xlsx';

const BASE_URL = 'https://bassem-sales.vercel.app/api';

async function runProductionTests() {
  console.log('🧪 Starting End-to-End Production Tests on https://bassem-sales.vercel.app/ ...\n');

  // 1. Test GET /columns
  console.log('1️⃣ Testing GET /columns ...');
  const colsRes = await fetch(`${BASE_URL}/columns`);
  const colsData = await colsRes.json();
  if (!colsData.success || !Array.isArray(colsData.columns)) {
    throw new Error(`GET /columns failed: ${JSON.stringify(colsData)}`);
  }
  console.log(`✅ GET /columns returned ${colsData.columns.length} columns.\n`);

  // 2. Generate a valid sample Excel file buffer with test chillers
  console.log('2️⃣ Generating test Excel workbook with sample chiller records ...');
  const sampleData = [
    {
      'Branch': 'Cairo East',
      'Received Date': '2026-01-15',
      'Chiller Type': 'Water-Cooled',
      'Chiller Code': 'CH-PROD-TEST-101',
      'Chiller Status': 'Active',
      'Condition': 'Good',
      'Serial Number': 'SN-99881',
      'Latitude': 30.0444,
      'Longitude': 31.2357,
      'Customer Type': 'Retail',
      'Customer Name': 'Main Supermarket Cairo',
      'Month Ach. Status': 'Performing'
    },
    {
      'Branch': 'Alexandria West',
      'Received Date': '2026-02-10',
      'Chiller Type': 'Air-Cooled',
      'Chiller Code': 'CH-PROD-TEST-102',
      'Chiller Status': 'Under Maintenance',
      'Condition': 'Fair',
      'Serial Number': 'SN-99882',
      'Latitude': 31.2001,
      'Longitude': 29.9187,
      'Customer Type': 'LS',
      'Customer Name': 'Alex Hypermarket',
      'Month Ach. Status': 'Non-Performing'
    }
  ];

  const worksheet = XLSX.utils.json_to_sheet(sampleData);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'CE_Database');
  const excelBuffer = XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  const base64Excel = excelBuffer.toString('base64');
  console.log(`✅ Test workbook created (${excelBuffer.length} bytes).\n`);

  // 3. Test POST /excel/parse
  console.log('3️⃣ Testing POST /excel/parse with Base64 payload ...');
  const parseRes = await fetch(`${BASE_URL}/excel/parse`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fileBase64: base64Excel,
      filename: 'Production_Test_Chillers.xlsx'
    })
  });

  const parseData = await parseRes.json();
  if (!parseData.success || parseData.totalRows !== 2 || parseData.validCount !== 2) {
    throw new Error(`POST /excel/parse failed: ${JSON.stringify(parseData)}`);
  }
  console.log(`✅ POST /excel/parse parsed ${parseData.totalRows} rows cleanly (${parseData.validCount} valid).\n`);

  // 4. Test POST /excel/confirm (Save dataset to database)
  console.log('4️⃣ Testing POST /excel/confirm (Saving dataset into database) ...');
  const confirmRes = await fetch(`${BASE_URL}/excel/confirm`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: parseData.filename,
      rows: parseData.rows,
      bypassValidation: false
    })
  });

  const confirmData = await confirmRes.json();
  if (!confirmData.success || confirmData.savedRowsCount !== 2) {
    throw new Error(`POST /excel/confirm failed: ${JSON.stringify(confirmData)}`);
  }
  console.log(`✅ POST /excel/confirm saved ${confirmData.savedRowsCount} records (Batch ID: ${confirmData.batchId}).\n`);

  // 5. Test GET /chillers (Verify map data reflection)
  console.log('5️⃣ Testing GET /chillers to verify map data reflection ...');
  const chillersRes = await fetch(`${BASE_URL}/chillers`);
  const chillersData = await chillersRes.json();
  if (!chillersData.success || !Array.isArray(chillersData.chillers) || chillersData.count < 2) {
    throw new Error(`GET /chillers failed: ${JSON.stringify(chillersData)}`);
  }

  console.log(`✅ GET /chillers returned ${chillersData.count} pins for Map View!`);
  const samplePin = chillersData.chillers[0];
  console.log(`   📍 Sample Pin: Code=${samplePin.chillerCode}, Lat=${samplePin.latitude}, Lng=${samplePin.longitude}, Customer=${samplePin.customerName}, Efficiency=${samplePin.efficiency}\n`);

  // 6. Test GET /chillers with filters
  console.log('6️⃣ Testing GET /chillers with Efficiency filter (Performing) ...');
  const perfRes = await fetch(`${BASE_URL}/chillers?efficiency=Performing`);
  const perfData = await perfRes.json();
  console.log(`✅ Filter 'Performing' returned ${perfData.count} pins.\n`);

  // 7. Test GET /batches
  console.log('7️⃣ Testing GET /batches ...');
  const batchesRes = await fetch(`${BASE_URL}/batches`);
  const batchesData = await batchesRes.json();
  if (!batchesData.success || !Array.isArray(batchesData.batches)) {
    throw new Error(`GET /batches failed: ${JSON.stringify(batchesData)}`);
  }
  console.log(`✅ GET /batches returned ${batchesData.batches.length} batch upload history records.\n`);

  console.log('🎉 ALL AUTOMATED END-TO-END TESTS PASSED ON PRODUCTION DOMAIN! 🎉');
}

runProductionTests().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
