# BA Requirements Traceability & Business Test Results (`v2.5.0` — Post-Fix Verification)

**Tester:** QA Tester  
**Date:** 2026-11-19  
**Target Environment:** `http://localhost:5000` (Express API `v2.5.0` connected to Vercel Blob Persistent Cloud: `1,403` chillers, `7` batches) + Isolated verification server (`PORT=5099`, `ENABLE_RATE_LIMIT_TEST=true`)  
**Official BA Source Documents:**
- `C:\Users\skamal\.gemini\antigravity\brain\8478fc99-bff6-4264-bdb8-643b88791f14\BRD.md` (`v2.5.0`: `BR-01`–`BR-08`, Scope `§4.1–4.3`, Key Findings `§6.1–6.6`)
- `C:\Users\skamal\.gemini\antigravity\brain\8478fc99-bff6-4264-bdb8-643b88791f14\FSD.md` (`v2.5.0`: Architecture `§1`, Auth/RBAC `§2`, Modules `§3.1–3.11`, Entities/API `§4`)
- [team/02-ba/USER_STORIES.md](../02-ba/USER_STORIES.md) (`STORY-002`, `DECISION-TC-05`, `DECISION-TC-09`, `DECISION-TC-22`, `DECISION-TC-23`)

---

## 1. Executive Summary

| Scope | Total | Pass | Partial | Fail |
| :--- | :---: | :---: | :---: | :---: |
| **Auth, Security & RBAC (`BR-01`, `FSD §2`, `BRD §6.2/6.5`)** | 5 | 4 | 1 | 0 |
| **Excel Ingestion, DDE & Sync (`BR-02`, `FSD §3.3`, `BRD §6.6`)** | 4 | 3 | 1 | 0 |
| **Map View & Data Table (`BR-03`, `BR-04`, `FSD §3.2/3.4`)** | 5 | 5 | 0 | 0 |
| **Agents, Assignments & Isolation (`BR-05`, `FSD §3.5/3.6`)** | 3 | 3 | 0 | 0 |
| **Forms, Field Visits & Review (`BR-06`, `BR-07`, `FSD §3.7–3.9`)** | 3 | 3 | 0 | 0 |
| **Audit Logs & Unwired/Deferred Modules (`BR-08`, `BRD §4.2/6.1/6.3/6.4`, `FSD §3.10–3.11`)** | 4 | 4 | 0 | 0 |
| **Total Business Test Cases** | **24** | **22** | **2** | **0** |

### Post-Fix Automated & Non-Destructive Execution Summary
- **`scripts/test_qa_remediation.js`**: **34 Passed, 0 Failed** against `http://localhost:5000/api`.
- **Isolated `api/index.js` Verification (`PORT=5099`, `ENABLE_RATE_LIMIT_TEST=true`, `BLOB_READ_WRITE_TOKEN=""`):**
  - `TC-07`: **PASS** — `POST /api/excel/parse` neutralized `=CMD|'/C calc'!A0`, `+1+1`, `-1+1`, `@SUM(1,1)` in `rowObj` (`raw_data_json`) and preserved `-5.5`.
  - `TC-24`: **PASS** — `POST /api/columns` and `POST /api/columns/toggle` persisted `columns` changes to `DB_FILE` (`saveDbStore()` + `await saveDatabaseToBlob()`).
  - `TC-03`: **PASS** — 6 consecutive failed logins returned `[401, 401, 401, 401, 401, 429]` with `ENABLE_RATE_LIMIT_TEST=true`.
- **Operational Deployment Notes:**
  1. `http://localhost:5000` is still running the pre-fix Node process and returned un-neutralized `rowObj` on `POST /api/excel/parse`; **restart the `localhost:5000` server** to activate the `api/index.js` fixes (`TC-07`, `TC-24`, `TC-03`).
  2. Flutter SDK is not installed on this machine, so `public/` was **not** rebuilt after Dev's `upload_view.dart` `.csv` fix (`TC-06`).
- **Safety Rule Respected:** Destructive endpoints (`POST /api/excel/confirm`, `DELETE /api/chillers/clear`, `POST /api/admin/clear-all-batches`, `POST /api/admin/restore-master-dataset`) were **not** executed against `localhost:5000` to preserve the live `1,403`-chiller / `7`-batch Vercel Blob dataset.

