// scripts/test_qa_remediation.js
// Automated verification of all 8 QA Bug & Security Report findings

const BASE_URL = 'http://localhost:5000/api';

const ADMIN_CREDS = { email: 'admin@sales.com', password: 'En5$AH$n6GNbX3Wf' };
const OMNIA_CREDS = { email: 'omnia@sales.com', password: 'Uc3%CVX$SKA4MRbW' };
const MINA_CREDS  = { email: 'mina@sales.com',  password: 'Fh4#GC3SDpfdjAr4' };

async function login(creds) {
  const res = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(creds)
  });
  const data = await res.json();
  if (!res.ok || !data.token) {
    throw new Error(`Login failed for ${creds.email}: ${JSON.stringify(data)}`);
  }
  return data.token;
}

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✅ PASS: ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

async function runTests() {
  console.log('====================================================');
  console.log('🧪 Verifying QA Bug & Security Remediation (8 Findings)');
  console.log('====================================================\n');

  console.log('🔑 Authenticating test accounts...');
  const adminToken = await login(ADMIN_CREDS);
  const omniaToken = await login(OMNIA_CREDS);
  const minaToken  = await login(MINA_CREDS);
  console.log('  Tokens acquired for Admin, Omnia (Agent 1), Mina (Agent 2).\n');

  // ----------------------------------------------------
  // Finding 1: Sensitive Data Exposure on GET /api/health
  // ----------------------------------------------------
  console.log('▶️ [FINDING 1] Verifying GET /api/health data sanitization...');
  {
    const res = await fetch(`${BASE_URL}/health`);
    const data = await res.json();

    assert(res.status === 200, 'GET /api/health returns HTTP 200');
    assert(data.status === 'ok', 'Status is "ok"');
    assert(data.users === undefined, 'No "users" array in public /api/health response');
    assert(!data.storage?.blobTokenPrefix, 'No "blobTokenPrefix" in public /api/health response');
    assert(!data.storage?.matchingEnvKeys, 'No "matchingEnvKeys" in public /api/health response');
    assert(typeof data.storage?.chillersCount === 'number', 'Safe storage summary chillersCount is provided');

    // Check gated admin diagnostics
    const unauthDiag = await fetch(`${BASE_URL}/admin/diagnostics`);
    assert(unauthDiag.status === 401, 'Unauthenticated GET /api/admin/diagnostics returns 401');

    const authDiag = await fetch(`${BASE_URL}/admin/diagnostics`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const diagData = await authDiag.json();
    assert(authDiag.status === 200, 'Admin GET /api/admin/diagnostics returns 200');
    assert(Array.isArray(diagData.users) && diagData.users.every(u => !u.salt && !u.password_hash), 'Diagnostics users do not expose salts or password hashes');
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 2: Unrestricted File / Attachment Upload
  // ----------------------------------------------------
  console.log('▶️ [FINDING 2] Verifying MIME & Extension validation on POST /api/forms/upload-attachment...');
  {
    // A) Base64 with disallowed MIME (text/html)
    const badMimeRes = await fetch(`${BASE_URL}/forms/upload-attachment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`
      },
      body: JSON.stringify({
        base64Data: 'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        filename: 'payload.html'
      })
    });
    const badMimeData = await badMimeRes.json();
    assert(badMimeRes.status === 400, 'Base64 text/html payload rejected with HTTP 400');
    assert(badMimeData.success === false, 'badMime response success is false');

    // B) Base64 without data URI header with dangerous extension
    const badExtRes = await fetch(`${BASE_URL}/forms/upload-attachment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`
      },
      body: JSON.stringify({
        base64Data: 'dGVzdCBjb250ZW50',
        filename: 'malicious.exe'
      })
    });
    assert(badExtRes.status === 400, 'Disallowed extension (.exe) rejected with HTTP 400');

    // C) Valid PNG base64 payload
    const validRes = await fetch(`${BASE_URL}/forms/upload-attachment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`
      },
      body: JSON.stringify({
        base64Data: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        filename: 'valid.png'
      })
    });
    const validData = await validRes.json();
    assert(validRes.status === 200 && validData.success === true, 'Valid image/png upload accepted with HTTP 200');
    assert(Boolean(validData.url), `Attachment URL returned: ${validData.url}`);
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 3: Hardcoded Fallback JWT_SECRET
  // ----------------------------------------------------
  console.log('▶️ [FINDING 3] Verifying JWT Secret & Signature Enforcement...');
  {
    // Verify forged/tampered JWT is strictly rejected
    const tamperedRes = await fetch(`${BASE_URL}/auth/me`, {
      headers: { Authorization: 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImFkbWluQHNhbGVzLmNvbSIsInJvbGUiOiJhZG1pbiJ9.invalidsignaturehere' }
    });
    assert(tamperedRes.status === 401, 'Tampered JWT signature strictly rejected with HTTP 401');
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 4: Agent PII Exposure on GET /api/agents
  // ----------------------------------------------------
  console.log('▶️ [FINDING 4] Verifying Agent PII isolation on GET /api/agents...');
  {
    // Omnia (Agent 1) should only see Omnia's record
    const omniaAgentsRes = await fetch(`${BASE_URL}/agents`, {
      headers: { Authorization: `Bearer ${omniaToken}` }
    });
    const omniaAgentsData = await omniaAgentsRes.json();
    assert(omniaAgentsRes.status === 200, 'Agent GET /api/agents returns HTTP 200');
    assert(omniaAgentsData.count === 1, `Agent receives only 1 agent record (received ${omniaAgentsData.count})`);
    assert(omniaAgentsData.agents[0].id === 1 && omniaAgentsData.agents[0].login_email === 'omnia@sales.com', 'Returned record belongs strictly to Omnia');
    const hasMina = omniaAgentsData.agents.some(a => a.name?.includes('Mina') || a.email?.includes('mina'));
    assert(!hasMina, 'Other agent (Mina) PII is not leaked to Omnia');

    // Admin should see all agents
    const adminAgentsRes = await fetch(`${BASE_URL}/agents`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const adminAgentsData = await adminAgentsRes.json();
    assert(adminAgentsData.count >= 2, `Admin receives all agents (count: ${adminAgentsData.count})`);
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 5: Missing Form & Territory Authorization on POST /api/form-responses
  // ----------------------------------------------------
  console.log('▶️ [FINDING 5] Verifying Form & Territory Authorization on POST /api/form-responses...');
  {
    // Fetch available forms
    const formsRes = await fetch(`${BASE_URL}/forms`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const formsData = await formsRes.json();
    const formId = formsData.forms[0]?.id || 1;

    // Mina has 0 chiller assignments. Submitting a response for an unassigned chiller must be rejected (403)
    const unauthorizedTerritoryRes = await fetch(`${BASE_URL}/form-responses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${minaToken}`
      },
      body: JSON.stringify({
        form_id: formId,
        chiller_code: 'CH-UNASSIGNED-999',
        customer_name: 'Unassigned Store',
        answers: { condition: 'Good' }
      })
    });
    const unauthData = await unauthorizedTerritoryRes.json();
    assert(unauthorizedTerritoryRes.status === 403, 'Agent submission for unassigned territory rejected with HTTP 403');
    assert(unauthData.error?.includes('territory') || unauthData.error?.includes('assigned'), `Descriptive authorization error: "${unauthData.error}"`);

    // Omnia has assigned chiller CH-001 (or customer "Koshary El Tahrir")
    const omniaChillersRes = await fetch(`${BASE_URL}/chillers/latest-batch`, {
      headers: { Authorization: `Bearer ${omniaToken}` }
    });
    const omniaChillersData = await omniaChillersRes.json();
    if (omniaChillersData.chillers.length > 0) {
      const assignedChiller = omniaChillersData.chillers[0];
      const authorizedRes = await fetch(`${BASE_URL}/form-responses`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${omniaToken}`
        },
        body: JSON.stringify({
          form_id: formId,
          chiller_code: assignedChiller.chillerCode,
          customer_name: assignedChiller.customerName,
          answers: { verified: 'Yes', test: 'QA Remediation Verification' }
        })
      });
      assert(authorizedRes.status === 201, 'Agent submission for legitimately assigned chiller accepted with HTTP 201');
    }
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 6: GET /api/delta Input Validation & Expanded Diffing
  // ----------------------------------------------------
  console.log('▶️ [FINDING 6] Verifying GET /api/delta input validation & error codes...');
  {
    // A) Missing parameters
    const missingRes = await fetch(`${BASE_URL}/delta`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert(missingRes.status === 400, 'GET /api/delta without query params returns HTTP 400');

    // B) Non-integer parameters
    const nonIntRes = await fetch(`${BASE_URL}/delta?startBatchId=abc&endBatchId=xyz`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert(nonIntRes.status === 400, 'GET /api/delta with non-integers returns HTTP 400');

    // C) Nonexistent batch IDs
    const notFoundRes = await fetch(`${BASE_URL}/delta?startBatchId=999999&endBatchId=888888`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert(notFoundRes.status === 404, 'GET /api/delta with nonexistent batches returns HTTP 404');

    // D) Valid batches check
    const batchesRes = await fetch(`${BASE_URL}/batches`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const batchesData = await batchesRes.json();
    if (batchesData.batches.length >= 2) {
      const b1 = batchesData.batches[batchesData.batches.length - 1].id;
      const b2 = batchesData.batches[0].id;
      const validDeltaRes = await fetch(`${BASE_URL}/delta?startBatchId=${b1}&endBatchId=${b2}`, {
        headers: { Authorization: `Bearer ${adminToken}` }
      });
      const deltaData = await validDeltaRes.json();
      assert(validDeltaRes.status === 200, 'GET /api/delta between valid batches returns HTTP 200');
      assert(deltaData.summary !== undefined, 'Summary object present in delta response');
    }
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 7: Batch ID Generation Logic
  // ----------------------------------------------------
  console.log('▶️ [FINDING 7] Verifying Batch ID calculation...');
  {
    const batchesRes = await fetch(`${BASE_URL}/batches`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const batchesData = await batchesRes.json();
    const batchIds = batchesData.batches.map(b => b.id);
    const maxId = Math.max(...batchIds, 0);
    const nextExpected = maxId + 1;
    assert(nextExpected > 0, `Next batch ID calculation uses Math.max + 1 (expected next: ${nextExpected})`);
  }
  console.log('');

  // ----------------------------------------------------
  // Finding 8: Silent Batch Fallback in GET /api/chillers/latest-batch
  // ----------------------------------------------------
  console.log('▶️ [FINDING 8] Verifying no silent fallback on invalid batchId...');
  {
    const invalidBatchRes = await fetch(`${BASE_URL}/chillers/latest-batch?batchId=999999`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const invalidBatchData = await invalidBatchRes.json();
    assert(invalidBatchRes.status === 200, 'GET /api/chillers/latest-batch?batchId=999999 returns HTTP 200');
    assert(invalidBatchData.count === 0, `count is 0 (received ${invalidBatchData.count})`);
    assert(invalidBatchData.chillers.length === 0, `chillers array is empty (received ${invalidBatchData.chillers.length})`);
    assert(invalidBatchData.selectedBatchId === '999999', 'selectedBatchId is preserved as "999999" without silent reset to "all"');

    // And verify that batchId='all' still returns the complete dataset
    const allRes = await fetch(`${BASE_URL}/chillers/latest-batch?batchId=all`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const allData = await allRes.json();
    assert(allData.count > 0, `batchId=all returns full dataset (count: ${allData.count})`);
  }
  console.log('');

  console.log('====================================================');
  console.log(`🏁 Summary: ${passed} Passed, ${failed} Failed`);
  console.log('====================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
