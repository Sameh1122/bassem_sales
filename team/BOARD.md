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
- [x] **OPS-01 & Live Local QA (`http://localhost:5000`):** Compiled Flutter Web UI via CI (`p5-local-build`), pulled `public/`, restarted `:5000`, and passed **8/8** live QA items (**67 Passed, 0 Failed** assertions, `0` browser console/HTTP errors).
- [x] **Sprint 3 (Sales Hierarchy RBAC, Role Dashboards & Statistics):** Implemented `owner`, `regional_manager`/`admin`, `supervisor`, `agent`, `technician` RBAC (`ADR-008`), `GET /api/stats/dashboard`, `PATCH /api/chillers/:id/condition`, [dashboard_widgets.dart](../frontend/lib/widgets/dashboard_widgets.dart), [dashboard_view.dart](../frontend/lib/views/dashboard_view.dart) (Tab 0 `Home`), and updated [../docs/USER_GUIDE.md](../docs/USER_GUIDE.md). CI Run `44551234822` succeeded; live `http://localhost:5000` QA passed (**34/34** remediation + headless Chrome `0` errors).
- [x] **Full-Shift Role Simulations:** Hired and ran full daily shifts on `http://localhost:5000` for **Branch Supervisor** (`supervisor@sales.com`), **Field Sales Rep** (`omnia@sales.com`), and **Maintenance Technician** (`tech@sales.com` verified by QA) (`1,403` chillers / `7` batches preserved).
- [x] **Track 1 — Shift Polish & Live Snapshots:** Aligned Supervisor `pendingReviewsCount` (`15` = `GET /api/form-responses`), added `comparedMonthsLabel` (`"Aug → Sep"`) & collapsible same-day audits in [customer_360_drawer.dart](../frontend/lib/views/customer_360_drawer.dart), and captured **7 live authenticated screenshots** into `docs/screenshots/` embedded in [../docs/USER_GUIDE.md](../docs/USER_GUIDE.md).
- [x] **Track 2 — P6 (`v2.7.0`) Architecture & UI/UX Specs:** Published `ADR-009` in [04-tech-lead/ARCHITECTURE_DECISIONS.md](04-tech-lead/ARCHITECTURE_DECISIONS.md) (`GET /api/sync/pull`, `POST /api/sync/batch`, 100m GPS geofencing, geo-stamped photo metadata, `GET /api/form-responses/:id/report`) and `§10` in [03-ui-ux/DESIGN_NOTES.md](03-ui-ux/DESIGN_NOTES.md).

---

## ⚪ Release & Post-Build Items (CI / Ops)
| ID | Scope | Item | Owner | Priority | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BA-07** | `docs/USER_GUIDE.md` | Capture authenticated User Guide snapshots (`02`–`21`) from live `http://localhost:5000` | BA | Medium | Queued |

---

## 🗓️ Upcoming (`P6`–`P9` Vision)
- **P6 (`v2.7.0`):** Offline-First Field Resilience & Trust (PWA/IndexedDB queue, 100m GPS geofencing, geo-stamped photo watermarking & 1-click Audit PDF)
- **P7 (`v2.8.0`):** Automated Service Ops (Maintenance/Scrap SLA ticketing) & Rep Gamification ("Perfect Chiller" scorecards, map-lasso bulk reassignment)
- **P8 (`v3.0.0`):** AI Chiller Purity / OOS / POSM Vision & Predictive Relocation
- **P9 (`v3.2.0`):** Enterprise ERP/DMS/WhatsApp Sync, Executive ROI Console & Multi-Tenant PostgreSQL/PostGIS (`ADR-002`)