---

## 2. Business Test Cases & Execution Matrix

| ID | Traceability | Test Case & Scenario | Status | Evidence & Observation | Triage / Routing |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **TC-01** | `BR-01`, `FSD §2.1` | **Authentication, PBKDF2-SHA512 & Session Validation:** Login as `admin`, `omnia`, `mina` via `POST /api/auth/login`, verify JWT and `GET /api/auth/me` enrichment. | **Pass** | All 3 accounts returned HTTP `200`; `/api/auth/me` returned `role: 'admin'` and `omnia` with `agentArea: 'مصر الجديدة'`. PBKDF2-SHA512 (100k iterations, `timingSafeEqual`) verified in `api/index.js:102-146` and 7-day `exp` in `api/index.js:198`. | — |
| **TC-02** | `BR-01`, `BRD §4.3`, `BRD §6.5`, `USER_STORIES.md` (`STORY-002`) | **Password Policy & Self-Service Change Password UI:** Verify password complexity enforcement and availability of user-facing Change Password UI. | **Partial** | BA approved `STORY-002` as **In-Scope for `v2.5.x`**. `POST /api/auth/change-password` (`api/index.js:1106`) and `ApiService.changePassword` (`api_service.dart:111`) exist, but `changePassword` is not yet wired into any UI dialog in `frontend/lib/`. | **`[ROUTE -> DEV]`** Implement the `STORY-002` Change Password dialog in `frontend/lib/` and rebuild `public/`. |
| **TC-03** | `BR-01`, `FSD §2.1` | **Brute-Force Login Rate Limiting:** Submit 6 consecutive failed logins to verify `429` 5-minute lockout. | **Pass** | `checkRateLimit()` (`api/index.js:168-180`) now supports `ENABLE_RATE_LIMIT_TEST === 'true'`. Isolated verification on `PORT=5099` with `ENABLE_RATE_LIMIT_TEST=true` returned `[401, 401, 401, 401, 401, 429]`. | — |
| **TC-04** | `BR-01`, `FSD §2.2` | **RBAC Matrix (`owner` vs `admin` vs `agent`):** Verify role scoping across API and UI navigation. | **Pass** | Agent `omnia` received `403` on `POST /excel/parse`, `POST /assignments`, `POST /forms`, `GET /delta`, `GET /logs`. `admin` received `403` on `GET /logs` & `POST /logs/toggle`. `frontend/lib/main.dart:111,154` restricts `SystemLogsViewScreen` to `isOwner`. | — |
| **TC-05** | `BRD §6.2`, `FSD §4.2`, `DECISION-TC-05` | **Public `/api/health` Data Exposure Check:** Verify `GET /api/health` returns only sanitized summary fields. | **Pass** | Live `GET /api/health` (`200`) returned `{ status, version, storage: { type, cloudSync, lastSync, chillersCount: 1403, batchesCount: 7, blobConfigured }, timestamp }` (`api/index.js:932-946`). `BRD.md §6.2` and `USER_STORIES.md` updated to match. | — |
| **TC-06** | `BR-02`, `FSD §3.3` | **Excel/CSV Upload & Sheet Auto-Detection:** Upload `.xlsx`/`.xls`/`.csv` (up to 25MB), auto-detect `CE_Database`/`CW_Database` or largest sheet. | **Partial** | Dev added `'csv'` to `allowedExtensions: ['xlsx', 'xls', 'csv']` in `frontend/lib/views/upload_view.dart:51`, and backend `POST /api/excel/parse` accepts `.csv`. However, Flutter SDK is not installed locally so `public/` was not rebuilt. | **`[ROUTE -> DEV]`** Rebuild Flutter Web (`flutter build web`) into `public/` in a Flutter-equipped environment. |
| **TC-07** | `BR-02`, `FSD §3.3` | **DDE Formula Injection Neutralization (`=`, `+`, `-`, `@`):** Parse spreadsheet containing formula payloads and verify both normalized fields and `rowObj` (`raw_data_json`). | **Pass** | `neutralizeFormula()` (`api/index.js:581-587`) is now applied to `rowObj` (`api/index.js:683`). Isolated `PORT=5099` test verified `=CMD...`, `+1+1`, `-1+1`, `@SUM(1,1)` neutralized in `rowObj` and `-5.5` preserved. *(Note: Restart `localhost:5000` server to serve updated `api/index.js`.)* | — |
| **TC-08** | `BR-02`, `FSD §3.3` | **Inverted Cairo GPS Auto-Correction:** Parse row with `lat=31.325, lng=30.091` and verify automatic coordinate swap. | **Pass** | Live `POST /api/excel/parse` returned `latitude: 30.091, longitude: 31.325, validCount: 1` via `parseCoords()` (`api/index.js:631-633`). | — |
| **TC-09** | `BR-02`, `BRD §6.6`, `DECISION-TC-09` | **Incremental `UPSERT` Commit & `onlyThisBatch` Flag:** Verify upload commit behavior and `onlyThisBatch` policy. | **Pass** | BA confirmed in `BRD.md §6.6` and `USER_STORIES.md` (`[DECISION-TC-09]`) that `onlyThisBatch: false` (incremental `UPSERT` only) is intentional for `v2.5.0` to prevent accidental master dataset wipe (`api_service.dart:235`). | — |
| **TC-10** | `BR-03`, `FSD §3.2` | **Map Pin Color & Icon Priority:** Verify `accepted` > `submitted` > `reopened` > `efficiency` (`Performing`/`Non-Performing`/`Zero`/Other). | **Pass** | Verified in `frontend/lib/views/map_view.dart:240-250, 779-795`. Priority order and hex colors match `FSD §3.2`. | — |
| **TC-11** | `BR-03`, `FSD §3.2` | **Map Toolbar, GPS "My Location", Haversine Radius (`1–50 km`), & Surrounding Panel:** Verify proximity filtering and collapsible toolbar. | **Pass** | Verified in `map_view.dart:29, 34-143` (`_radiusOptions`, Haversine formula, `_isToolbarMinimized`). | — |
| **TC-12** | `BR-03`, `FSD §3.2` | **Chiller Details Modal & Dynamic Action Label:** Verify `rawData` display, `reopened` feedback banner, and button labels. | **Pass** | Verified in `map_view.dart:279-345, 453-485` (`Complete Visit`, `Resubmit Visit Audit`, `Update Audit Form`). | — |
| **TC-13** | `BR-04`, `FSD §3.4` | **Universal Data Table — 36+ Columns, Omni-Search, & Top-25 Value Chips:** Verify schema extraction and filtering. | **Pass** | Live `GET /api/columns` returned `36` columns; `data_table_view.dart:193-220, 271-275` implements all-column omni-search and top-25 value-frequency chips. | — |
| **TC-14** | `BR-04`, `FSD §3.4` | **Data Table — 3-State Numeric-Aware Sort, Column Visibility, Pagination, & CSV Export:** Verify sorting, pagination, and export. | **Pass** | Verified in `data_table_view.dart:185-257` (strips commas/spaces/`EGP` for numeric sort, 3-state cycle, `25/50/100/250/500` pagination, CSV export). | — |
| **TC-15** | `BR-05`, `FSD §3.5` | **Sales Agent CRUD, Linked Login & Cascade:** Verify agent listing, search, linked user creation, cascade edit/delete, and password reset. | **Pass** | Live `GET /api/agents` returned `2` agents for Admin; `agents_view.dart` and `api/index.js` cascade logic verified. (Mutating CRUD skipped on live store.) | — |
| **TC-16** | `BR-05`, `FSD §3.6` | **Territory Assignment (Single, Bulk "Select All", Reassign, Unassign):** Verify assignment management. | **Pass** | Live `GET /api/assignments` returned `2` assignments for Admin; `assign_locations_view.dart` and `api/index.js:1812-1893` verified. | — |
| **TC-17** | `BR-05`, `BR-01`, `FSD §2.2` | **Strict Agent Horizontal Isolation (`omnia` vs `mina`):** Verify agents only see assigned chillers, own PII, and assigned responses. | **Pass** | Live: `omnia` saw `1` chiller, `1` agent record, `2` assignments, `5` responses; `mina` saw `0` across all. `test_qa_remediation.js` confirmed `403` on unassigned chiller submission. | — |
| **TC-18** | `BR-06`, `FSD §3.7` | **Dynamic Audit Form Builder (`text`, `choose`, `attachments`) & Targeting:** Verify form templates and agent scoping. | **Pass** | Live `GET /api/forms` returned `1` form for Admin & Omnia; `forms_manager_view.dart:329-331` & `api/index.js:2048-2127` verified. | — |
| **TC-19** | `BR-06`, `FSD §3.8` | **Field Visit Execution & Attachment Upload:** Verify 3.0 MB limit, >800 KB downscaling to 1280px, and MIME/extension checks. | **Pass** | `form_filler_dialog.dart:97-152` enforces 3.0 MB max & >800 KB downscale; `test_qa_remediation.js` verified `400` for `text/html`/`.exe` and `200` for valid PNG. | — |
| **TC-20** | `BR-07`, `FSD §3.9` | **Admin Visit Review State Machine:** Verify `submitted` → `accepted` / `reopened` (mandatory feedback) → `submitted`. | **Pass** | Live `GET /api/form-responses` returned `5` responses; `form_responses_view.dart:54-134, 338-382` & `api/index.js:2306-2365` verified. | — |
| **TC-21** | `BR-08`, `FSD §3.10` | **Owner-Only System Audit Logs:** Verify Owner-only access, 6s auto-refresh, 2,500 cap, filters, JSON inspector, export, clear. | **Pass** | Live `admin` & `omnia` received `403` on `/api/logs*`. `system_logs_view.dart:22-270` & `api/index.js:840-930` implement all specified controls. | — |
| **TC-22** | `BRD §4.2, §6.1`, `FSD §3.11`, `DECISION-TC-22` | **Unwired Modules (`Batch Manager`, `Delta Comparison`, `Columns Manager`):** Verify UI wiring vs backend readiness. | **Pass** | BA formally deferred these 3 views to `v2.6.0` in `BRD.md §4.2, §6.1` and `USER_STORIES.md` (`[DECISION-TC-22]`), matching current `main.dart` navigation and live backend endpoints (`/api/batches`, `/api/delta`, `/api/columns`). | — |
| **TC-23** | `BRD §6.3`, `FSD §3.11`, `DECISION-TC-23` | **Immutable Batches (`DELETE /api/batches/:id` → `403`) vs `clear-all-batches`:** Verify batch deletion policy. | **Pass** | Live `DELETE /api/batches/1` returned `403` (`api/index.js:1553-1558`). BA confirmed in `BRD.md §6.3` and `USER_STORIES.md` (`[DECISION-TC-23]`) that single-batch deletion remains permanently disabled. | — |
| **TC-24** | `BRD §6.4`, `FSD §3.11` | **Custom Columns Persistence (`POST /api/columns`, `POST /api/columns/toggle`):** Verify column schema mutations persist across restarts. | **Pass** | `api/index.js:1200-1225` now calls `saveDbStore(dbStore)` and `await saveDatabaseToBlob(dbStore)`. Isolated `PORT=5099` test verified column creation and toggle persisted to `DB_FILE`. | — |

---

## 3. Remaining Triage & Routing Summary (2 Open Items)

### `[ROUTE -> DEV]` (2 Partial items)
1. **TC-02 (`Partial` — `STORY-002`):** `frontend/lib/services/api_service.dart:111` — Wire `ApiService.changePassword` into a user-facing Change Password dialog for `owner`, `admin`, and `agent` per `team/02-ba/USER_STORIES.md` (`STORY-002`) and rebuild `public/`.
2. **TC-06 (`Partial` — Build Pending):** `frontend/lib/views/upload_view.dart:51` — Dart source updated with `'csv'`, but `public/` must be rebuilt with `flutter build web` on a machine with Flutter SDK installed (and `localhost:5000` restarted to serve updated `api/index.js`).

### `[ROUTE -> BA]` (0 items)
All 5 previously routed BA items (`TC-05`, `TC-23`, `TC-02`, `TC-09`, `TC-22`) have been resolved and documented in `BRD.md` and `team/02-ba/USER_STORIES.md`.
