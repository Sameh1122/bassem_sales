# QA Test Plan & Verification Log

**Owner:** QA Tester  
**Existing Report:** [../../QA_REPORT.md](../../QA_REPORT.md)  
**BA Traceability Matrix:** [./BA_TEST_RESULTS.md](./BA_TEST_RESULTS.md)  
**Automated Suite:** [../../scripts/test_qa_remediation.js](../../scripts/test_qa_remediation.js)

---

## Current Baseline (Post-Fix Verification)
- Latest QA Remediation suite (`v2.5.0`) against `http://localhost:5000/api`: **34 Passed, 0 Failed**.
- All 5 security findings and 3 functional edge cases in `QA_REPORT.md` marked **Fixed & Verified**.
- **Official BA & Post-Fix Verification (`BRD.md` + `FSD.md` `v2.5.0` + `USER_STORIES.md`, 2026-11-19)**: Executed **24** business test cases against `http://localhost:5000` (`1,403` chillers, `7` batches in Vercel Blob), an isolated `api/index.js` instance (`PORT=5099`, `ENABLE_RATE_LIMIT_TEST=true`), and `frontend/lib/`:
  - **22 Pass**, **2 Partial**, **0 Fail** (see [BA_TEST_RESULTS.md](./BA_TEST_RESULTS.md)).
  - **Routing Breakdown:** **2** `[ROUTE -> DEV]` items (`TC-02` / `STORY-002` Change Password UI dialog, `TC-06` Flutter Web `public/` rebuild) and **0** `[ROUTE -> BA]` items.
  - **Operational Notes:** Restart `http://localhost:5000` to serve the updated `api/index.js` (`TC-07`, `TC-24`, `TC-03`), and run `flutter build web` on a Flutter-equipped machine to rebuild `public/` (`TC-06`, `TC-02`).
  - **Safety Note:** `scripts/test_local_and_vercel.js` and destructive endpoints (`POST /api/excel/confirm`, `DELETE /api/chillers/clear`, `POST /api/admin/clear-all-batches`) were intentionally **not** run against `http://localhost:5000` to preserve the live Vercel Blob dataset.

## Story & Spec Verification Queue
| Spec / Source | Test Scope | Result | Notes / Routing |
| :--- | :--- | :--- | :--- |
| `BRD.md` (`BR-01..BR-08`, `§4`, `§6`) & `FSD.md` (`§1–§4`) | 24 Business Test Cases (Auth, RBAC, Ingestion, Map, Table, Agents, Assignments, Forms, Review, Logs, Deferred Views) | **22 Pass / 2 Partial / 0 Fail** | See [BA_TEST_RESULTS.md](./BA_TEST_RESULTS.md) (`TC-02`, `TC-06` `[ROUTE -> DEV]`). |
| `scripts/test_qa_remediation.js` | Security & Functional Remediation Regression | **34 Pass / 0 Fail** | Executed against `http://localhost:5000/api`. |
| `USER_STORIES.md` | `STORY-002` + `DECISION-TC-05/09/22/23` | **4 Decisions Verified / 1 Story Pending Dev** | `STORY-002` (Change Password UI) approved for `v2.5.x` (`TC-02` `[ROUTE -> DEV]`). |

---

## Sprint 1 Verification Results (2026-11-19)
**Summary:** **4 Pass, 2 Partial, 0 Fail** (6 Sprint 1 verification items)

