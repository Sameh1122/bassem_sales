import XLSX from 'xlsx';
import http from 'http';
import express from 'express';
import apiHandler from '../api/index.js';

async function runTests(baseUrl, environmentName) {
  console.log(`\n============================================================`);
  console.log(`🧪 TESTING ENVIRONMENT: [ ${environmentName} ] (${baseUrl})`);
  console.log(`============================================================\n`);

  // 1. Test GET /columns
  console.log('1️⃣ Testing GET /columns ...');
  const colsRes = await fetch(`${baseUrl}/columns`);
  const colsData = await colsRes.json();
  if (!colsData.success || !Array.isArray(colsData.columns)) {
    throw new Error(`GET /columns failed: ${JSON.stringify(colsData)}`);
  }
  console.log(`✅ GET /columns returned ${colsData.columns.length} columns.`);

  // 2. Generate a valid sample Excel file buffer with test chillers
  console.log('2️⃣ Generating test Excel workbook with 3 sample chiller records ...');
  const sampleData = [
    {
      'Branch': 'Cairo East',
      'Received Date': '2026-01-15',
      'Chiller Type': 'Water-Cooled',
      'Chiller Code': 'CH-E2E-001',
      'Chiller Status': 'Active',
      'Condition': 'Good',
      'Serial Number': 'SN-E2E-01',
      'Latitude': 30.0444,
      'Longitude': 31.2357,
      'Customer Type': 'Retail',
      'Customer Name': 'Cairo Retail Store A',
      'Month Ach. Status': 'Performing'
    },
    {
      'Branch': 'Alexandria West',
      'Received Date': '2026-02-10',
      'Chiller Type': 'Air-Cooled',
      'Chiller Code': 'CH-E2E-002',
      'Chiller Status': 'Under Maintenance',
      'Condition': 'Fair',
      'Serial Number': 'SN-E2E-02',
      'Latitude': 31.2001,
      'Longitude': 29.9187,
      'Customer Type': 'LS',
      'Customer Name': 'Alex Large Supermarket B',
      'Month Ach. Status': 'Non-Performing'
    },
    {
      'Branch': 'Giza Central',
      'Received Date': '2026-03-01',
      'Chiller Type': 'Absorption',
      'Chiller Code': 'CH-E2E-003',
      'Chiller Status': 'Standby',
      'Condition': 'New',
      'Serial Number': 'SN-E2E-03',
      'Latitude': 30.0131,
      'Longitude': 31.2089,
      'Customer Type': 'SM',
      'Customer Name': 'Giza Market C',
      'Month Ach. Status': 'Zero'
    }
  ];

  const worksheet = XLSX.utils.json_to_sheet(sampleData);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'CE_Database');
  const excelBuffer = XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  const base64Excel = excelBuffer.toString('base64');
  console.log(`✅ Test workbook created (${excelBuffer.length} bytes).`);

  // 3. Test POST /excel/parse
  console.log('3️⃣ Testing POST /excel/parse with Base64 payload ...');
  const parseRes = await fetch(`${baseUrl}/excel/parse`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fileBase64: base64Excel,
      filename: 'E2E_Test_Chillers.xlsx'
    })
  });

  const parseData = await parseRes.json();
  if (!parseData.success || parseData.totalRows !== 3 || parseData.validCount !== 3) {
    throw new Error(`POST /excel/parse failed: ${JSON.stringify(parseData)}`);
  }
  console.log(`✅ POST /excel/parse parsed ${parseData.totalRows} rows cleanly (${parseData.validCount} valid).`);

  // 4. Test POST /excel/confirm (Save dataset to database)
  console.log('4️⃣ Testing POST /excel/confirm (Saving dataset into database) ...');
  const confirmRes = await fetch(`${baseUrl}/excel/confirm`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: parseData.filename,
      rows: parseData.rows,
      bypassValidation: false
    })
  });

  const confirmData = await confirmRes.json();
  if (!confirmData.success || confirmData.savedRowsCount !== 3) {
    throw new Error(`POST /excel/confirm failed: ${JSON.stringify(confirmData)}`);
  }
  console.log(`✅ POST /excel/confirm saved ${confirmData.savedRowsCount} records into database (Batch ID: ${confirmData.batchId}).`);

  // 5. Test GET /chillers (Verify map data reflection)
  console.log('5️⃣ Testing GET /chillers (Verifying Map Data Reflection) ...');
  const chillersRes = await fetch(`${baseUrl}/chillers`);
  const chillersData = await chillersRes.json();
  if (!chillersData.success || !Array.isArray(chillersData.chillers) || chillersData.count < 3) {
    throw new Error(`GET /chillers failed: ${JSON.stringify(chillersData)}`);
  }

  console.log(`✅ GET /chillers returned ${chillersData.count} pins reflected on Map View!`);
  const samplePin = chillersData.chillers[0];
  console.log(`   📍 Pin 1: Code=${samplePin.chillerCode}, Lat=${samplePin.latitude}, Lng=${samplePin.longitude}, Customer=${samplePin.customerName}, Status=${samplePin.efficiency}`);

  // 6. Test GET /chillers with filters
  console.log('6️⃣ Testing GET /chillers with Efficiency filter (Performing) ...');
  const perfRes = await fetch(`${baseUrl}/chillers?efficiency=Performing`);
  const perfData = await perfRes.json();
  console.log(`✅ Filter 'Performing' returned ${perfData.count} pins.`);

  // 7. Test GET /batches
  console.log('7️⃣ Testing GET /batches ...');
  const batchesRes = await fetch(`${baseUrl}/batches`);
  const batchesData = await batchesRes.json();
  if (!batchesData.success || !Array.isArray(batchesData.batches)) {
    throw new Error(`GET /batches failed: ${JSON.stringify(batchesData)}`);
  }
  console.log(`✅ GET /batches returned ${batchesData.batches.length} batch history records.`);

  console.log(`\n🎉 SUCCESS! ALL TESTS PASSED FOR ENVIRONMENT: [ ${environmentName} ] 🎉\n`);
}

async function startLocalServerAndRunTests() {
  console.log('🚀 Starting Local Test Server on port 5005 ...');
  const app = express();
  app.use('/', apiHandler);
  
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(5005, resolve));
  console.log('✅ Local test server running on http://localhost:5005');

  try {
    // Phase 1: Local Testing
    await runTests('http://localhost:5005/api', 'LOCAL ENVIRONMENT');

    // Phase 2: Vercel Production Testing
    try {
      await runTests('https://gallant-maxwell-nine.vercel.app/api', 'VERCEL PRODUCTION ENVIRONMENT (gallant-maxwell-nine.vercel.app)');
    } catch (e) {
      console.warn('⚠️ Main production URL failed, trying fallback bassem-sales-eta.vercel.app:', e.message);
      await runTests('https://bassem-sales-eta.vercel.app/api', 'VERCEL PRODUCTION ENVIRONMENT (bassem-sales-eta.vercel.app)');
    }

    console.log('============================================================');
    console.log('🏆 ALL LOCAL AND VERCEL PRODUCTION TESTS PASSED 100%! 🏆');
    console.log('============================================================\n');
  } finally {
    server.close();
  }
}

startLocalServerAndRunTests().catch(err => {
  console.error('❌ Integration test failed:', err);
  process.exit(1);
});
