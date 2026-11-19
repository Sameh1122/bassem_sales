# Project Board — Bassem Sales Platform

**Current Platform Baseline:** **`P3` + `P4` + `P5` Complete (`v2.6.8` — Pending `:5000` Restart & CI `public/` Build)**  
**Last Updated:** 2026-11-19

---

## 🟢 Done (Verified Across P3, P4 & P5)
- [x] **P3 (Backend Modularization `ADR-001` & Hardening `ADR-005`):** Decomposed `api/index.js` (`2,965` → `148` lines) into `api/routes/`, `api/services/`, `api/middleware/`, `api/utils/` + `CORS_ORIGINS` allowlist. **Security Signed Off** (`0` Critical/High/Med) & **QA Signed Off** (**69/69 Pass**).
- [x] **P4 (UI/UX Sprint 1 — `STORY-006`, `STORY-007`):** Implemented `app_tokens.dart` (Dark / Light / Outdoor Field Contrast), `app_feedback.dart` (`AppSkeleton` & `AppEmptyState`), `Efficiency | Condition` map pins, `.xlsx/.xls/.csv` drag-and-drop upload with `Errors Only` preview, and mobile thumb-zone bottom `NavigationBar`.
- [x] **P5 (UI/UX Sprint 2 — `STORY-008`, `STORY-009`):** Implemented Data Table sticky pinning, density toggle & 3-level multi-sort (`data_table_view.dart`), `Before → After` Delta diff cards (`delta_view.dart`), `AuditPhotoGallery` 1x–4x Lightbox (`audit_photo_gallery.dart`), `AppToast` & inline validation + auto-scroll, and `EN / عربي` RTL + `flutter_localizations` + WCAG AA readiness.
- [x] **P4 & P5 QA Sign-Off:** **5 Pass, 1 Partial, 0 Fail** (`STORY-006`–`009` all **PASS**, `34/34` regression **PASS**, `0` `[ROUTE -> DEV]`, `0` `[ROUTE -> BA]`). See [06-qa/TEST_PLAN.md](06-qa/TEST_PLAN.md).
- [x] **BA Living User Guide:** Documented P4 & P5 in [../docs/USER_GUIDE.md](../docs/USER_GUIDE.md) (`§1.2–§1.4`, `§2.1`, `§2.3`, `§3`, `§4`, `§6.3`).

---

## ⚪ Release & Post-Build Items (CI / Ops)
| ID | Scope | Item | Owner | Priority | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **OPS-01** | `P3`–`P5` | Commit & push to `main` to trigger `.github/workflows/flutter-build.yml` (`public/` rebuild) & restart `localhost:5000` Node process | DevOps / User | High | Ready |
| **BA-07** | `docs/USER_GUIDE.md` | Capture authenticated User Guide snapshots (`02`–`21`) after CI `public/` rebuild & `:5000` restart | BA | Medium | Queued |

---

## 🗓️ Upcoming (`P6`–`P9` Vision)
- **P6 (`v2.7.0`):** Offline-First Field Resilience & Trust (PWA/IndexedDB queue, 100m GPS geofencing, geo-stamped photo watermarking & 1-click Audit PDF)
- **P7 (`v2.8.0`):** Automated Service Ops (Maintenance/Scrap SLA ticketing) & Rep Gamification ("Perfect Chiller" scorecards, map-lasso bulk reassignment)
- **P8 (`v3.0.0`):** AI Chiller Purity / OOS / POSM Vision & Predictive Relocation
- **P9 (`v3.2.0`):** Enterprise ERP/DMS/WhatsApp Sync, Executive ROI Console & Multi-Tenant PostgreSQL/PostGIS (`ADR-002`)
