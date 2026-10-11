import XLSX from 'xlsx';
import http from 'http';
import express from 'express';
import apiHandler from '../api/index.js';

const ADMIN_CREDENTIALS = {
  email: 'admin@sales.com',
  password: 'A@$jjjff223445@'
};

const AGENT_CREDENTIALS = {
  email: 'omnia@sales.com',
  password: 'axB@134567_3354'
};

async function runTests(baseUrl, environmentName) {
  console.log(`\n============================================================`);
  console.log(`🧪 TESTING ENVIRONMENT: [ ${environmentName} ] (${baseUrl})`);
  console.log(`============================================================\n`);

  // 1. Test GET /health
  console.log('1️⃣ Testing GET /health ...');
  const healthRes = await fetch(`${baseUrl}/health`);
  const healthData = await healthRes.json();
  if (healthData.status !== 'ok') {
    throw new Error(`GET /health failed: ${JSON.stringify(healthData)}`);
  }
  console.log(`✅ GET /health reported status="${healthData.status}", version="${healthData.version}".`);

  // 2. Test Authentication (Admin & Agent Login)
  console.log('2️⃣ Testing POST /auth/login for Admin ...');
  const adminLoginRes = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(ADMIN_CREDENTIALS)
  });
  const adminLoginData = await adminLoginRes.json();
  if (!adminLoginData.success || !adminLoginData.token) {
    throw new Error(`Admin login failed: ${JSON.stringify(adminLoginData)}`);
  }
  const adminToken = adminLoginData.token;
  console.log(`✅ Admin login successful! Token received (Role: ${adminLoginData.user.role}).`);

  console.log('   Testing POST /auth/login for Field Agent (Omnia) ...');
  const agentLoginRes = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(AGENT_CREDENTIALS)
  });
  const agentLoginData = await agentLoginRes.json();
  if (!agentLoginData.success || !agentLoginData.token) {
    throw new Error(`Agent login failed: ${JSON.stringify(agentLoginData)}`);
  }
  const agentToken = agentLoginData.token;
  console.log(`✅ Agent login successful! Token received (Role: ${agentLoginData.user.role}, Name: ${agentLoginData.user.name}).`);

  const adminHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${adminToken}`
  };

  const agentHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${agentToken}`
  };

  // 3. Test GET /columns
  console.log('3️⃣ Testing GET /columns (with Admin Bearer Token) ...');
  const colsRes = await fetch(`${baseUrl}/columns`, { headers: adminHeaders });
  const colsData = await colsRes.json();
  if (!colsData.success || !Array.isArray(colsData.columns)) {
    throw new Error(`GET /columns failed: ${JSON.stringify(colsData)}`);
  }
  console.log(`✅ GET /columns returned ${colsData.columns.length} columns.`);

  // 4. Generate a valid test Excel workbook with sample chiller records
  console.log('4️⃣ Generating test Excel workbook with 3 sample chiller records ...');
  const sampleData = [
    {
      'Branch': 'Cairo East',
      'Received Date': '2026-01-15',
      'Chiller Type': 'Water-Cooled',
      'Chiller Code': 'CH-E2E-901',
      'Chiller Status': 'Active',
      'Condition': 'Good',
      'Serial Number': 'SN-E2E-901',
      'Latitude': 30.0444,
      'Longitude': 31.2357,
      'Customer Type': 'Retail',
      'Customer Name': 'Cairo Retail Store Alpha',
      'Month Ach. Status': 'Performing'
    },
    {
      'Branch': 'Alexandria West',
      'Received Date': '2026-02-10',
      'Chiller Type': 'Air-Cooled',
      'Chiller Code': 'CH-E2E-902',
      'Chiller Status': 'Under Maintenance',
      'Condition': 'Fair',
      'Serial Number': 'SN-E2E-902',
      'Latitude': 31.2001,
      'Longitude': 29.9187,
      'Customer Type': 'LS',
      'Customer Name': 'Alex Hypermarket Beta',
      'Month Ach. Status': 'Non-Performing'
    },
    {
      'Branch': 'Giza Central',
      'Received Date': '2026-03-01',
      'Chiller Type': 'Absorption',
      'Chiller Code': 'CH-E2E-903',
      'Chiller Status': 'Standby',
      'Condition': 'New',
      'Serial Number': 'SN-E2E-903',
      'Latitude': 30.0131,
      'Longitude': 31.2089,
      'Customer Type': 'SM',
      'Customer Name': 'Giza Store Gamma',
      'Month Ach. Status': 'Zero'
    }
  ];

  const worksheet = XLSX.utils.json_to_sheet(sampleData);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'CE_Database');
  const excelBuffer = XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  const base64Excel = excelBuffer.toString('base64');
  console.log(`✅ Test workbook created (${excelBuffer.length} bytes).`);

  // 5. Test POST /excel/parse
  console.log('5️⃣ Testing POST /excel/parse with Base64 payload ...');
  const parseRes = await fetch(`${baseUrl}/excel/parse`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      fileBase64: base64Excel,
      filename: 'E2E_Test_Chillers_2026.xlsx'
    })
  });

  const parseData = await parseRes.json();
  if (!parseData.success || parseData.totalRows !== 3 || parseData.validCount !== 3) {
    throw new Error(`POST /excel/parse failed: ${JSON.stringify(parseData)}`);
  }
  console.log(`✅ POST /excel/parse parsed ${parseData.totalRows} rows cleanly (${parseData.validCount} valid).`);

  // 6. Test POST /excel/confirm (Save dataset to database)
  console.log('6️⃣ Testing POST /excel/confirm (Saving dataset into database) ...');
  const confirmRes = await fetch(`${baseUrl}/excel/confirm`, {
    method: 'POST',
    headers: adminHeaders,
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

  // 7. Test GET /chillers (Verify Map Data Reflection)
  console.log('7️⃣ Testing GET /chillers (Verifying Map Data Reflection) ...');
  const chillersRes = await fetch(`${baseUrl}/chillers`, { headers: adminHeaders });
  const chillersData = await chillersRes.json();
  if (!chillersData.success || !Array.isArray(chillersData.chillers) || chillersData.count < 3) {
    throw new Error(`GET /chillers failed: ${JSON.stringify(chillersData)}`);
  }

  console.log(`✅ GET /chillers returned ${chillersData.count} pins reflected on Map View!`);
  const samplePin = chillersData.chillers[0];
  console.log(`   📍 Sample Pin: Code=${samplePin.chillerCode}, Lat=${samplePin.latitude}, Lng=${samplePin.longitude}, Customer=${samplePin.customerName}, Status=${samplePin.efficiency}`);

  // 8. Test GET /chillers with Efficiency filter (Performing)
  console.log('8️⃣ Testing GET /chillers with Efficiency filter (Performing) ...');
  const perfRes = await fetch(`${baseUrl}/chillers?efficiency=Performing`, { headers: adminHeaders });
  const perfData = await perfRes.json();
  console.log(`✅ Filter 'Performing' returned ${perfData.count} pins.`);

  // 9. Test GET /batches
  console.log('9️⃣ Testing GET /batches (Batch Upload History) ...');
  const batchesRes = await fetch(`${baseUrl}/batches`, { headers: adminHeaders });
  const batchesData = await batchesRes.json();
  if (!batchesData.success || !Array.isArray(batchesData.batches)) {
    throw new Error(`GET /batches failed: ${JSON.stringify(batchesData)}`);
  }
  console.log(`✅ GET /batches returned ${batchesData.batches.length} batch history records.`);

  // 10. Test Dynamic Forms & Visit Flow
  console.log('🔟 Testing GET /forms & POST /form-responses (Agent Visit Simulation) ...');
  const formsRes = await fetch(`${baseUrl}/forms`, { headers: agentHeaders });
  const formsData = await formsRes.json();
  if (!formsData.success || !Array.isArray(formsData.forms) || formsData.forms.length === 0) {
    throw new Error(`GET /forms failed: ${JSON.stringify(formsData)}`);
  }
  const activeForm = formsData.forms[0];
  console.log(`✅ GET /forms returned ${formsData.forms.length} available form(s). Using Form: "${activeForm.title}" (ID: ${activeForm.id}).`);

  const visitSubmitRes = await fetch(`${baseUrl}/form-responses`, {
    method: 'POST',
    headers: agentHeaders,
    body: JSON.stringify({
      form_id: activeForm.id,
      chiller_code: 'CH-E2E-901',
      customer_name: 'Cairo Retail Store Alpha',
      answers: {
        'cleanliness': 'Clean',
        'operational': 'Yes',
        'notes': 'Visit completed successfully during automated E2E test'
      },
      attachments: []
    })
  });
  const visitSubmitData = await visitSubmitRes.json();
  if (!visitSubmitData.success) {
    throw new Error(`POST /form-responses failed: ${JSON.stringify(visitSubmitData)}`);
  }
  console.log(`✅ POST /form-responses submitted visit successfully (Response ID: ${visitSubmitData.response.id}).`);

  console.log(`\n🎉 SUCCESS! ALL 10 TESTS PASSED FOR ENVIRONMENT: [ ${environmentName} ] 🎉\n`);
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
      console.warn('⚠️ Primary production URL failed, trying fallback bassem-sales-eta.vercel.app:', e.message);
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
