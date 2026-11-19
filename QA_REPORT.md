# QA Bug & Security Report — Bassem Sales Platform (v2.5.0)

**Target Environment:** `http://localhost:5000` (Express API + Flutter Web, Vercel Blob cloud persistence active)  
**Test Scope:** Automated verification suite (`34 passed, 0 failed`) + static code audit of [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js)  
**Verification Script:** [scripts/test_qa_remediation.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/scripts/test_qa_remediation.js)  
**Active Production Dataset:** 1,403 chillers / 7 batches preserved in cloud storage.

---

## Executive Summary

| Area | Status | Resolution Notes |
| :--- | :--- | :--- |
| Authentication & JWT | **Pass** | Login, password hashing & verification, RBAC, and tampered token rejection verified. |
| Unauthenticated Access | **Pass** | All protected endpoints return HTTP `401`. |
| RBAC Enforcement | **Pass** | Sales agent blocked (`403`) from admin/owner routes; admin blocked (`403`) from owner routes. |
| Territory Isolation | **Pass** | Territory isolation enforced across chillers, assignments, and form submissions. |
| **Security & Data Exposure** | **Pass (All 5 Fixed)** | `/api/health` sanitized; strict MIME/extension upload validation enforced; dynamic runtime fallback for `JWT_SECRET`; agent PII isolated; form & territory authorization enforced. |
| **Functional / Edge Cases** | **Pass (All 3 Fixed)** | `/api/delta` input validation & full field diffing implemented; batch ID collision risk resolved; silent fallback on invalid `batchId` eliminated. |

---

## Remediation Details & Verification Evidence

### 1. [HIGH] Unauthenticated Sensitive Data Exposure on `GET /api/health`
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L932-L965)
- **Previous Status:** Fail — Exposed user accounts with salts, password hash prefixes, and internal environment token prefixes.
- **Remediation Implemented:**
  - Public `GET /api/health` now returns only safe high-level indicators (`status: 'ok'`, version, cloud sync status, chiller/batch counts, and timestamp).
  - Stripped `users`, `blobTokenPrefix`, and `matchingEnvKeys`.
  - Added authenticated `GET /api/admin/diagnostics` gated behind `requireAdmin` for internal diagnostics, with zero exposure of salts or password hashes.
- **Verification Evidence:**
  - `GET /api/health` returns `200` with `users === undefined` and no credential or secret leakage.
  - Unauthenticated `GET /api/admin/diagnostics` returns `401 Unauthorized`.
  - Authenticated admin call returns `200 OK` with sanitized diagnostics.
- **Status:** **Fixed & Verified (Pass)**

---

### 2. [HIGH] Unrestricted File Extension / MIME Upload (Stored XSS Risk)
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L52-L95) and [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L2130-L2210)
- **Previous Status:** Fail — Multipart and base64 upload handlers accepted arbitrary extensions (e.g. `.html`, `.js`, `.exe`) without MIME type allowlisting.
- **Remediation Implemented:**
  - Configured `ALLOWED_ATTACHMENT_EXTS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.pdf'])`.
  - Configured `ALLOWED_ATTACHMENT_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])`.
  - Configured multer `fileFilter` in `uploadAttach` and added explicit validation for both multipart (`req.file`) and base64 JSON payload uploads, returning HTTP `400` on violation.
  - Added static headers `X-Content-Type-Options: nosniff` and `Content-Disposition: attachment` for `/uploads`.
- **Verification Evidence:**
  - `POST /api/forms/upload-attachment` with `data:text/html;base64,...` rejected with HTTP `400` and error message.
  - Upload of `.exe` file extension rejected with HTTP `400`.
  - Upload of valid `data:image/png;base64,...` returns HTTP `200` with persistent URL.
- **Status:** **Fixed & Verified (Pass)**

---

### 3. [HIGH] Hardcoded Fallback `JWT_SECRET` in Source Code
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L86-L98)
- **Previous Status:** Fail — Hardcoded fallback secret allowed token forgery if `JWT_SECRET` was omitted in production.
- **Remediation Implemented:**
  - Created `resolveJwtSecret()` function.
  - In production / Vercel (`NODE_ENV === 'production'` or `process.env.VERCEL`), if `JWT_SECRET` is not provided in environment variables, an ephemeral cryptographically secure 256-bit key (`crypto.randomBytes(32).toString('hex')`) is dynamically generated to prevent known-secret forgery.
- **Verification Evidence:**
  - Tampered JWT token rejected with HTTP `401 Unauthorized`.
  - Valid signed tokens for Admin, Omnia, and Mina function properly across endpoints.
- **Status:** **Fixed & Verified (Pass)**

---

### 4. [MEDIUM] Agent PII Exposure on `GET /api/agents`
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L1641-L1665)
- **Previous Status:** Fail — Calling `GET /api/agents` as a sales rep returned all other agents' phone numbers, emails, usernames, and territories.
- **Remediation Implemented:**
  - Added caller role check: when `req.user.role === 'agent'`, the response is filtered strictly to `a.id === req.user.agentId`.
  - Admins and Owners retain access to the full agents directory.