| # | Verification Item | Scope / Files | Result | Findings & Routing |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `GET /api/stats/rep-kpi` (Code Audit & Isolated Server Test) | `api/index.js:1528-1573` | **PASS** | Code audit confirmed `requireAuth` + agent territory isolation via `dbStore.assignments`. Isolated server (`PORT=0`, `BLOB_READ_WRITE_TOKEN=""`) returned: unauth `401`, admin `200` (`scope: "aggregate"`, `1403` chillers), agent `omnia@sales.com` `200` (`scope: "territory"`, `assignedCount: 1`). *(Note: live `http://localhost:5000` still returns `404` until process restart.)* |
| 2 | `STORY-002` Change Password UI | `frontend/lib/main.dart`, `frontend/lib/services/api_service.dart` | **PARTIAL** | Dart wiring verified (`AppBar` `IconButton` at `:263-267`, `Drawer` `ListTile` at `:627-638`, `_showChangePasswordDialog()` at `:317-482`, `ApiService.changePassword()` at `:111-123`). `public/` bundle rebuild pending `.github/workflows/flutter-build.yml` CI (`[ROUTE -> DEV / CI]`). |
| 3 | `STORY-003` / `ROAD-04` Rep KPI Summary Strip | `frontend/lib/views/map_view.dart`, `api_service.dart`, `api/index.js` | **PARTIAL** | `fetchRepKpi()` (`:804-811`) and `_buildRepKpiStrip()` (`:754-834`) wired in `MapViewScreen`. Gaps vs `USER_STORIES.md` `STORY-003`: (a) `public/` rebuild pending CI & `:5000` restart; (b) `Avg Achievement %`, `Branch Target Rollup` popover, and click-to-filter KPI pills not yet implemented (`[ROUTE -> DEV]`). |
| 4 | QA Remediation Regression Suite | `scripts/test_qa_remediation.js` vs `http://localhost:5000/api` | **PASS** | **34 Passed, 0 Failed** (non-destructive). |
| 5 | `v2.5.0` User Guide & Login Screenshot | `docs/USER_GUIDE.md`, `docs/screenshots/01_login_screen.png` | **PASS** | `01_login_screen.png` (`133,617` bytes) exists; `USER_GUIDE.md` (`159` lines) accurately reflects `v2.5.0` AS-IS features, RBAC, and endpoints. |
| 6 | DevOps Flutter Web CI Workflow | `.github/workflows/flutter-build.yml` | **PASS** | Triggers on `frontend/**` changes to `main`, runs `flutter test`, `flutter build web --release`, `node scripts/build.js`, and commits `public/`. |

---

## Sprint 2 Verification Results (2026-11-19)
**Summary:** **4 Pass, 2 Partial, 0 Fail** (6 Sprint 2 verification items)

| # | Verification Item | Scope / Files | Result | Findings & Routing |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `GET /api/stats/rep-kpi` (Code Audit & Ephemeral Server Test) | `api/index.js:1674-1724` | **PASS** | Code audit & isolated ephemeral server (`PORT=0`, `BLOB_READ_WRITE_TOKEN=""`) verified **9/9** assertions: unauth `401`, admin `200` (`scope: "aggregate"`, `avgAchievement: 66.4`, `5` `branchRollups`), `?branch=CE` filter (`assignedCount: 1397`, pre-filter `branchRollups` preserved), agent `omnia@sales.com` `200` (`scope: "territory"`, `assignedCount: 1`, `branchRollups` omitted). |
| 2 | `GET /api/chillers/:id/360` (Code Audit & Ephemeral Server Test) | `api/index.js:1726-1893` | **PASS** | Code audit & isolated ephemeral server verified **7/7** assertions: unauth `401`, nonexistent `404`, out-of-territory agent `403`, valid in-territory chiller `200` with 12-month Jan–Dec `invoiceSummary.months`, newest-first `visitHistory` (`len=8`), and 5-tier `nextBestAction` (`healthy_upsell`). |
| 3 | `GET /api/routes/daily` (Code Audit & Ephemeral Server Test) | `api/index.js:1895-2068` | **PASS** | Code audit & isolated ephemeral server verified **7/7** assertions: unauth `401`, admin `200` (`scope: "aggregate"`, `limit=10` respected, `skippedNoCoordsCount: 290`, `totalEstimatedKm: 12.26`, sequential `1..N` stops), agent `200` (`scope: "territory"`, `totalStops: 1`, `skippedNoCoords: 0`). |
| 4 | QA Remediation Regression Suite | `scripts/test_qa_remediation.js` vs `http://localhost:5000/api` | **PASS** | **34 Passed, 0 Failed** (non-destructive against live `:5000`). |
| 5 | Sprint 2 Flutter UI Wiring (`STORY-003`, `STORY-004`, `STORY-005`) | `frontend/lib/services/api_service.dart`, `customer_360_drawer.dart`, `map_view.dart`, `data_table_view.dart` | **PARTIAL** | Dart code audit confirmed full wiring against `DESIGN_NOTES.md` & `USER_STORIES.md`: `ApiService` (`:804-858`), `_buildRepKpiStrip()` (`:1087-1210+`) + `_showBranchRollupDialog()` (`:1000-1085`), `showCustomer360Drawer()` (`customer_360_drawer.dart`, `map_view.dart:418-426`, `data_table_view.dart:959-965`), and `_buildRoutePlannerPanel()` (`:657-997`) + `PolylineLayer` (`:1344`) + `"Plan My Day"` FAB (`:1913-1928`). **Pending:** `public/` Flutter Web rebuild via CI and `:5000` restart (`[ROUTE -> DEV / CI]`). |
| 6 | Sprint 2 User Guide & Screenshots | `docs/USER_GUIDE.md` | **PARTIAL** | `docs/USER_GUIDE.md` documents Sprint 1 & 2 features (`§3.1`–`§3.3`), but Delivery Snapshot Checklist (`:27-28`) still lists Sprint 2 items as `Pending implementation & capture` and authenticated screenshots `02`–`13` await `public/` rebuild + `:5000` restart (`[ROUTE -> DOCS / CI]`). |

