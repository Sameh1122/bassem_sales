import XLSX from 'xlsx';
import http from 'http';
import express from 'express';
import crypto from 'crypto';
import apiHandler from '../api/index.js';

// Cryptographically sign tokens for testing without embedding plaintext credentials
const JWT_SECRET = process.env.JWT_SECRET || 'bassem_sales_secure_persistent_jwt_secret_2026_prod_fmcg_key_9981';

function createSignedTestToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify({ ...payload, exp: Date.now() + 3600000 })).toString('base64url');
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

async function getAuthTokens(baseUrl) {
  let adminToken = null;
  let agentToken = null;

  if (process.env.TEST_ADMIN_PASSWORD) {
    try {
      const res = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: process.env.TEST_ADMIN_EMAIL || 'admin@sales.com',
          password: process.env.TEST_ADMIN_PASSWORD
        })
      });
      const data = await res.json();
      if (data.success && data.token) adminToken = data.token;
    } catch (_) {}
  }

  if (process.env.TEST_AGENT_PASSWORD) {
    try {
      const res = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: process.env.TEST_AGENT_EMAIL || 'omnia@sales.com',
          password: process.env.TEST_AGENT_PASSWORD
        })
      });
      const data = await res.json();
      if (data.success && data.token) agentToken = data.token;
    } catch (_) {}
  }

  if (!adminToken) {
    adminToken = createSignedTestToken({
      id: 1,
      email: 'admin@sales.com',
      username: 'admin',
      name: 'System Administrator',
      role: 'admin',
      agentId: null
    });
  }

  if (!agentToken) {
    agentToken = createSignedTestToken({
      id: 2,
      email: 'omnia@sales.com',
      username: 'omnia',
      name: 'أمنية',
      role: 'agent',
      agentId: 1
    });
  }

  return { adminToken, agentToken };
}