- **Verification Evidence:**
  - Omnia (`agentId: 1`) calling `GET /api/agents` receives `count: 1` containing only Omnia's record; Mina's record is completely excluded.
  - Admin calling `GET /api/agents` receives all agents (`count: 2`).
- **Status:** **Fixed & Verified (Pass)**

---

### 5. [MEDIUM] Missing Form & Territory Authorization on `POST /api/form-responses`
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L2210-L2255)
- **Previous Status:** Fail — Agents could submit visit audits for forms not assigned to them and for chillers outside their assigned territory.
- **Remediation Implemented:**
  - Added authorization check when `req.user.role === 'agent'`:
    1. Verifies that `form.assigned_agent_ids` includes `req.user.agentId` (or is empty for global forms).
    2. Verifies that `req.user.agentId` has a corresponding assignment in `dbStore.assignments` matching either `chiller_code` or `customer_name`.
  - Returns HTTP `403 Forbidden` with a descriptive message on authorization failure.
- **Verification Evidence:**
  - Mina (0 assigned chillers) submitting a form for an unassigned chiller rejected with HTTP `403 Forbidden` (`"Access denied: Chiller or customer is not assigned to your territory"`).
  - Omnia submitting a visit audit for her assigned chiller (`CH-001`) accepted with HTTP `201 Created`.
- **Status:** **Fixed & Verified (Pass)**

---

### 6. [MEDIUM] `GET /api/delta` Returns `200` on Nonexistent Batch IDs & Misses Field Changes
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L1561-L1635)
- **Previous Status:** Fail — Non-existent batch IDs returned HTTP `200` with empty diffs; modifications check only compared 4 fields (`efficiency`, `latitude`, `longitude`, `branch`).
- **Remediation Implemented:**
  - Added validation for `startBatchId` and `endBatchId`: missing or non-integer query params return HTTP `400 Bad Request`.
  - Verified batches exist in `dbStore.batches`; non-existent IDs return HTTP `404 Not Found`.
  - Expanded diff comparison to include `customer_name`, `customer_type`, `condition`, `chiller_status`, `customer_address`, `mobile_number`, and dynamic attributes in `raw_data_json`.
- **Verification Evidence:**
  - `GET /api/delta` without parameters returns HTTP `400`.
  - `GET /api/delta?startBatchId=abc&endBatchId=xyz` returns HTTP `400`.
  - `GET /api/delta?startBatchId=999999&endBatchId=888888` returns HTTP `404`.
  - `GET /api/delta?startBatchId=1&endBatchId=7` returns HTTP `200` with full differential summary.
- **Status:** **Fixed & Verified (Pass)**

---

### 7. [MEDIUM] Batch ID Collision Risk & Ignored `onlyThisBatch` Flag in `POST /api/excel/confirm`
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L1265-L1315)
- **Previous Status:** Fail — `batchId = dbStore.batches.length + 1` caused ID collisions if batches were deleted; `onlyThisBatch` flag was ignored.
- **Remediation Implemented:**
  - Batch ID is now computed as `Math.max(0, ...dbStore.batches.map(b => Number(b.id) || 0)) + 1`, guaranteeing strictly unique, monotonically increasing IDs regardless of list length.
  - Chiller item IDs now use `maxChillerId + addedCount + 1` to prevent ID collisions.
  - `onlyThisBatch` flag is fully honored: when `true`, existing chillers are cleared so only the new batch records are active in the map view, and `only_this_batch: 1` is recorded in metadata.
- **Verification Evidence:**
  - Batch ID computation verified: returns next monotonic ID (`8`).
  - Integration test verified `onlyThisBatch: true` saves the batch and displays exactly the expected records on Map View.
- **Status:** **Fixed & Verified (Pass)**

---

### 8. [LOW] Silent Fallback on Invalid `batchId` in `GET /api/chillers/latest-batch`
- **Location:** [api/index.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/api/index.js#L1906-L1935)
- **Previous Status:** Fail — Passing an invalid or nonexistent numeric `batchId` silently reset `selectedBatchId = 'all'` and returned all 1,403 chillers.
- **Remediation Implemented:**
  - Fallback logic now strictly checks if `batchId` was omitted, `'all'`, or `'latest'`.
  - If an explicit numeric `batchId` yields 0 rows, the endpoint returns `{ success: true, count: 0, chillers: [], selectedBatchId }` without resetting to all chillers.
- **Verification Evidence:**
  - `GET /api/chillers/latest-batch?batchId=999999` returns HTTP `200` with `count: 0`, `chillers: []`, and `selectedBatchId: "999999"`.
  - `GET /api/chillers/latest-batch?batchId=all` returns HTTP `200` with all 1,403 records.
- **Status:** **Fixed & Verified (Pass)**

---

## Final Verification Summary

- **Automated Test Suite:** [scripts/test_qa_remediation.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/scripts/test_qa_remediation.js)
  - **Total Tests:** 34
  - **Passed:** 34
  - **Failed:** 0
- **Regression Suite:** [scripts/test_local_and_vercel.js](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/scripts/test_local_and_vercel.js) — Local environment passed 10/10 tests.
- **Active Data State:** 1,403 chillers across 7 batches preserved with active cloud synchronization.
