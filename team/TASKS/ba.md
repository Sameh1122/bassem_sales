# Task Dispatch — Business Analyst (BA)

**Status:** `DONE`  
**Assigned By:** Project Manager  
**Source Report:** [../06-qa/BA_TEST_RESULTS.md](../06-qa/BA_TEST_RESULTS.md)  
**Target Docs:** `C:\Users\skamal\.gemini\antigravity\brain\34abd210-de75-4f73-8114-f14f12b58f0c\BRD.md` & `FSD.md`

---

## Current Task: Resolve QA Documentation & Scope Feedback (`[ROUTE -> BA]`)

1. **`[HIGH]` `TC-05` (Fail — Doc vs Reality):**
   - `BRD.md §6.2` states public `GET /api/health` exposes user emails, roles, salts, hash prefixes, and `blobTokenPrefix`.
   - **Reality:** Public `GET /api/health` (`api/index.js:932-946`) is sanitized; diagnostics were moved behind admin auth at `GET /api/admin/diagnostics` (`api/index.js:948`).
   - **Action:** Update `BRD.md §6.2` (and `FSD.md` if referenced) to match the hardened security behavior.

2. **`[MEDIUM]` `TC-23` (Partial — Batch Deletion Policy):**
   - **Action:** Confirm with PO whether `DELETE /api/batches/:id` remains permanently disabled (`403`) in favor of `POST /api/admin/clear-all-batches`, and update `BRD.md §6.3`.

3. **`[MEDIUM]` `TC-02` (Partial — Shared w/ Dev):**
   - **Action:** Confirm whether self-service **Change Password UI** (`BRD.md §4.3, §6.5`) is in-scope for `v2.5.x` or deferred.

4. **`[MEDIUM]` `TC-09` (Partial — Shared w/ Dev):**
   - **Action:** Confirm whether `onlyThisBatch: true` upload mode (`BRD.md §6.6`) should be enabled (`api_service.dart:235`) or formally removed.

5. **`[MEDIUM]` `TC-22` (Partial — Shared w/ Dev):**
   - **Action:** Confirm whether `batch_manager_view.dart`, `delta_view.dart`, and `columns_view.dart` (`BRD.md §4.2, §6.1`) should be wired into `main.dart` navigation or formally descoped.

## Completion Protocol
1. Update `BRD.md` / `FSD.md` and record scope decisions in [../02-ba/USER_STORIES.md](../02-ba/USER_STORIES.md).
2. Change **Status** at the top of this file to `DONE` and notify PM so `TC-02`, `TC-09`, `TC-22` can be released to Developers.