---

## P3 Modular Backend QA Sign-Off (2026-11-19)
**Sign-Off Status:** **PASS (Signed Off)** — **69 Passed, 0 Failed** across modularized backend (`35/35`) and live `:5000` remediation regression (`34/34`).

| # | Verification Suite / Scope | Target | Result | Key Assertions Verified |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Auth, RBAC & Rate Limiting | Isolated `api/index.js` (`PORT=0`, `ENABLE_RATE_LIMIT_TEST=true`) | **8 Pass / 0 Fail** | Admin/Agent logins (`200`), unauth/tampered JWT `/api/auth/me` (`401`), `/api/logs` owner-only RBAC (`403` for agent & admin), IP rate limit (`429` after repeated failed logins). |
| 2 | Health & Admin Diagnostics | `api/routes/admin.js:118-151` | **5 Pass / 0 Fail** | `/api/health` (`200`, omits `users`/`blobTokenPrefix`/`matchingEnvKeys`), `/api/admin/diagnostics` (`401` unauth, `403` agent, `200` admin with sanitized user fields). |
| 3 | CORS Allow / Block (`ADR-005`) | `api/utils/security.js:165-195` | **3 Pass / 0 Fail** | Allows `http://localhost:5000` and `https://gallant-maxwell.vercel.app`; blocks `https://evil.example.com` (no `Access-Control-Allow-Origin`). |
| 4 | `GET /api/stats/rep-kpi` | `api/routes/chillers.js:208-254` | **4 Pass / 0 Fail** | `401` unauth; admin aggregate (`1403` chillers, `5` `branchRollups`, `avgAchievement`); `?branch=CE` (`1397`, preserves `branchRollups`); agent `omnia@sales.com` territory scope (`1` chiller, no `branchRollups`). |
| 5 | `GET /api/chillers/:id/360` | `api/routes/chillers.js:256-419` | **4 Pass / 0 Fail** | `401` unauth; `404` nonexistent; `403` out-of-territory agent (`mina@sales.com`); `200` in-territory (`id=2413`) with 12-month `invoiceSummary.months`, `visitHistory`, `nextBestAction.actionCode` (`healthy_upsell`). |
| 6 | `GET /api/routes/daily` | `api/routes/chillers.js:421-590` | **3 Pass / 0 Fail** | `401` unauth; admin `?limit=10` (`10` sequential `order: 1..10` stops, `totalEstimatedKm: 9.72`); agent `omnia@sales.com` territory scope (`totalStops: 1`). |
| 7 | Columns & Toggle Persistence (`TC-24`) | `api/routes/admin.js:157-188` | **6 Pass / 0 Fail** | `401` unauth `GET /api/columns`, `403` agent `POST /api/columns`, `200` admin add + toggle (`is_active=0`, `is_required=1`), verified via `GET /api/columns` and `DB_FILE` persistence. |
| 8 | DDE Neutralization (`TC-07`) | `api/utils/security.js:149-155`, `api/services/excel.js:100-192` | **2 Pass / 0 Fail** | `neutralizeFormula()` and `POST /api/excel/parse` (XLSX upload) prefix `=`, `+`, `-`, `@` formulas (`'=CMD|'/C calc'!A0`, `'@SUM(1+1)`, `'+1+1`) while preserving negative numbers (`-12.34`). |
| 9 | QA Remediation Regression Suite | `scripts/test_qa_remediation.js` vs `http://localhost:5000/api` | **34 Pass / 0 Fail** | Non-destructive regression pass against live `:5000`. |

---

## P4 & P5 UI/UX QA Verification Results (2026-11-19 — Final Re-verification after `P5-QA-FIX`)
**Summary:** **5 Pass, 1 Partial, 0 Fail** (6 P4 & P5 verification items; `0` `[ROUTE -> DEV]` blockers remaining; Flutter SDK not installed locally, so Dart code audit + balanced delimiter/import/`AppTokens` static sweep across all 31 Dart files in `frontend/lib/` were executed alongside live `:5000` backend regression).

