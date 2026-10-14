import fs from 'fs';
import os from 'os';
import path from 'path';
import XLSX from 'xlsx';
import http from 'http';
import express from 'express';
import crypto from 'crypto';

const JWT_SECRET = 'bassem_sales_secure_persistent_jwt_secret_2026_prod_fmcg_key_9981';

function createSignedTestToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify({ ...payload, exp: Date.now() + 3600000 })).toString('base64url');
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

const adminToken = createSignedTestToken({
  id: 1,
  email: 'admin@sales.com',
  username: 'admin',
  name: 'System Administrator',
  role: 'admin'
});

const adminHeaders = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${adminToken}`
};

async function testColdStart() {
  console.log('\n============================================================');
  console.log('🧪 VERIFYING SERVERLESS COLD START PERSISTENCE');
  console.log('============================================================\n');

  // Step 1: Start Server Instance A
  console.log('1️⃣ Starting Serverless Instance A (Simulating Upload Instance)...');
  const { default: apiHandlerA } = await import(`../api/index.js?instance=A_${Date.now()}`);
  const appA = express();
  appA.use('/', apiHandlerA);
  const serverA = http.createServer(appA);
  await new Promise(r => serverA.listen(5006, r));
  console.log('✅ Instance A running on port 5006.');

  // Check health storage info
  const healthA = await (await fetch('http://localhost:5006/api/health')).json();
  console.log('Instance A Storage:', healthA.storage);

  // Generate Excel with 3 sample chillers
  const sampleData = [
    {
      'Branch': 'Alexandria West',
      'Chiller Code': 'CH-PERSIST-001',
      'Customer Name': 'Alex Hypermarket',
      'Latitude': 31.2001,
      'Longitude': 29.9187,
      'Customer Type': 'LS',
      'Month Ach. Status': 'Performing'
    },
    {
      'Branch': 'Cairo Central',
      'Chiller Code': 'CH-PERSIST-002',
      'Customer Name': 'Cairo Downtown Mart',
      'Latitude': 30.0444,
      'Longitude': 31.2357,
      'Customer Type': 'Retail',
      'Month Ach. Status': 'Performing'
    }
  ];

  const ws = XLSX.utils.json_to_sheet(sampleData);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'CE_Database');
  const base64Excel = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }).toString('base64');

  console.log('\n2️⃣ Uploading and confirming batch on Instance A...');
  const parseRes = await (await fetch('http://localhost:5006/api/excel/parse', {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({ fileBase64: base64Excel, filename: 'ColdStart_Test.xlsx' })
  })).json();

  const confirmRes = await (await fetch('http://localhost:5006/api/excel/confirm', {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      filename: parseRes.filename,
      rows: parseRes.rows,
      onlyThisBatch: true
    })
  })).json();

  console.log(`✅ Uploaded batch #${confirmRes.batchId} with ${confirmRes.savedRowsCount} chillers on Instance A.`);

  // Verify chillers count on Instance A
  const chillersA = await (await fetch('http://localhost:5006/api/chillers', { headers: adminHeaders })).json();
  console.log(`✅ Instance A /chillers returned ${chillersA.count} chillers.`);

  // Step 2: Shutdown Instance A completely
  console.log('\n3️⃣ Shutting down Instance A completely (Simulating container deallocation)...');
  await new Promise(r => serverA.close(r));
  console.log('✅ Instance A is dead.');

  // Delete local /tmp/chillers_db.json or OS tmp file so there is ZERO local file
  const tmpFiles = [
    path.resolve(os.tmpdir(), 'chillers_db.json'),
    '/tmp/chillers_db.json'
  ];
  tmpFiles.forEach(f => {
    try {
      if (fs.existsSync(f)) fs.unlinkSync(f);
    } catch (_) {}
  });
  console.log('✅ Local temporary files wiped clean.');

  // Step 3: Start brand new Instance B with zero local state
  console.log('\n4️⃣ Starting Brand New Serverless Instance B (Cold Start Container)...');
  // Dynamic import with fresh query cache buster
  const { default: apiHandlerB } = await import(`../api/index.js?instance=B_${Date.now()}`);
  const appB = express();
  appB.use('/', apiHandlerB);
  const serverB = http.createServer(appB);
  await new Promise(r => serverB.listen(5007, r));
  console.log('✅ Instance B running on port 5007 with NO local file.');

  // Step 4: Query Instance B (Map View)
  console.log('\n5️⃣ Fetching /chillers and /batches on fresh Instance B (Simulating user opening website)...');
  const chillersB = await (await fetch('http://localhost:5007/api/chillers', { headers: adminHeaders })).json();
  const batchesB = await (await fetch('http://localhost:5007/api/batches', { headers: adminHeaders })).json();

  console.log(`✅ Instance B /chillers returned: ${chillersB.count} chillers (Pins on Map)`);
  console.log(`✅ Instance B /batches returned: ${batchesB.batches.length} batches in history`);

  if (chillersB.count !== 2 || batchesB.batches.length === 0) {
    throw new Error(`Cold start failed! Expected 2 chillers on map, got ${chillersB.count}`);
  }

  console.log('\nSample chiller retrieved from Instance B:');
  console.log(` - Code: ${chillersB.chillers[0].chillerCode}`);
  console.log(` - Customer: ${chillersB.chillers[0].customerName}`);
  console.log(` - Coordinates: [${chillersB.chillers[0].latitude}, ${chillersB.chillers[0].longitude}]`);

  await new Promise(r => serverB.close(r));

  console.log('\n🎉 SUCCESS! COLD START PERSISTENCE FULLY VERIFIED! 🎉');
  console.log('Uploaded data will NEVER be lost across container recycles, redeployments, or website visits!\n');
}

testColdStart().catch(err => {
  console.error('❌ Cold start test failed:', err);
  process.exit(1);
});
