# Task Dispatch — Developers (Web Platform)

**Status:** `PENDING` (Next Flutter Sprint)  
**Assigned By:** Project Manager  
**Source Report:** [../06-qa/BA_TEST_RESULTS.md](../06-qa/BA_TEST_RESULTS.md)  
**Output Location:** [../05-developers/DEV_LOG.md](../05-developers/DEV_LOG.md)

---

## Completed in Previous Cycle
- [x] `TC-24`: Persisted `POST /api/columns` & `POST /api/columns/toggle` in `api/index.js`.
- [x] `TC-07`: Applied `neutralizeFormula()` to `rowObj` (`raw_data_json`) in `api/index.js`.
- [x] `TC-06`: Added `'csv'` to `allowedExtensions` in `frontend/lib/views/upload_view.dart`.
- [x] `TC-03`: Added `ENABLE_RATE_LIMIT_TEST=true` support in `checkRateLimit()`.

## Next Cycle Tasks (Flutter SDK Required)
1. **`[MEDIUM]` `TC-02` (`STORY-002`) — Wire Self-Service Change Password UI:**
   - Implement the Change Password dialog in `frontend/lib/` wired to `ApiService.changePassword` (`frontend/lib/services/api_service.dart:111`) per [../02-ba/USER_STORIES.md](../02-ba/USER_STORIES.md).
2. **`[MEDIUM]` `TC-06` & `STORY-002` — Rebuild Production Web Assets:**
   - Run `flutter build web` (via `scripts/build.js`) on a machine with Flutter SDK installed to update `public/`.