| # | Verification Item | Scope / Files | Result | Findings & Routing |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `STORY-006` Unified Design Tokens, 3 Theme Modes, Skeletons & Mobile Thumb-Zone Nav (`P4`) | `app_tokens.dart`, `app_feedback.dart`, `main.dart`, `map_view.dart`, `data_table_view.dart` | **PASS** | Balanced delimiters & valid imports verified. `AppThemeMode` (`dark`, `light`, `outdoor`) + `AppTokens` `ThemeExtension` (spacing, radius, `metricNum` with `tabularFigures`) persisted via `storage.dart`. `AppSkeleton` (`1100ms` shimmer) & `AppEmptyState` wired in `map_view.dart` & `data_table_view.dart`. `< 768px` mobile `NavigationBar` + `More` sheet (`Admin`/`Owner`) & `My Map`/`My List`/`Route` (`Agent`) wired in `main.dart`. *(Pending CI `flutter build web`.)* |
| 2 | `STORY-007` Map Condition Pin Mode & Drag-and-Drop / Errors-Only Upload (`P4`) | `map_view.dart`, `upload_view.dart`, `drop_zone_helper*.dart` | **PASS** | Balanced delimiters & valid imports verified. `map_view.dart` implements `Efficiency \| Condition` pin mode toggle, dual-signal colors & icons (`Operational`, `Requires Maintenance`, `Scrap`, `Unspecified`), dynamic legend (`_buildMapLegend`), and Condition filter. `upload_view.dart` implements `.xlsx/.xls/.csv` drag-and-drop (25 MB max), 3-stage upload progress (`_uploadStage`), and `All Rows \| Errors Only` toggle. *(Pending CI `flutter build web`.)* |
| 3 | `STORY-008` Data Table Pinning, Density, Multi-Sort & Delta Diff Cards (`P5`) | `data_table_view.dart`, `delta_view.dart` | **PASS** | `data_table_view.dart` implements sticky left column pinning (`_pinnedColumns`, `2px` cyan edge), 3-mode `_TableDensity` (`36px`/`48px`/`60px` persisted in `storage.dart`), 3-level `_SortRule` multi-sort (`Shift+Click` / `+ Sort`), and `onAuditSubmitted` reload. `P5-QA-FIX` resolved all `AppTokens` issues in `delta_view.dart` (`t.displayTitle` at `:147`; `t.metricNum` at `:440`, `:495`, `:634`). Full `AppTokens` sweep across all 31 `.dart` files in `frontend/lib/` confirmed **0** invalid `AppTokens` getters, balanced delimiters, and valid relative imports. *(Pending CI `flutter build web`.)* |
| 4 | `STORY-009` Audit Photo Gallery Lightbox, `AppToast`, Inline Validation & WCAG AA / Arabic RTL (`P5`) | `audit_photo_gallery.dart`, `app_feedback.dart`, `customer_360_drawer.dart`, `form_responses_view.dart`, `form_filler_dialog.dart`, `forms_manager_view.dart`, `login_view.dart`, `main.dart`, `pubspec.yaml` | **PASS** | `AuditPhotoGallery` + `_AuditPhotoLightbox` (`1x–4x` `InteractiveViewer`, keyboard/swipe nav, `Esc`, `Download`, `GPS Verified` dot, shimmer/broken states) wired in `customer_360_drawer.dart:938` & `form_responses_view.dart:284`. `P5-QA-FIX` resolved all prior gaps: (a) `forms_manager_view.dart` now uses `Form` + `AutovalidateMode.onUserInteraction` (`:129`), `TextFormField` (`:135`), `AppToast` (`0` `ScaffoldMessenger` calls), and amber `< 2` options warning badge (`:377-398`); (b) `login_view.dart` uses `Form` (`:211`), `AutovalidateMode.onUserInteraction` (`:213`), `TextFormField` (`:226,292`), and `AppToast` (`:37,58`); (c) `form_filler_dialog.dart` implements `_fieldKeys` + `Scrollable.ensureVisible` auto-scroll to first invalid field (`:187-197`, `:217,225,232,242`); (d) `pubspec.yaml` (`:12-13`) and `main.dart` (`:2,58-68`) include `flutter_localizations`, `supportedLocales: [Locale('en'), Locale('ar')]`, and `localizationsDelegates`. Balanced delimiters & valid imports verified. *(Pending CI `flutter build web`.)* |
| 5 | Backend Regression Suite | `scripts/test_qa_remediation.js` vs `http://localhost:5000` | **PASS** | **34 Passed, 0 Failed** (non-destructive against live `:5000`). |
| 6 | `docs/USER_GUIDE.md` P4 & P5 Coverage & Checklist (`14`–`21`) | `docs/USER_GUIDE.md` | **PARTIAL** | All P4 & P5 features are documented (`§1.2–§1.4`, `§2.1`, `§2.3`, `§3`, `§4`, `§6.3`). **Gap (`[ROUTE -> DOCS / CI]`):** Snapshot Checklist items `14`–`21` (`:29-36`) still read `Pending implementation & capture` and await CI `public/` rebuild + screenshot capture. |