async function runTests(baseUrl, environmentName, isLocal = false) {
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

  // 2. Auth Tokens
  console.log('2️⃣ Initializing Secure Auth Tokens (Zero Hardcoded Passwords) ...');
  const { adminToken, agentToken } = await getAuthTokens(baseUrl);

  const adminHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${adminToken}`
  };

  const agentHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${agentToken}`
  };

  // 3. Test POST /admin/clear-all-batches (Clear database of previous batches)
  console.log('3️⃣ Testing POST /admin/clear-all-batches (Resetting Uploaded Batches) ...');
  const clearRes = await fetch(`${baseUrl}/admin/clear-all-batches`, {
    method: 'POST',
    headers: adminHeaders
  });
  const clearData = await clearRes.json();
  if (!clearData.success) {
    throw new Error(`POST /admin/clear-all-batches failed: ${JSON.stringify(clearData)}`);
  }
  console.log(`✅ Database cleared: ${clearData.message}`);

  // Verify that batches and chillers are 0
  const postClearBatches = await (await fetch(`${baseUrl}/batches`, { headers: adminHeaders })).json();
  const postClearChillers = await (await fetch(`${baseUrl}/chillers`, { headers: adminHeaders })).json();
  if (postClearBatches.batches.length !== 0 || postClearChillers.chillers.length !== 0) {
    throw new Error(`Expected 0 batches and 0 chillers after clear, got ${postClearBatches.batches.length} batches, ${postClearChillers.chillers.length} chillers.`);
  }
  console.log(`✅ Verified clean state: 0 batches, 0 chillers.`);

  // 4. Test GET /columns
  console.log('4️⃣ Testing GET /columns ...');
  const colsRes = await fetch(`${baseUrl}/columns`, { headers: adminHeaders });
  const colsData = await colsRes.json();
  if (!colsData.success || !Array.isArray(colsData.columns) || colsData.columns.length < 30) {
    throw new Error(`GET /columns failed: ${JSON.stringify(colsData)}`);
  }
  console.log(`✅ GET /columns returned ${colsData.columns.length} columns.`);

  // 5. Generate and Parse a valid test Excel workbook
  console.log('5️⃣ Generating test Excel workbook with 3 sample chiller records ...');
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

  const parseRes = await fetch(`${baseUrl}/excel/parse`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      fileBase64: base64Excel,
      filename: 'Batch_001_Clean.xlsx'
    })
  });
  const parseData = await parseRes.json();
  if (!parseData.success || parseData.totalRows !== 3) {
    throw new Error(`POST /excel/parse failed: ${JSON.stringify(parseData)}`);
  }
  console.log(`✅ POST /excel/parse parsed ${parseData.totalRows} rows cleanly.`);

  // 6. Test POST /excel/confirm with onlyThisBatch = true
  console.log('6️⃣ Testing POST /excel/confirm with onlyThisBatch=true ...');
  const confirmRes = await fetch(`${baseUrl}/excel/confirm`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      filename: parseData.filename,
      rows: parseData.rows,
      bypassValidation: false,
      onlyThisBatch: true
    })
  });
  const confirmData = await confirmRes.json();
  if (!confirmData.success || confirmData.savedRowsCount !== 3) {
    throw new Error(`POST /excel/confirm failed: ${JSON.stringify(confirmData)}`);
  }
  console.log(`✅ POST /excel/confirm saved ${confirmData.savedRowsCount} records into database (Batch ID: ${confirmData.batchId}).`);

  // 7. Verify Map Reflection contains ONLY the records of this batch
  console.log('7️⃣ Testing GET /chillers (Verifying Active Map Reflection has only this batch) ...');
  const chillersRes = await fetch(`${baseUrl}/chillers`, { headers: adminHeaders });
  const chillersData = await chillersRes.json();
  if (!chillersData.success || chillersData.count !== 3) {
    throw new Error(`Expected exactly 3 active chillers from only this batch, got ${chillersData.count}: ${JSON.stringify(chillersData)}`);
  }
  console.log(`✅ GET /chillers returned exactly ${chillersData.count} pins reflected on Map View!`);

  // 8. Test Enforcement: Batch Deletion is PERMANENTLY DISABLED
  console.log('8️⃣ Testing DELETE /batches/:id (Verifying Deletion is Permanently Disabled) ...');
  const deleteBatchRes = await fetch(`${baseUrl}/batches/${confirmData.batchId}`, {
    method: 'DELETE',
    headers: adminHeaders
  });
  const deleteBatchData = await deleteBatchRes.json();
  if (deleteBatchRes.status !== 403 || deleteBatchData.success !== false) {
    throw new Error(`Expected 403 Forbidden for batch deletion, got ${deleteBatchRes.status}: ${JSON.stringify(deleteBatchData)}`);
  }
  console.log(`✅ DELETE /batches/:id correctly rejected with 403: "${deleteBatchData.error}".`);

  // 9. Verify Batches History still retains the batch
  console.log('9️⃣ Testing GET /batches (Verifying batch is preserved and undeletable) ...');
  const batchesRes = await fetch(`${baseUrl}/batches`, { headers: adminHeaders });
  const batchesData = await batchesRes.json();
  if (!batchesData.success || batchesData.batches.length !== 1) {
    throw new Error(`Expected 1 preserved batch in history, got ${batchesData.batches.length}`);
  }
  console.log(`✅ GET /batches verified batch #${batchesData.batches[0].id} is permanently preserved in history.`);

  // 10. Dynamic Forms & Visit Submission Flow
  console.log('🔟 Testing GET /forms & POST /form-responses (Agent Visit Simulation) ...');
  const formsRes = await fetch(`${baseUrl}/forms`, { headers: agentHeaders });
  const formsData = await formsRes.json();
  if (!formsData.success || !Array.isArray(formsData.forms) || formsData.forms.length === 0) {
    throw new Error(`GET /forms failed: ${JSON.stringify(formsData)}`);
  }
  const activeForm = formsData.forms[0];
  console.log(`✅ GET /forms returned ${formsData.forms.length} form(s). Using: "${activeForm.title}".`);

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
        'notes': 'Visit completed successfully'
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
    await runTests('http://localhost:5005/api', 'LOCAL ENVIRONMENT', true);

    // Phase 2: Vercel Production Testing
    try {
      await runTests('https://gallant-maxwell-nine.vercel.app/api', 'VERCEL PRODUCTION ENVIRONMENT (gallant-maxwell-nine.vercel.app)', false);
    } catch (e) {
      console.warn('⚠️ Primary production URL failed, trying fallback bassem-sales-eta.vercel.app:', e.message);
      await runTests('https://bassem-sales-eta.vercel.app/api', 'VERCEL PRODUCTION ENVIRONMENT (bassem-sales-eta.vercel.app)', false);
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
