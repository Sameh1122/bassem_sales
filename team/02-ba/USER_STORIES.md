# User Stories & Acceptance Criteria

**Owner:** Business Analyst (BA)  
**Collaborators:** Product Owner, UI/UX Designer  
**Reference:** [../../docs/BRD.md](../../docs/BRD.md)

---

## Story Template
Copy this block for each new story:

```markdown
### [STORY-XXX] Short Title
- **Linked PO Goal:** ...
- **UI/UX Spec:** Link to design note / screen
- **As a** <role>, **I want** <capability>, **so that** <value>.
- **Acceptance Criteria:**
  1. Given ..., when ..., then ...
  2. Edge cases / validation rules: ...
```

---

## Active Stories & `v2.5.0` Scope Decisions

### `[DECISION-TC-05]` Sanitized Public Health & Admin Diagnostics
- **QA Reference:** `TC-05` (`BRD.md §6.2`, `FSD.md §4.2`)
- **Decision:** **Resolved in `v2.5.0`.** Public `GET /api/health` (`api/index.js:932-946`) is sanitized (returns only `status`, `version`, `storage` summary, and `timestamp`). Detailed diagnostics are gated behind `requireAdmin` at `GET /api/admin/diagnostics` (`api/index.js:948-965`).

### `[DECISION-TC-23]` Immutable Batches (`DELETE /api/batches/:id` Disabled)
- **QA Reference:** `TC-23` (`BRD.md §6.3`)
- **Decision:** **Confirmed for `v2.5.0` (Permanently Disabled).** `DELETE /api/batches/:id` (`api/index.js:1553-1558`) remains permanently disabled (`403 Forbidden`) to preserve historical snapshot & audit immutability (`BR-02`). Full dataset reset remains available to `admin`/`owner` via `POST /api/admin/clear-all-batches`.

### `[STORY-002]` Self-Service Change Password UI (`TC-02` / `ROAD-01`)
- **Sprint:** Sprint 1 (`v2.6.0` Carry-Over Stabilization)
- **Linked PO Goal:** `ROAD-01` — Close `DEV-05` / `DEV-06` (`STORY-002` Change Password UI & `.csv` web build)
- **QA Reference:** `TC-02` (`BRD.md §4.3, §6.5`, `FSD.md §2.1`)
- **Scope Decision:** **In-Scope for Sprint 1 (Release to Dev: `DEV-05` + `DEV-06`).**
- **As a** logged-in user (`owner`, `admin`, or `agent`), **I want** a "Change Password" dialog in the app navigation/header, **so that** I can rotate my own password without requiring Admin intervention.
- **Acceptance Criteria:**
  1. Given any authenticated user (`owner`, `admin`, or `agent`), when they click "Change Password" in the top `AppBar` or mobile `Drawer`, then a modal dialog prompts for `Current Password`, `New Password`, and `Confirm New Password` (with show/hide visibility toggles).
  2. Client validates that all fields are non-empty and `New Password == Confirm New Password` before calling `ApiService.changePassword(currentPassword, newPassword)` (`POST /api/auth/change-password`).
  3. Backend complexity rules (minimum 8 characters, at least 1 uppercase, 1 lowercase, 1 digit, and 1 special character) and incorrect current password errors (`400`) are surfaced inline inside the dialog without closing it.
  4. On `200 OK`, the dialog closes, a confirmation snackbar is displayed, and the user's updated credentials take effect immediately on next login.
  5. Compiled web bundle (`public/`) is rebuilt via `flutter build web` (`DEV-06`) so both the Change Password UI and `.csv` file picker are live at `http://localhost:5000`.

### `[STORY-003]` Rep KPI Summary Strip & Branch Target Rollups (`ROAD-04`)
- **Sprint:** Sprint 1 (`v2.6.0` Field Execution & Operational Velocity)
- **Linked PO Goal:** `ROAD-04` — Rep KPI Summary Strip & Branch Target Rollups
- **UI/UX Spec:** Top-of-screen KPI Summary Strip above the Map / Data Table workspace (responsive horizontal cards on desktop, 2x2 compact grid on mobile `< 768px`).
- **As a** Field Sales Agent or Operations Admin/Manager, **I want** a live KPI Summary Strip at the top of my workspace, **so that** I can immediately see my assigned chiller coverage, monthly visit progress, pending audits, and target achievement without exporting spreadsheets.
- **Acceptance Criteria:**
  1. **Agent View (`role = agent`)**: Displays 4 live metric cards scoped strictly to the logged-in agent's assigned chillers:
     - `Assigned Chillers`: Total count of chillers assigned to the agent.
     - `Visited This Month`: Count (and `%`) of assigned chillers with at least one submitted visit audit in the current calendar month.
     - `Pending Audits`: Count of assigned chillers with no visit this month or with a `Re-opened` audit status.
     - `Avg Achievement %`: Mean monthly/YTD achievement percentage across the agent's assigned chillers (formatted to 1 decimal place, handling missing/non-numeric cells gracefully as `N/A` without crashing).
  2. **Admin / Owner View (`role = admin | owner`)**: Displays fleet-wide totals for the same 4 KPIs plus a **Branch Target Rollup** selector/popover (grouped by `Branch` column) showing per-branch chiller count, visited %, and average achievement %.
  3. **Interactive Filtering**: Clicking `Visited This Month` or `Pending Audits` filters the active Map / Data Table view to those matching chillers (with a clear active-filter chip to reset).
  4. **Performance & Isolation**: KPI calculations respect horizontal isolation (`agent` only receives their own counts) and resolve in `< 120ms` (`NFR-01`) alongside `/api/chillers` or a dedicated `/api/kpis/summary` endpoint.

### `[DECISION-TC-09]` Incremental `UPSERT` Upload Mode Only (`TC-09`)
- **QA Reference:** `TC-09` (`BRD.md §6.6`, `BR-02`)
- **Scope Decision:** **Intentionally Disabled in `v2.5.0` (No `onlyThisBatch: true` UI).**
- **Rationale:** Allowing a single spreadsheet upload to wipe/replace all 1,403+ master chillers (`onlyThisBatch: true`) introduces high accidental data-loss risk. All uploads in `v2.5.0` remain strictly incremental `UPSERT`s (`onlyThisBatch: false` in `api_service.dart:235`).
- **Dev Note:** Keep `onlyThisBatch: false` behavior (or remove the unused `_onlyThisBatch` state in `upload_view.dart` if cleaning up); do **not** expose a replace-all toggle in `v2.5.x`.

### `[DECISION-TC-22]` Defer Unwired Views to `v2.6.0` (`TC-22`)
- **QA Reference:** `TC-22` (`BRD.md §4.2, §6.1`, `FSD.md §3.11`)
- **Scope Decision:** **Formally Deferred from `v2.5.0` Active Navigation (`v2.6.0` Backlog).**
- **Rationale:** `columns_view.dart` mutations (`POST /api/columns`, `POST /api/columns/toggle`) are in-memory only and do not persist to `DB_FILE`/Vercel Blob (`BRD.md §6.4`). Exposing `batch_manager_view.dart`, `delta_view.dart`, and `columns_view.dart` in `main.dart` would add non-persistent behavior and clutter the 8-tab navigation rail.
- **Dev Note:** Do **not** wire these 3 views into `main.dart` for `v2.5.x`; schedule `columns` persistence + navigation wiring together for `v2.6.0`.

---

## Sprint 2 Stories (`v2.6.0` Field Execution & Operational Velocity)

### `[STORY-004]` Customer 360 Drawer & Next Best Action (NBA) Guided Selling Card (`ROAD-02`)
- **Sprint:** Sprint 2 (`v2.6.0` Field Execution & Operational Velocity)
- **Linked PO Goal:** `ROAD-02` — Customer 360 Drawer + Rule-Based Next Best Action (NBA) Card
- **UI/UX Spec:** Slide-over right-hand drawer on desktop (`>= 768px`) / full-height bottom sheet on mobile (`< 768px`), triggered from any map pin or Data Table row.
- **As a** Field Sales Agent, Operations Admin, or System Owner, **I want** a unified Customer 360 Drawer with a rule-based Next Best Action (NBA) card when I click any chiller pin or table row, **so that** I can review asset condition, `Jan–Dec` financial velocity, and past visit audits in one place and know the highest-value action to take before entering the store.
- **Acceptance Criteria:**
  1. **Trigger & Horizontal Isolation:** Clicking any chiller pin on `Map View` / `My Assigned Customers` (or any row in `Data Table` for `admin`/`owner`) opens the Customer 360 Drawer for that chiller. For `agent`, data is strictly scoped to chillers assigned to that agent; requests for unassigned chillers are blocked (`403`/`404`).
  2. **Header & Asset Profile:** Displays Customer/Outlet Name, `Chiller Code`, `Branch`, `Condition` badge, `Month Ach. Status` badge, serial/asset metadata, and assigned agent name (or `Unassigned`).
  3. **Financial Velocity (`Jan–Dec` Invoice Sparkline & YTD):** Renders a 12-month (`Jan`–`Dec`) invoice trendline/sparkline along with `YTD` total and month-over-month (MoM) delta `%`. Missing, blank, or non-numeric cells (e.g., `-`, `N/A`) are handled gracefully as `0` or `N/A` without crashing.
  4. **Rule-Based Next Best Action (NBA) Guided Selling Card:** Evaluates deterministic rules on the chiller's live data and displays a prioritized action prompt with rationale and a primary CTA:
     - *Maintenance Priority:* `Condition` is `Requires Maintenance`, `Damaged`, or `Scrap` -> **"Log Service / Maintenance Ticket"** (prioritized first so broken assets are escalated).
     - *Revenue Drop:* Latest non-zero invoice month dropped `> 20%` MoM or `YTD` is underperforming -> **"Pitch Restock / Promo"** (highlight volume recovery).
     - *Overdue Visit:* No submitted visit audit in the current calendar month or audit status is `Re-opened` -> **"Complete Monthly Visit Audit"**.
     - *Healthy / On-Track:* Operational and on-target -> **"Reinforce Relationship & Check POSM"**.
  5. **Visit Audit History & Quick Actions:** Lists chronological past visit audits for the chiller (timestamp, status: `Pending`/`Approved`/`Re-opened`, summary answers, photo thumbnails) and provides one-tap **Start / Open Audit Form** and **Get Directions** (Google Maps link) actions.

### `[STORY-005]` Smart Daily Route Planner (`ROAD-03`)
- **Sprint:** Sprint 2 (`v2.6.0` Field Execution & Operational Velocity)
- **Linked PO Goal:** `ROAD-03` — Smart Daily Route Planner ("Plan My Day" + Maps Handoff)
- **UI/UX Spec:** **"Plan My Day"** action button in the `Map View` / `My Assigned Customers` toolbar, opening a collapsible Route Planner panel/sheet with sequenced stops and a numbered polyline overlay on the Leaflet map.
- **As a** Field Sales Agent (or Admin/Owner previewing a territory), **I want** a one-click "Plan My Day" Smart Daily Route Planner on my map, **so that** my assigned chillers are sequenced into an optimal visiting order by urgency and proximity with one-tap Google Maps navigation.
- **Acceptance Criteria:**
  1. **Route Generation ("Plan My Day"):** Clicking **Plan My Day** filters visible/assigned chillers that have valid GPS coordinates (`lat`, `lng`), prioritizes urgent stops (unvisited this month, `Re-opened` audits, `Requires Maintenance`, or underperforming), and sequences them using a nearest-neighbor shortest-path heuristic starting from the user's current GPS position (via `My Location` / browser geolocation, falling back to the territory centroid if geolocation is unavailable or denied).
  2. **Stop Limit & Interactive Selection:** Defaults to up to 10 stops (configurable up to 25) and allows toggling individual chillers in or out of today's route, immediately recalculating stop order and estimated total route distance (`km`).
  3. **Visual Map Polyline & Numbered Pins:** Renders numbered sequence badges (`1, 2, 3...`) and a connecting polyline on the Leaflet map. Clicking any stop in the Route Planner list centers the map on that pin and allows opening its **Customer 360 Drawer** or **Visit Audit Form**.
  4. **One-Tap Google Maps Handoff:** Provides a **Start Navigation (Google Maps)** button that opens a Google Maps multi-stop directions URL (`https://www.google.com/maps/dir/...`) with the sequenced coordinates (safely chunked/capped to Google Maps URL waypoint limits, e.g., up to 10 waypoints per leg), plus a per-stop **Navigate** button for single-stop directions.
  5. **Edge Cases & Isolation:** Chillers missing valid GPS coordinates are excluded from the route and surfaced with a clear notice (e.g., `"N assigned chillers missing GPS excluded"`). All route data strictly respects horizontal territory isolation (`agent` only sees and routes their own assigned chillers).

---

## UI/UX Sprint 1 Stories (P4 — Design System, Navigation & Field Ergonomics)

### `[STORY-006]` Unified Design Tokens, 3 Theme Modes (Dark/Light/Outdoor) & Mobile Thumb-Zone Navigation (`P4`)
- **Sprint:** UI/UX Sprint 1 (`P4`)
- **Linked PO Goal:** `P4` — Design System, Field Legibility & Ergonomic Mobile Navigation
- **UI/UX Spec:** [DESIGN_NOTES.md §6.1, §6.2, §6.5](../03-ui-ux/DESIGN_NOTES.md) (`lib/theme/app_tokens.dart`, `lib/widgets/app_skeleton.dart`, `lib/widgets/app_empty_state.dart`, `main.dart`)
- **As a** Field Sales Agent, Operations Admin, or System Owner using the platform across office desktops and sunlit outdoor retail routes, **I want** a unified design token system with Dark/Light/Outdoor theme switching, structured skeleton loaders/empty states, and thumb-zone mobile bottom navigation, **so that** the interface is legible in direct sunlight, communicates loading/empty states clearly, and is effortless to operate one-handed on mobile.
- **Acceptance Criteria:**
  1. **Unified Design Tokens (`AppTokens` ThemeExtension):** Spacing (`spaceXs=4` to `spaceXl=24`), radius (`radiusSm=8` to `radiusPill=20`), and Material 3 typography scale (including `FontFeature.tabularFigures()` for `metricNum`) are centralized in `lib/theme/app_tokens.dart` and consumed via `Theme.of(context).extension<AppTokens>()!`, eliminating hardcoded inline slate colors in new/updated views.
  2. **3 Theme Modes & Persistence:** Users can switch between `Dark` (default `#0F172A`), `Light` (`#F8FAFC`), and `Outdoor Field Contrast` (`#FFFFFF` canvas, `#020617` text `>= 14:1` contrast, deepened `#0369A1` accent) via a compact theme switcher icon in the `AppBar` (and mobile `More` sheet). The selected `AppThemeMode` persists across reloads in `storage.dart`.
  3. **Cross-App Skeleton Loaders & Empty States:**
     - `AppSkeleton` replaces bare centered spinners with structured shimmer placeholders (`1100ms` loop) tailored to Map View (top `2px` progress bar + skeleton KPI pills), Data Table (8 skeleton rows), Assign/Forms lists (5 skeleton cards), and Customer 360 Drawer sections.
     - `AppEmptyState` renders a consistent `420px` max-width empty state card distinguishing *"No data uploaded yet"* (Admin CTA to Upload) from *"No records match current filters"* (1-tap `"Reset Filters"` CTA).
  4. **Mobile Thumb-Zone Navigation (`< 768px`):**
     - **Admin / Owner:** Bottom `NavigationBar` (`64px` height + `SafeArea`) with 4 primary tabs (`Map`, `Table`, `Assign`, `Responses`) + `More` button opening a `showModalBottomSheet` grid for `Upload & Validate`, `Sales Agents`, `Forms Manager`, `System Logs` (Owner only), and `Theme Mode` toggle.
     - **Sales Agent:** Bottom `NavigationBar` with 3 ergonomic tabs (`My Map`, `My List`, `Route` to jump to Map and toggle Smart Daily Route Mode).
     - **Desktop (`>= 768px`):** Preserves the existing `NavigationRail` (`extended: screenWidth >= 1100`).

### `[STORY-007]` Map Condition Pin Mode & Upload Drag-and-Drop / Errors-Only Preview (`P4`)
- **Sprint:** UI/UX Sprint 1 (`P4`)
- **Linked PO Goal:** `P4` — Field Asset Condition Visibility & Modernized Ingestion UX
- **UI/UX Spec:** [DESIGN_NOTES.md §6.3, §6.4](../03-ui-ux/DESIGN_NOTES.md) (`map_view.dart`, `upload_view.dart`)
- **As a** Field Sales Agent, Maintenance Supervisor, or Operations Admin, **I want** to toggle map pins between Efficiency and physical Condition modes (with dual-signal icons) and upload `.xlsx`/`.xls`/`.csv` sheets via drag-and-drop with an `Errors Only` validation filter, **so that** maintenance/scrap chillers stand out immediately on the map and spreadsheet ingestion errors are isolated before confirming an `UPSERT`.
- **Acceptance Criteria:**
  1. **Map Pin Color Mode Toggle (`Efficiency` | `Condition`):** A compact segmented toggle in `MapViewScreen`'s top-left control bar switches marker coloring between `Efficiency` and `Condition`.
  2. **Condition Dual-Signal Pins & Dynamic Legend:** In `Condition` mode, each `28x28` marker pin renders both its semantic fill color and a `13px` inner icon (`Operational`/`Good`/`Working` -> `#10B981` + `Icons.check_circle_outline`; `Requires Maintenance`/`Maintenance`/`Needs Repair` -> `#F97316` + `Icons.build_circle_outlined`; `Scrap`/`Damaged`/`Decommissioned` -> `#EF4444` + `Icons.dangerous_outlined`; `Unknown`/empty/`-` -> `#64748B` + `Icons.help_outline`). The floating map legend updates dynamically to match the active mode, and a quick `Condition` filter chip allows 1-tap isolation of maintenance/scrap assets.
  3. **Interactive Drag-and-Drop Dropzone (`upload_view.dart`):** Replaces the top button row with a responsive 2-column Dropzone + Quick Actions card (stacked on `< 768px`, `minHeight: 160px`) supporting `.xlsx`, `.xls`, and `.csv` up to `25 MB`. Visual border/tint reacts to `dragOver` (`#06B6D4`), valid drop (`#10B981`), and invalid file extension (`#EF4444`), and shows filename, size badge, progress bar, and step indicator (`1. Uploading` -> `2. Validating Columns` -> `3. Ready for UPSERT`).
  4. **Validation Preview `Errors Only` Toggle:** Above the validation preview table, a segmented toggle (`All Rows` | `Errors Only`) lets admins isolate failing/incomplete rows before choosing strict vs bypassed `UPSERT` (`onlyThisBatch: false`).

---

## UI/UX Sprint 2 Stories (P5 — Visual Intelligence, Micro-Interactions & Polish)

### `[STORY-008]` Data Table Pinning, Density Toggle & Multi-Sort + Delta Diff Cards (`P5`)
- **Sprint:** UI/UX Sprint 2 (`P5`)
- **Linked PO Goal:** `P5` — Power-User Data Table Ergonomics & Visual Batch Diffing
- **UI/UX Spec:** [DESIGN_NOTES.md §7.1, §7.2.2](../03-ui-ux/DESIGN_NOTES.md) (`data_table_view.dart`, `delta_view.dart`)
- **As an** Operations Admin or System Owner reviewing 36+ column chiller datasets and batch deltas, **I want** sticky left column pinning, row density controls, multi-column sorting (up to 3 levels), and visual Before/After Delta Diff cards, **so that** I never lose customer context while scrolling horizontally and can spot asset/financial changes at a glance.
- **Acceptance Criteria:**
  1. **Sticky Left Column Pinning:** `360° Action + Chiller Code + Customer Name` (configurable via `"Pin"` icon in Column Visibility dialog) remain frozen on the left, synchronized vertically with the horizontally scrollable remaining columns, separated by a `2px` `#06B6D4` (`0.25` opacity) edge shadow/border.
  2. **Row Density Toggle:** Segmented toolbar control switches between `Compact` (`36px` row height, `12px` font), `Standard` (`48px`, `13px` default), and `Comfortable` (`60px`, `13.5px` + wrapped address), persisted in `storage.dart`.
  3. **Multi-Column Sorting (Max 3 Levels):** Replaces single-column sort with `List<SortRule>` (Primary, Secondary, Tertiary). Clicking a header sets/toggles primary sort; `Shift + Click` (Desktop) or `+ Sort` in the column menu (Mobile/Touch) appends secondary/tertiary rules. Headers display numbered badges (`1 ↑`, `2 ↓`), with a dismissible active-sort chip bar above the table.
  4. **Before/After Delta Visual Diff Cards (`delta_view.dart`):** Replaces dense raw diff rows with structured cards showing `Chiller Code`, `Customer Name`, Change Type pill (`Added` `#10B981`, `Removed` `#EF4444`, `Modified` `#F59E0B`), side-by-side field diff pills (`Before -> After` for `Condition`, `Efficiency`, and numeric `YTD Invoice` delta), and an `"Open 360°"` quick action.

### `[STORY-009]` Audit Photo Gallery Lightbox, AppToast & WCAG AA / Arabic RTL Readiness (`P5`)
- **Sprint:** UI/UX Sprint 2 (`P5`)
- **Linked PO Goal:** `P5` — Visual Evidence Review, Unified Feedback & Inclusive Accessibility/RTL
- **UI/UX Spec:** [DESIGN_NOTES.md §7.2.1, §7.3, §7.4](../03-ui-ux/DESIGN_NOTES.md) (`customer_360_drawer.dart`, `form_responses_view.dart`, `lib/widgets/app_toast.dart`, `main.dart`)
- **As a** Field Sales Agent, Reviewer, or Operations Admin, **I want** a zoomable photo gallery lightbox for visit audit evidence, consistent floating toast/inline form validation feedback, and WCAG AA touch targets with Arabic RTL layout support, **so that** field photos can be inspected clearly, form errors are actionable, and the platform is accessible and ready for bilingual `EN`/`AR` usage.
- **Acceptance Criteria:**
  1. **Audit Photo Gallery & Lightbox (`customer_360_drawer.dart`, `form_responses_view.dart`):** Renders `80x80` rounded-8 thumbnails in a `3-column` (Drawer) or `4-column` (Responses) grid with `Photo N/M`, timestamp, and `GPS Verified` dot badges, plus shimmer loading and `Icons.broken_image_outlined` fallback states. Tapping any thumbnail opens a full-screen `Colors.black87` lightbox with `InteractiveViewer` (`1x–4x` zoom), Left/Right keyboard & swipe navigation, metadata footer (Rep, Chiller Code, Date, Condition), `Esc` to close, and `Download` button.
  2. **Unified `AppToast` & Inline Form Validation:**
     - `AppToast.show(context, type: ..., message: ..., actionLabel: ...)` standardizes floating toasts (`maxWidth: 460px` desktop, positioned above mobile `NavigationBar`, `4px` left semantic accent bar, `3s` auto-dismiss for `success`/`info`, `5s` for `warning`/`error`).
     - Forms (`forms_manager_view.dart`, `form_filler_dialog.dart`, `login_view.dart`) use `AutovalidateMode.onUserInteraction` after first submit, `1.5px` `#EF4444` invalid borders with inline helper text, auto-scroll to the first invalid field, and an inline warning badge on `"choose"` fields with `< 2` options.
  3. **WCAG AA Accessibility & Touch Targets:** All mobile `IconButton`s, map pins, and filter chips enforce `44x44` minimum tap targets (`MaterialTapTargetSize.padded`); custom `InkWell`/`GestureDetector` controls include `Semantics(button: true, label: ...)`; keyboard `Tab` focus rings and `Esc` dismissal for drawers/modals are supported.
  4. **Arabic RTL Layout Readiness:** `MaterialApp.supportedLocales` includes `Locale('en')` and `Locale('ar')` with `flutter_localizations` and an `EN` / `عربي` toggle in the `AppBar` / `More` sheet. Directional layout properties migrate to `EdgeInsetsDirectional`, `AlignmentDirectional`, and `BorderDirectional`, while Chiller Codes, GPS coordinates, and numeric KPIs remain wrapped in `TextDirection.ltr`.

---

## Sprint 3 Stories (Sales Hierarchy RBAC, Analytics Dashboard & Role-Tailored Workflows)

### `[STORY-010]` Sales Hierarchy RBAC & Permissions (`owner`, `admin`/`regional_manager`, `supervisor`, `agent`, `technician`)
- **Sprint:** Sprint 3
- **Linked PO Goal:** Sales Hierarchy RBAC & Permissions
- **UI/UX Spec:** `agents_view.dart` (Role & Branch/Team assignment), `main.dart` (Role-scoped navigation & role badge), `api/middleware/auth.js`, `api/routes/agents.js`
- **As a** System Owner or Operations Admin, **I want** a 5-tier Sales Hierarchy RBAC model (`owner`, `admin`/`regional_manager`, `supervisor`, `agent`, `technician`) with branch/team scoping and role management in the Admin/Agents UI, **so that** supervisors can manage their branch/team, technicians can focus on maintenance chillers, and existing `owner`/`admin`/`agent` accounts continue working without breaking changes.
- **Acceptance Criteria:**
  1. **Backward-Compatible Role Normalization & Hierarchy:**
     - Supported roles: `owner` (highest), `admin` / `regional_manager` (equivalent operational admin tier; `regional_manager` treated as `admin` or optionally branch-scoped when `branch`/`area` is assigned), `supervisor` (team/branch lead), `agent` (field sales rep), and `technician` (field maintenance specialist).
     - Existing `owner`, `admin`, and `agent` accounts, tokens, and `requireAuth` / `requireAdmin` / `requireOwner` checks remain 100% backward-compatible.
     - New/updated auth middleware helpers (e.g., `requireRole(...roles)` / `requireSupervisorOrAbove`) enforce role-based access cleanly and return `401` (unauthenticated) or `403` (insufficient role).
  2. **Role-Based Data & Action Scoping:**
     - `owner`: Full global access including `System Logs`, user/role management, batch uploads, and all branches/teams.
     - `admin` / `regional_manager`: Full operational access (Map, Upload, Assign, Agents, Data Table, Forms Manager, Visit Responses, Dashboard); scoped to `branch`/`area` if configured on `regional_manager`, otherwise global (excluding `owner`-only system logs/destructive resets).
     - `supervisor`: Scoped to their assigned `branch`/`area` or `team_agent_ids` across `/api/chillers`, `/api/agents`, `/api/assignments`, and `/api/form-responses` (`Pending` / `Approved` / `Re-opened` visit review for their team). Cannot access `System Logs` or `Upload & Validate` master dataset ingestion.
     - `agent`: Strictly isolated to their own assigned chillers (`agent_id`) for map, list, Customer 360, route planner, and visit form submission.
     - `technician`: Scoped to the **Maintenance Queue** — chillers whose `Condition` is `Requires Maintenance`, `Damaged`, or `Scrap` (optionally filtered by technician's `branch`/`area` if set). Technicians can view Customer 360 and update chiller `Condition` / repair status (e.g., `Operational`) via a dedicated endpoint, but cannot edit sales financials, reassign sales reps, or manage forms/uploads.
  3. **Admin / Agents UI Role Management (`agents_view.dart`):**
     - Admin/Owner can create and edit users/agents with a **Role** selector (`agent`, `supervisor`, `technician`, `regional_manager`, `admin`; `owner` assignable only by `owner`), **Branch / Area** field, and optional **Team Members / Supervisor** assignment.
     - Existing agent creation (`POST /api/agents`) defaults `role` to `'agent'` when omitted, preserving backward compatibility.
     - Attempting to demote or delete the last `owner` is rejected (`400`/`403`).

### `[STORY-011]` Role-Tailored Statistics & Analytics Dashboard (`GET /api/stats/dashboard`)
- **Sprint:** Sprint 3
- **Linked PO Goal:** Role-Tailored Statistics & Analytics Dashboard
- **UI/UX Spec:** `Dashboard` home screen (`dashboard_view.dart`), `GET /api/stats/dashboard`
- **As a** System Owner, Regional Manager/Admin, Supervisor, Sales Agent, or Field Technician, **I want** a single fast `GET /api/stats/dashboard` analytics endpoint returning KPIs, YTD achievement, Condition & Efficiency distributions, Visit Review velocity, and Branch/Agent performance tables scoped to my role, **so that** every persona immediately sees actionable performance and operational metrics without manual spreadsheet exports.
- **Acceptance Criteria:**
  1. **Authenticated & Role-Scoped Endpoint (`GET /api/stats/dashboard`):**
     - Requires `requireAuth`; automatically scopes all aggregations to `req.user` (`owner`/`admin` = fleet-wide with optional `?branch=` filter; `regional_manager` = assigned branch or fleet; `supervisor` = assigned branch/team; `agent` = own assigned chillers; `technician` = maintenance-eligible fleet).
     - Resolves in `< 150ms` for standard datasets (~1,400+ chillers) and handles missing/non-numeric invoice/achievement cells (`-`, `N/A`, blank) safely without `NaN` or `500` errors.
  2. **Role-Tailored KPI Numbers:**
     - **Executive / Branch / Supervisor:** Total Chillers, Assigned vs Unassigned %, Monthly Visit Coverage (`Visited This Month` count & `%`), Pending/Re-opened Reviews, Fleet/Team `Avg Achievement %`, Total `YTD` Revenue, and `Requires Maintenance / Damaged` count.
     - **Rep (`agent`):** Assigned Chillers, Visited This Month (`%`), Pending/Re-opened Visits, Personal `Avg Achievement %`, and Personal `YTD` Revenue.
     - **Technician (`technician`):** Open Maintenance Queue (`Requires Maintenance` + `Damaged`), Scrap Count, Repaired This Month, and Fleet Operational Health `%`.
  3. **Distribution & Velocity Payloads:**
     - **Condition Distribution:** Counts & percentages grouped by `Operational`/`Good`, `Requires Maintenance`, `Damaged`/`Scrap`, and `Unknown`.
     - **Efficiency / Achievement Distribution:** Buckets (e.g., `>= 100% On-Target`, `75–99% Near Target`, `< 75% Underperforming`, `N/A`).
     - **Visit Review Velocity:** Counts of visit responses by status (`Pending`, `Approved`, `Re-opened`) plus average review turnaround / submissions over the last 7 or 30 days.
  4. **Branch & Agent Performance Tables:**
     - Returns ranked `branchPerformance` (Branch name, chiller count, visited %, avg achievement %, YTD total, maintenance count) and `agentPerformance` (Agent name, area/branch, assigned count, visited %, pending reviews, avg achievement %) scoped to the caller's visibility (`agent` sees only their own row or summary; `technician` receives branch maintenance breakdown instead of rep sales rankings).

### `[STORY-012]` Role-Specific Workflows & Dashboard Home (`Dashboard` Tab)
- **Sprint:** Sprint 3
- **Linked PO Goal:** Amazing Role-Specific Workflows & Dashboard Home
- **UI/UX Spec:** New `Dashboard` home tab (`index 0` in `main.dart` for all roles on both Desktop `NavigationRail` and Mobile `NavigationBar`), backed by `GET /api/stats/dashboard`
- **As a** logged-in user (`owner`, `admin`/`regional_manager`, `supervisor`, `agent`, or `technician`), **I want** a dedicated `Dashboard` home tab tailored to my exact role and daily workflow, **so that** I land on my highest-priority actions, charts, and queues the moment I sign in.
- **Acceptance Criteria:**
  1. **Universal `Dashboard` Home Tab (`main.dart`):**
     - `Dashboard` (`Icons.dashboard_outlined` / `Icons.dashboard`) is the default landing tab (`index 0`) for all roles on Desktop (`NavigationRail`) and Mobile (`NavigationBar`), using `AppTokens`, `AppSkeleton` loading states, and `AppEmptyState` fallbacks across Dark, Light, and Outdoor themes.
  2. **Owner / Admin / Regional Manager Command Center:**
     - Displays executive KPI cards, interactive **Condition** & **Efficiency** distribution charts, **Visit Review Velocity** summary, and sortable **Branch & Agent Performance** tables with 1-click drill-down to `Map View` / `Data Table` filtered by that branch or agent.
  3. **Supervisor Review & Team Hub:**
     - Displays team KPIs, team agent coverage leaderboard, and a prioritized **Pending & Re-opened Visit Reviews** queue with quick actions to inspect photos/answers and `Approve` or `Re-open` directly (or jump to `Visit Responses` scoped to their team).
  4. **Rep (`agent`) "My Day" Hub:**
     - Displays personal KPIs (`Assigned`, `Visited This Month`, `Pending`, `Avg Achievement %`), a **Today's Priority Stops / NBA** list (highlighting `Re-opened` audits, overdue visits, and top revenue-drop outlets), and a prominent **"Launch Smart Route (Plan My Day)"** CTA that opens `My Map` with Route Mode active, plus 1-tap **Start Audit** / **Open 360°**.
  5. **Technician Maintenance Queue:**
     - Displays maintenance KPIs (`Open Repairs`, `Damaged/Scrap`, `Operational %`) and a prioritized **Maintenance Queue** list of chillers needing service (with `Chiller Code`, Customer, Branch, Condition badge, GPS/Directions link, and **Customer 360°**).
     - Includes a **1-click "Mark Repaired / Update Condition"** action button on each queue item (with quick condition selector: `Operational`, `Requires Maintenance`, `Damaged`, `Scrap` + optional repair note) that calls the backend update endpoint, shows an `AppToast` confirmation, and immediately refreshes the queue and KPIs.

---

## Sprints 4 & 5 Stories (`P6` — Offline-First Field Resilience & Trust)

### `[STORY-013]` Offline Delta Sync & Outbox Queue (`P6`)
- **Sprint:** Sprints 4 & 5 (`P6` / `v2.7.0`)
- **Linked PO Goal:** `ROAD-05` — Offline-First PWA & Local Sync Queue (Zero Lost Field Data)
- **UI/UX & Architecture Spec:** [DESIGN_NOTES.md §10.1](../03-ui-ux/DESIGN_NOTES.md) (`OfflineSyncBanner`, `OutboxQueueSheet`), [ARCHITECTURE_DECISIONS.md `ADR-009` §1](../04-tech-lead/ARCHITECTURE_DECISIONS.md) (`GET /api/sync/pull`, `POST /api/sync/batch`)
- **As a** Field Sales Agent or Maintenance Technician working in low-connectivity or zero-signal retail/warehouse zones, **I want** my assigned chillers, forms, and assignments cached locally with incremental delta sync and a persistent offline outbox queue, **so that** I can complete visit audits and repair updates offline without losing data and sync safely when connectivity returns.
- **Acceptance Criteria:**
  1. **Delta Pull (`GET /api/sync/pull?since=<iso>`):**
     - Requires `requireAuth`; supports optional ISO-8601 `since` cursor (`400 Bad Request` on invalid timestamp; full bootstrap sync with `isFullSync: true` when omitted).
     - Captures `serverTime` before filtering so clients never miss concurrent writes, and returns role/territory-scoped `chillers`, `forms`, `assignments`, plus `tombstones` (`chillerCodes`, `formIds`, `assignmentIds`) deleted after `since`.
  2. **Transactional & Idempotent Outbox Flush (`POST /api/sync/batch`):**
     - Accepts `1..50` queued operations (`type: 'form_response' | 'condition'`), each with a required `idempotencyKey` (max 128 chars) and optional batch-level `Idempotency-Key` header (`24h` TTL deduplication in `dbStore.idempotency_keys`).
     - Executes each operation under the caller's exact RBAC and territory rules (`technician` receives item-level `403` on `form_response`; `agent` receives item-level `403` on `condition`) and returns per-item `results[]` (`created`, `updated`, `duplicate`, or `error`) without rolling back valid sibling items.
  3. **Offline Sync Status Bar (`OfflineSyncBanner` in `main.dart`):**
     - Docked at the top of the main content pane on desktop (`>= 768px`) and directly above `NavigationBar` on mobile (`< 768px`), styled with `AppTokens.of(context)` across Dark, Light, and Outdoor themes.
     - Auto-collapses (`0px`) when Online with an empty queue (showing a `3s` transient `"All audits synced ✓"` strip right after sync), and surfaces clear states for `Offline (0 Queued)`, `Offline (N Queued)`, `Online (N Queued — Ready)` with **`Sync Now`**, `Syncing (i of N)` progress bar, and `Sync paused — K audit(s) need attention` with **`Resolve / Retry`**.
  4. **Outbox Queue Sheet / Dialog (`OutboxQueueSheet`):**
     - Displays queued items (`Customer Name`, `Chiller Code` in `LTR`, timestamp, photo count, geofence badge, and status pill: `Queued`, `Syncing`, `Retry Needed`, or `Conflict`), with **`Sync All`**, **`Retry`**, **`Discard`** (with confirmation), and conflict resolution (**`Keep Mine (Resubmit)`** / **`Discard Local`**).
     - Preserves `44x44` touch targets, `Semantics` labels, and `Directionality.ltr` on codes/timestamps in Arabic RTL (`Locale('ar')`).

### `[STORY-014]` 100m GPS Check-In Geofencing (`P6`)
- **Sprint:** Sprints 4 & 5 (`P6` / `v2.7.0`)
- **Linked PO Goal:** `ROAD-11` — 100m GPS Check-In Geofencing for Physical Visit Verification
- **UI/UX & Architecture Spec:** [DESIGN_NOTES.md §10.2](../03-ui-ux/DESIGN_NOTES.md) (`GeofenceCheckInPill`), [ARCHITECTURE_DECISIONS.md `ADR-009` §2](../04-tech-lead/ARCHITECTURE_DECISIONS.md) (`POST /api/form-responses` & `POST /api/sync/batch`)
- **As a** Branch Supervisor, Operations Admin, or Field Sales Agent, **I want** live `100m` GPS proximity verification during visit audit check-in and on daily stop cards, **so that** supervisors can trust that field audits were conducted on-site without hard-blocking reps when indoor GPS drifts.
- **Acceptance Criteria:**
  1. **Backend Geofence Calculation & Validation (`POST /api/form-responses` & `sync/batch`):**
     - Accepts optional `checkInLat` and `checkInLng` numbers. Supplying neither preserves full backward compatibility (`checkInLat: null`, `checkInLng: null`, `checkInDistanceM: null`, `geofenceVerified: null`). Supplying only one coordinate or out-of-bounds WGS84 values (`lat` outside `[-90, 90]`, `lng` outside `[-180, 180]`) returns `400 Bad Request`.
     - When the target chiller has valid non-zero finite coordinates, computes `checkInDistanceM = Math.round(haversineKm(...) * 1000)` and `geofenceVerified = checkInDistanceM <= 100`, persisting `check_in_lat`, `check_in_lng`, `check_in_distance_m`, and `geofence_verified` (plus camelCase aliases in responses).
  2. **Soft-Flag Policy (No Hard Block):**
     - Submissions with `checkInDistanceM > 100` (`geofenceVerified: false`) are **accepted** so legitimate visits with indoor GPS drift or relocated chillers are never blocked, while surfacing the distance and `OUT OF RANGE` / `Outside Geofence` indicator for supervisor review.
  3. **Live `GeofenceCheckInPill` UI (`FormFillerDialog` & `DashboardViewScreen`):**
     - Displayed in `FormFillerDialog` directly below `$customerName ($chillerCode)` and inline in `DashboardViewScreen` ("My Day" Next Stop well, Priority Stop cards, Technician Work cards).
     - Renders 4 semantic states using `AppTokens.of(context)`: `Within 100m ✓` (`t.success`), `Outside Geofence — Xm` / `X.X km` (`t.caution`), `Checking GPS...` (`t.accentPrimary`), and `GPS Unavailable` (`t.surfaceHeader` + `Retry` tap action in `FormFillerDialog`).
     - When `distanceMeters > 100`, `FormFillerDialog` displays a non-blocking helper note (`"You are Xm from the registered chiller pin. You can still submit — distance is logged for supervisor review."`). Distance values remain `Directionality.ltr` in Arabic RTL.

### `[STORY-015]` Geo-Stamped Photo Watermarks & 1-Click Visual Audit PDF Export (`P6`)
- **Sprint:** Sprints 4 & 5 (`P6` / `v2.7.0`)
- **Linked PO Goal:** `ROAD-11` — Tamper-Evident Geo-Stamped Photo Evidence & 1-Click Visual Audit PDF Export
- **UI/UX & Architecture Spec:** [DESIGN_NOTES.md §10.3](../03-ui-ux/DESIGN_NOTES.md) (`AuditPhotoGallery`, `_AuditPhotoLightbox`, Export CTA), [ARCHITECTURE_DECISIONS.md `ADR-009` §3](../04-tech-lead/ARCHITECTURE_DECISIONS.md) (`GET /api/form-responses/:id/report`)
- **As a** Branch Supervisor, Operations Admin, System Owner, or Field Sales Agent, **I want** visit audit photos to carry visible geo-stamped watermarks (`Chiller Code`, `Timestamp`, `Lat/Lng`, `Agent Name`) and a 1-click **Export Visual Audit PDF** action, **so that** photo evidence is tamper-evident and audit dossiers can be printed or shared externally with stakeholders.
- **Acceptance Criteria:**
  1. **Structured Geo-Stamped Photo Metadata (`attachments[]`):**
     - `POST /api/form-responses` (and `sync/batch`) supports structured attachment objects `{ url, filename, watermark: { capturedAt, lat, lng, agentName, chillerCode } }` while remaining 100% backward-compatible with legacy string URLs/data-URIs.
     - The Flutter client renders the visible geo-stamp watermark onto captured photos prior to upload and attaches the structured `watermark` metadata.
  2. **Watermark Overlays in `AuditPhotoGallery` & `_AuditPhotoLightbox`:**
     - **Thumbnail Grid:** Renders a subtle bottom gradient scrim with 2 `LTR`-locked lines: `${chillerCode} · $shortDateTime` and `📍 lat, lng` (or `📍 GPS Unverified` in `t.caution` when unverified, paired with a `t.caution` dot badge).
     - **Fullscreen Lightbox:** Displays a bottom watermark metadata card (`Chiller Code`, `Condition` badge, `Geofence` pill, `Timestamp · Agent Name`, `Lat, Lng`, and a `44x44` **`Open in Maps`** action when GPS is verified).
  3. **1-Click Visual Audit Report / PDF Export (`GET /api/form-responses/:id/report`):**
     - Protected by `requireAuth` and `requireRoles('owner', 'admin', 'regional_manager', 'supervisor', 'agent')`, enforcing strict territory isolation (`403` for out-of-scope `agent` or `supervisor`, `404` if missing).
     - Supports `format=html` (default, self-contained print-optimized `@media print` dossier with `Print / Save as PDF` trigger) and `format=json`. All dynamic text is HTML-escaped (`escapeHtml`) and attachment URLs are restricted to safe schemes (`https://`, `http://`, `/uploads/`, `data:image/`) to prevent stored XSS.
     - **UI Placement & States:** Available in `FormResponsesViewScreen` (compact `44x44` PDF icon button on list cards + `Export Visual Audit PDF` `OutlinedButton.icon` in the detail dialog) and `Customer360Drawer` (Audit History header button + per-visit card icon button), with Idle, Generating (`CircularProgressIndicator` + `"Generating PDF..."`), Success (`AppToastType.success`), and Error (`AppToastType.error` with `Retry`) states.

---

## Sprints 6 & 7 Stories (`P7` — Automated Service Operations, Gamification & Bulk Territory Rebalance)

### `[STORY-016]` Automated Maintenance & Scrap SLA Ticketing (`P7`)
- **Sprint:** Sprints 6 & 7 (`P7` / `v2.8.0`)
- **Linked PO Goal:** `ROAD-06` — Automated Maintenance & Scrap SLA Timers & Escalation
- **UI/UX & Architecture Spec:** Service Operations SLA Queue & Ticket Drawer (`DashboardViewScreen`, `Customer360Drawer`), Backend Service Ticket & SLA Escalation Engine
- **As a** Maintenance Technician, Branch Supervisor, or Regional Manager/Admin, **I want** chillers flagged as `Requires Maintenance`, `Damaged`, or `Scrap` to automatically generate SLA-tracked service tickets with configurable escalation timers (`>24h` / `>48h`), **so that** broken assets are repaired faster (reducing MTTR) and overdue tickets are escalated automatically before revenue is lost.
- **Acceptance Criteria:**
  1. **Auto-Ticket Creation & Deduplication:**
     - Whenever a chiller's `Condition` transitions to `Requires Maintenance`, `Damaged`, or `Scrap` (via `PATCH /api/chillers/:id/condition`, visit audit form submission, or master Excel/CSV ingestion delta), the backend automatically creates an `Open` Service Ticket unless an active (`Open`, `In Progress`, or `Escalated`) ticket already exists for that `chiller_code`.
  2. **SLA Tiering & Live Countdown Timers:**
     - **Critical (`Scrap` / `Damaged`):** `24-hour` SLA target (`slaDueAt = createdAt + 24h`).
     - **Urgent (`Requires Maintenance`):** `48-hour` SLA target (`slaDueAt = createdAt + 48h`).
     - Live SLA state (`On Track`, `Due Soon < 6h`, `Breached +Xh`) is computed dynamically and displayed as semantic badges (`t.success`, `t.caution`, `t.danger`) on Technician, Supervisor, and Admin/Owner dashboards.
  3. **Automated Escalation (`>24h` / `>48h`):**
     - Tickets exceeding their `slaDueAt` automatically transition to `Escalated` status (`L1 -> Supervisor`, `L2 -> Regional Manager / Admin` after an additional `24h` breach) and surface in the Supervisor and Regional Manager **SLA Escalation Queue**.
  4. **Ticket Lifecycle & MTTR Tracking:**
     - Technicians can `Acknowledge` (`In Progress`), `Log Repair Note / Photo`, and `Resolve` (marking the chiller `Operational` or confirming `Scrap`), which closes the ticket and records `resolvedAt` and `mttrHours` (Mean Time to Repair) for dashboard analytics.
  5. **RBAC & Territory Isolation:**
     - `technician`: Views/updates open and assigned maintenance tickets (branch-filtered if `branch` is set).
     - `supervisor`: Views/escalates tickets scoped to their `branch`/`team_agent_ids`.
     - `regional_manager` / `admin` / `owner`: Views branch-scoped or fleet-wide SLA compliance %, breached tickets, and MTTR trends.
     - `agent`: Read-only visibility of open ticket status on their own assigned chillers inside `Customer 360`.

### `[STORY-017]` Rep Gamification & "Perfect Chiller" Scorecards (`P7`)
- **Sprint:** Sprints 6 & 7 (`P7` / `v2.8.0`)
- **Linked PO Goal:** `ROAD-07` — "Perfect Chiller" Scorecards, Rep Visit Streaks & Branch Leaderboards
- **UI/UX & Architecture Spec:** Gamification Leaderboard & Scorecard Strip (`DashboardViewScreen`), "Perfect Chiller" Badge & Breakdown (`Customer360Drawer`)
- **As a** Field Sales Agent, Branch Supervisor, or Operations Admin, **I want** composite "Perfect Chiller" scorecards, daily/weekly visit streaks, and branch-scoped rep leaderboards, **so that** field reps stay motivated to complete high-quality, geofence-verified visits and maintain healthy, high-performing chillers.
- **Acceptance Criteria:**
  1. **"Perfect Chiller" Composite Score (`0–100`):**
     - Every chiller receives a deterministic score across 4 weighted pillars:
       - **Physical Condition (`30 pts`):** `Operational`/`Good` = `30`, `Requires Maintenance` = `10`, `Damaged`/`Scrap`/`Unknown` = `0`.
       - **Visit Compliance (`30 pts`):** Accepted/Approved visit audit in the current calendar month = `30`, `Pending` = `15`, Overdue or `Re-opened` = `0`.
       - **On-Site Geofence & Photo Verification (`20 pts`):** Latest visit has `geofenceVerified == true` (`<= 100m`) and photo evidence = `20` (`10` if photo only without geofence, `0` if neither).
       - **Commercial Performance (`20 pts`):** `>= 100%` target achievement = `20`, `75–99%` = `12`, `< 75%` = `4`, missing/`N/A` = `10` (neutral).
     - Chillers scoring `>= 90` earn the **"Perfect Chiller ★"** badge in `Customer 360` and Dashboard stop cards, with a tap-to-inspect 4-pillar breakdown.
  2. **Rep Visit Streaks & Milestone Badges:**
     - Tracks each `agent`'s consecutive active visit days (`currentStreakDays`, `bestStreakDays`), monthly Perfect Chiller count, and milestone badges (e.g., `On-Site Pro` for 10+ geofenced visits, `Zero Re-opens`, `7-Day Streak`).
  3. **Branch-Scoped Rep Leaderboard:**
     - Renders a ranked leaderboard on `Dashboard` (`Home`) for `agent` (branch/peer rank), `supervisor` (team leaderboard), and `admin`/`owner` (filterable by `Branch`), displaying Rep Name, Visit Completion %, Avg "Perfect Chiller" Score, Current Streak, and Total Points.
  4. **Edge Cases, Themes & Arabic RTL:**
     - Missing/non-numeric financial cells never produce `NaN`; all scorecard and leaderboard widgets use `AppTokens.of(context)` across Dark, Light, and Outdoor themes, with `Directionality.ltr` on numeric scores, percentages, and streak counts in `Locale('ar')`.

### `[STORY-018]` Bulk Territory Rebalance for Supervisors/Admins (`P7`)
- **Sprint:** Sprints 6 & 7 (`P7` / `v2.8.0`)
- **Linked PO Goal:** `ROAD-07` — Map-Lasso & Multi-Select Bulk Territory Rebalancing for Supervisors & Admins
- **UI/UX & Architecture Spec:** Map-Lasso / Multi-Select Rebalance Toolbar (`MapViewScreen`, `AssignLocationsViewScreen`, Supervisor `DashboardViewScreen` CTA), Bulk Reassignment API
- **As a** Branch Supervisor, Regional Manager, or Operations Admin, **I want** to select multiple chillers on the map (via polygon/lasso or multi-select) or in the Assign Locations table and bulk-reassign them to a target agent with workload preview, **so that** I can rebalance unbalanced territories or cover absent reps in seconds instead of editing one chiller at a time.
- **Acceptance Criteria:**
  1. **Map-Lasso & Multi-Select Selection (`MapViewScreen`):**
     - Supervisors, Regional Managers, Admins, and Owners can toggle **"Rebalance / Lasso Select"** mode on the map to draw a freehand polygon/lasso (or tap-select multiple pins) and highlight all chillers inside the selection boundary.
  2. **Before → After Workload Preview:**
     - Opening the **Rebalance Confirmation** sheet/dialog displays the selected chiller count, a **Before → After** workload comparison for affected agents (e.g., `Rep A: 48 → 35 chillers`, `Rep B: 22 → 35 chillers`), and a target **Sales Agent** selector (plus an optional **Bulk Unassign** action with confirmation).
  3. **Atomic Bulk Reassignment & Audit Trail:**
     - Confirming executes a single atomic bulk assignment request, updates all selected chillers, records a structured audit log entry in `System Logs` (actor, count, source/target agents, timestamp), and immediately refreshes map pins, KPIs, and `Assign Locations`.
  4. **RBAC & Branch Guardrails:**
     - `supervisor` can only select chillers within their assigned `branch`/`area` and can only reassign to agents in their `branch`/`team_agent_ids` (out-of-scope chillers or target agents return `403 Forbidden`).
     - `agent` and `technician` have no access to bulk territory rebalance controls or endpoints.
  5. **Seamless Entry Points:**
     - Accessible from both the `Map View` toolbar and the Supervisor Dashboard's **`Rebalance Territories`** CTA (`Assign Locations`), preserving `44x44` touch targets and `AppToast` confirmation feedback.

---

## Sprints 8 & 9 Stories (`P8` — AI Retail Execution Intelligence, Predictive Relocation & Data Completeness Center)

### `[STORY-019]` AI Chiller Purity, OOS & Predictive Relocation Insights (`P8`)
- **Sprint:** Sprints 8 & 9 (`P8` / `v3.0.0`)
- **Linked PO Goal:** `ROAD-08` & `ROAD-09` — AI Chiller "Purity", OOS & POSM Vision Audit + Predictive Chiller Relocation Engine
- **UI/UX & Architecture Spec:** AI Execution & Relocation Panel (`DashboardViewScreen`, `Customer360Drawer`, `FormResponsesViewScreen`), AI Vision & Relocation Scoring Service
- **As a** Regional Manager, Branch Supervisor, Operations Admin, or Field Sales Agent, **I want** automated AI Chiller Purity, Out-of-Stock (OOS), POSM compliance, and Predictive Relocation insights surfaced on audit photos, Customer 360, and executive dashboards, **so that** competitor intrusion and stockouts are caught automatically and underperforming "Ghost" chillers are relocated to higher-ROI outlets.
- **Acceptance Criteria:**
  1. **AI Vision Audit Analysis (Purity, OOS, POSM & Blur Detection):**
     - Audit photos submitted via `POST /api/form-responses` (or `POST /api/sync/batch`) are evaluated for **Shelf Purity %** (company vs. competitor SKU facings), **Out-of-Stock (OOS) Alert** (empty shelf ratio), **POSM / Branding Compliance** (`Compliant` / `Missing`), and **Image Quality / Blur Check** (non-blocking capture-time warning if blurry).
     - Results persist on the audit response and surface as semantic badges (`Purity >= 85%` -> `t.success`, `70–84%` -> `t.caution`, `< 70%` or `OOS Detected` -> `t.danger`) in `FormResponsesViewScreen` and `Customer360Drawer`.
  2. **Predictive Chiller Relocation Engine ("Ghost Chiller" Detection):**
     - Identifies low-ROI **"Ghost" Chillers** (`Condition = Operational/Good` with sustained low/zero or declining `YTD` revenue below branch threshold) and computes a **Relocation Priority Score** alongside nearby high-potential candidate outlets/zones within the same `Branch` / `District`.
     - Surfaces a **Relocation Recommendation** card inside `Customer360Drawer` (for `supervisor`, `regional_manager`, `admin`, `owner`) and a ranked **Relocation Watchlist** on `DashboardViewScreen` with 1-click drill-down to `Map View`.
  3. **RBAC, Territory Isolation & Auditability:**
     - `owner` / `admin` / `regional_manager`: View fleet-wide or branch-scoped AI Purity/OOS metrics and Relocation Watchlist; can approve/dismiss relocation recommendations (logged in `System Logs`).
     - `supervisor`: Scoped to their assigned `branch`/`team_agent_ids` for AI alerts and relocation candidates.
     - `agent`: Views Purity/OOS feedback on their own assigned chillers (`Customer360Drawer` & `Visit Responses`) and receives capture-time blur/OOS prompts; does not see fleet-wide relocation controls.
     - `technician`: No access to commercial relocation analytics.
  4. **Edge Cases, Themes & Arabic RTL:**
     - Missing or unprocessed photos display `Pending AI Scan` or `N/A` without blocking visit submission; numeric percentages and scores use `Directionality.ltr` in `Locale('ar')` and `AppTokens.of(context)` across Dark, Light, and Outdoor themes.

### `[STORY-020]` Data Completeness Center & Incomplete Record Filtering (`P8`)
- **Sprint:** Sprints 8 & 9 (`P8` / `v3.0.0`)
- **Linked PO Goal:** `P8` — Master Data Quality Governance & Incomplete Record Remediation
- **UI/UX & Architecture Spec:** Data Completeness Center Card / Drawer (`DashboardViewScreen`, `DataTableViewScreen`, `MapViewScreen`), Completeness Health Summary API
- **As a** System Owner, Regional Manager, Operations Admin, or Branch Supervisor, **I want** a centralized Data Completeness Center with field-level health scores and 1-click incomplete record filtering across the Data Table and Map, **so that** missing GPS coordinates, unassigned chillers, unspecified conditions, and blank financial/serial fields can be identified and remediated quickly.
- **Acceptance Criteria:**
  1. **Fleet & Branch Data Completeness Scorecard:**
     - Computes deterministic completeness `%` across critical master-data dimensions: **Valid GPS (`lat`/`lng`)**, **Assigned Agent**, **Chiller Condition** (non-`Unknown`/`-`), **Serial / Asset Metadata**, and **Financial / Branch-District Mapping**.
     - Displays an overall **Data Completeness %** gauge and per-dimension missing-record counts (`N missing GPS`, `N unassigned`, `N unspecified condition`, `N missing serial`) on `DashboardViewScreen` (for `owner`, `admin`, `regional_manager`, and branch-scoped `supervisor`).
  2. **1-Click Incomplete Record Filtering (`DataTableViewScreen` & `MapViewScreen`):**
     - Clicking any missing-dimension pill (e.g., `Missing GPS`, `Unassigned`, `Unspecified Condition`, `Incomplete Financial/Serial`) navigates to or filters `DataTableViewScreen` (or `AssignLocationsViewScreen`) to isolate only the affected rows, with a dismissible active-filter chip (`Incomplete: Missing GPS (N)`) to reset.
     - Inside `DataTableViewScreen`, a dedicated **`Incomplete Only`** quick-filter chip/toggle highlights missing cells with semantic `t.caution` / `t.danger` indicators so admins can inspect gaps immediately.
  3. **Inline Remediation & Export:**
     - Filtered incomplete rows provide direct quick actions (`Assign Agent`, `Open 360°`) and allow admins/owners to export the filtered incomplete subset to CSV/Excel for field or back-office cleanup.
  4. **RBAC & Edge Cases:**
     - `supervisor` sees completeness metrics and incomplete filters scoped strictly to their `branch`/`team_agent_ids`; `agent` and `technician` do not see fleet-wide Data Completeness Center admin controls.
     - Empty or zero-chiller branches render `0` / `N/A` cleanly via `AppEmptyState` without division-by-zero errors.

### `[STORY-021]` Sub-Branch District Rollups (`P8`)
- **Sprint:** Sprints 8 & 9 (`P8` / `v3.0.0`)
- **Linked PO Goal:** `P8` — Granular Sub-Branch / District Performance & Coverage Analytics
- **UI/UX & Architecture Spec:** Hierarchical Branch → Sub-Branch / District Rollup Table & Filter (`DashboardViewScreen`, `MapViewScreen`, `DataTableViewScreen`), Dashboard Stats District Aggregation
- **As a** System Owner, Regional Manager, Operations Admin, or Branch Supervisor, **I want** Sub-Branch / District-level rollups nested beneath each Branch across the Dashboard, Map, and Data Table, **so that** I can pinpoint underperforming districts, low visit coverage pockets, and maintenance hotspots inside large branches.
- **Acceptance Criteria:**
  1. **Hierarchical Branch → Sub-Branch / District Aggregation:**
     - Backend analytics (`GET /api/stats/dashboard` and KPI rollup payloads) group chillers by `Branch` and nested `Sub-Branch` / `District` (falling back gracefully to `Unspecified District` when the column is blank/`-` in master sheets).
     - Each district rollup computes: **Chiller Count**, **Assigned %**, **Visited This Month %**, **Avg Achievement %**, **YTD Revenue**, and **Maintenance / Alert Count**.
  2. **Expandable Branch → District Drill-Down (`DashboardViewScreen`):**
     - In the Branch Performance table/chart on `DashboardViewScreen`, expanding a `Branch` reveals its child **Sub-Branch / District** rows with sortable metrics and semantic target badges (`>= 85%` green, `65–84%` amber, `< 65%` red).
  3. **1-Click District Filtering (`MapViewScreen` & `DataTableViewScreen`):**
     - Selecting a Sub-Branch / District row drills into `Map View` or `Data Table` pre-filtered to that `Branch + District`, and a **District** filter chip/dropdown is available alongside the `Branch` filter.
  4. **RBAC, Performance & RTL:**
     - `supervisor` and branch-scoped `regional_manager` see only Sub-Branch / District rollups within their authorized `branch`; `agent` and `technician` do not see executive branch/district tables.
     - Missing/non-numeric financial cells never produce `NaN`; all numeric counts and percentages remain `Directionality.ltr` in Arabic RTL (`Locale('ar')`).

---

## Sprints 10 & 11 Stories (`P9` — Enterprise ERP/DMS Webhooks, Executive ROI Console & PostgreSQL/PostGIS Readiness)

### `[STORY-022]` Enterprise ERP/DMS Webhooks & Executive ROI Console (`P9`)
- **Sprint:** Sprints 10 & 11 (`P9` / `v3.2.0`)
- **Linked PO Goal:** `ROAD-10` — Scheduled ERP/DMS/WhatsApp Webhook Sync & Executive ROI / Fleet Depreciation Console
- **UI/UX & Architecture Spec:** ERP/DMS Webhook Integration Console & Executive ROI / Fleet Depreciation Console (`DashboardViewScreen` / Admin Settings), Webhook Delivery & HMAC Signature Service
- **As a** System Owner, Regional Manager, or Operations Admin, **I want** configurable ERP/DMS webhooks (with HMAC-SHA256 signing, retry/delivery logs, and automated restock/alert triggers) alongside an Executive ROI & Fleet Depreciation Console, **so that** manual Excel bottlenecks are eliminated and capital redeployment decisions are backed by real-time unit economics.
- **Acceptance Criteria:**
  1. **ERP/DMS Webhook Management & Delivery (`ROAD-10`):**
     - Owners/Admins can register, enable/disable, rotate secrets for, and test-fire webhook subscriptions across key lifecycle events (`batch.uploaded`, `visit.submitted`, `ticket.created`, `ticket.resolved`, `relocation.approved`, `restock.triggered`).
     - Outbound webhook payloads are signed with HMAC-SHA256 (`X-Bassem-Signature`), include idempotency keys, and record delivery attempts (`2xx` success, retry backoff, dead-letter status) in a **Webhook Delivery Log**; inbound ERP/DMS sync preserves immutable Batch Delta snapshots (`BR-02`).
  2. **Executive ROI & Fleet Depreciation Console (`DashboardViewScreen`):**
     - Computes per-chiller and branch-level unit economics: **Estimated Asset Cost / Depreciation**, **Maintenance Cost-to-Serve** (aggregated from SLA tickets), **YTD Revenue & Net Contribution**, **Payback Period (Months)**, and **Branch Asset Health Index**.
     - Surfaces an **Executive ROI & Depreciation** panel for `owner`, `admin`, and `regional_manager` with branch benchmarking, Top/Bottom ROI chiller rankings, and 1-click drill-down to `Customer360Drawer` or `Map View`.
  3. **RBAC, Territory Isolation & Auditability:**
     - `owner` / `admin`: Full access to ERP/DMS webhook configuration, secret rotation, test-fire triggers, delivery logs, and national Executive ROI Console.
     - `regional_manager`: Views Executive ROI metrics scoped to their authorized `branch`(es); restricted from global webhook secret management.
     - `supervisor`, `agent`, `technician`: No access to ERP/DMS webhook configuration or executive capital ROI/depreciation financials.
     - All webhook endpoint changes, secret rotations, and manual test triggers are logged in `System Logs`.
  4. **Edge Cases, Themes & Arabic RTL:**
     - Missing asset cost or zero maintenance spend renders cleanly (`N/A` or `0` without `NaN` or division-by-zero); outbound webhook failures never block core field visit submissions or batch uploads.
     - Numeric ROI figures, currency, and percentages remain `Directionality.ltr` in `Locale('ar')` and use `AppTokens.of(context)` across Dark, Light, and Outdoor themes.

### `[STORY-023]` PostgreSQL/PostGIS Multi-Tenant Migration Readiness (`P9`)
- **Sprint:** Sprints 10 & 11 (`P9` / `v3.2.0`)
- **Linked PO Goal:** `ADR-002` — Multi-Tenant Organization Isolation (PostgreSQL + PostGIS & RLS Readiness)
- **UI/UX & Architecture Spec:** Tenant Diagnostics & Migration Readiness Panel (`SystemLogsViewScreen` / `GET /api/admin/diagnostics`), PostgreSQL + PostGIS Schema & RLS Context (`tenant_id`, `ST_Distance`)
- **As a** System Owner or Operations Admin, **I want** tenant-scoped data isolation (`tenant_id` + PostgreSQL Row-Level Security readiness), PostGIS spatial query compatibility, and a pre-flight migration readiness & parity verification console, **so that** the platform can transition cleanly from JSON/Blob storage (`dbStore`) to multi-tenant PostgreSQL/PostGIS with zero cross-tenant leakage or data loss.
- **Acceptance Criteria:**
  1. **Multi-Tenant Context & Isolation Readiness (`tenant_id` & RLS):**
     - Core domain records (`chillers`, `batches`, `users`, `form_responses`, `tickets`, `audit_logs`, `webhooks`) carry a deterministic `tenant_id` (defaulting cleanly to the primary tenant for legacy single-tenant records) and enforce tenant-scoped query boundaries compatible with PostgreSQL RLS (`SET LOCAL app.tenant_id`, `app.role`, `app.branch`).
     - Cross-tenant access attempts are rejected (`403 Forbidden` / `404 Not Found`) and recorded in `System Logs`.
  2. **PostgreSQL/PostGIS Schema & Spatial Parity:**
     - Chiller and visit coordinates (`lat`/`lng`) validate cleanly for PostGIS `GEOGRAPHY(Point, 4326)` / `ST_Distance` spatial queries (100m geofence checks, nearest-chiller route planning, and predictive relocation radius queries) while keeping existing JSON API contracts backward-compatible.
     - Idempotent migration/parity tooling validates record counts, batch immutability, foreign-key integrity, and invalid/missing-coordinate counts prior to cutover.
  3. **Migration Readiness & Diagnostics Console (`Owner` / `Admin`):**
     - `GET /api/admin/diagnostics` and the **System Logs & Diagnostics** screen expose active storage engine (`JSON/Blob` vs. `PostgreSQL/PostGIS`), active `tenant_id` context, schema/parity check status, and pre-flight readiness indicators (unmapped tenants, invalid GPS coordinates, pending sync items).
  4. **RBAC & Security Boundaries:**
     - Only `owner` (and `admin` for non-secret tenant diagnostics) can view multi-tenant migration readiness; `supervisor`, `agent`, and `technician` have zero access to infrastructure/migration diagnostics or cross-tenant controls.
     - Public `GET /api/health` remains sanitized (`TC-05`) and never exposes database connection strings, tenant lists, or migration internals.

---

## Sprint 12 Stories (`v4.0-alpha` — Next-Level BI, Cross-Filtering, Variance, 90-Day Forecast & Management by Exception)

### `[STORY-024]` Period-over-Period Variance Waterfall & 90-Day Forecast (`v4.0-alpha`)
- **Sprint:** Sprint 12 (`v4.0-alpha`)
- **Linked PO Goal:** `v4.0` Pillar 1 ([VISION_AND_ROADMAP.md §8.2, §8.4](../01-product-owner/VISION_AND_ROADMAP.md)) — Time-Series Variance (`MoM / QoQ / YoY`) & Run-Rate Forecasting
- **UI/UX & Architecture Spec:** [DESIGN_NOTES.md §11.2, §11.4](../03-ui-ux/DESIGN_NOTES.md) (`DashboardViewScreen`, `ForecastBandPainter`), [ARCHITECTURE_DECISIONS.md `ADR-010`](../04-tech-lead/ARCHITECTURE_DECISIONS.md)
- **As a** System Owner, Regional Manager, Operations Admin, or Branch Supervisor, **I want** a Period-over-Period Variance Waterfall (`MoM` | `QoQ` | `YoY`) and a 90-Day Projected Attainment Forecast inside the Control Tower Dashboard, **so that** I can move beyond static YTD totals, diagnose expansion vs. contraction revenue drivers, and spot pace-to-goal risks before the period closes.
- **Acceptance Criteria:**
  1. **`MoM | QoQ | YoY` Period Toggle & Pace-to-Goal Status Pill:**
     - The **Period Variance & 90-Day Projection** card provides a compact `SegmentedButton` (`MoM` | `QoQ` | `YoY`) and an inline pace-to-goal status pill based on 90-day projected attainment vs. quota: `On Track` (`>= 95%`, `t.success`), `At Risk` (`80% – 94.9%`, `t.caution`), or `Behind Pace` (`< 80%`, `t.danger`).
  2. **Period-over-Period Variance Strip & 4-Bar Mini Waterfall Bridge:**
     - Displays a 3-part horizontal summary strip on desktop (`>= 900px`, `2x2` `Wrap` on mobile): **Current Period Actual** (with `▲` / `▼` / `●` period delta %), **Mini Waterfall Bridge** (`Prior` in `t.textMuted` → `+ Expansion / New` in `t.success` → `- Contraction / Churn` in `t.danger` → `Current` in `t.accentPrimary`), and **90-Day Projected Finish** (`Target` vs. `Projected` with confidence range).
  3. **90-Day Projected Attainment Chart (`ForecastBandPainter`):**
     - Pure Flutter `CustomPainter` (`210px` desktop / `180px` mobile) rendering horizontal dashed gridlines (`0%`, `50%`, `100%`), `-90d` to `+90d` timeline markers with a vertical dashed **`TODAY`** divider, solid historical actuals line, dashed `Quota (100%)` line, shaded `P10–P90` confidence band, and dashed projected run-rate line (`+30d`, `+60d`, `+90d` nodes).
     - Supports interactive scrub/tap tooltips showing `Period`, `Actual / Projected`, `Quota`, and `Confidence Band`. If `< 2` billing periods exist in the active scope, renders a clean empty baseline (`"Need at least 2 billing periods to project 90-day run-rate."`).
  4. **Control Tower Mode Switcher, RBAC & Arabic RTL:**
     - `owner`, `regional_manager`, `admin`, and `supervisor` can switch Control Tower views (`Executive`, `Commercial 360°`, `Asset Lifecycle 360°`, `Workforce 360°`) inside `DashboardViewScreen` without bloating `main.dart` navigation; `agent` and `technician` retain their focused `My Day` and `Service Dispatch` workspaces.
     - All variance and forecast aggregations respect branch/territory scoping, use `AppTokens.of(context)` across Dark, Light, and Outdoor themes, and lock numeric metrics/deltas to `Directionality.ltr` in `Locale('ar')`.

### `[STORY-025]` Global Cross-Filtering & Management by Exception Feed (`v4.0-alpha`)
- **Sprint:** Sprint 12 (`v4.0-alpha`)
- **Linked PO Goal:** `v4.0` Pillars 2 & 4 ([VISION_AND_ROADMAP.md §8.2, §8.4](../01-product-owner/VISION_AND_ROADMAP.md)) — Interactive Cross-Filtering, "Drill-Anywhere" & Exception-Based Management (EBM)
- **UI/UX & Architecture Spec:** [DESIGN_NOTES.md §11.1, §11.3](../03-ui-ux/DESIGN_NOTES.md) (`DashboardCrossFilter`, `CrossFilterPillBar`, `InteractiveDonutChart`, EBM Feed), [ARCHITECTURE_DECISIONS.md `ADR-010`](../04-tech-lead/ARCHITECTURE_DECISIONS.md)
- **As a** System Owner, Regional Manager, Operations Admin, or Branch Supervisor, **I want** bidirectional global cross-filtering across all Control Tower widgets paired with a ranked Management by Exception (EBM) Feed with 1-click corrective actions, **so that** I can slice fleet metrics in real time and resolve high-impact anomalies immediately without scanning 1,400+ rows.
- **Acceptance Criteria:**
  1. **Multi-Dimensional Bidirectional Cross-Filtering (`DashboardCrossFilter`):**
     - Clicking any bar in **Branch Performance** (`MiniBarChart`), territory row in **District Rollups**, or donut slice / legend row in **Fleet Health** (`InteractiveDonutChart` for `Condition` or `Efficiency`) adds/toggles that dimension predicate with `AND` semantics (e.g., `Branch: Cairo` + `District: Nasr City` + `Condition: Requires Maint.`).
     - Selected slices/bars highlight clearly while unselected elements dim; clicking an active item toggles it off.
  2. **Sticky `CrossFilterPillBar` & Quick-Pivot Actions:**
     - Renders below the greeting/Control Tower mode bar and auto-collapses (`0px`) when no filters are active.
     - Displays `Active Filters`, live matched count (`X / Y assets`), dismissible `[Dimension]: [Value]` chips (`>= 44x44` touch targets), **`Open in Map`**, **`Open in Table`**, and **`Clear All`**.
     - Filter updates keep existing cards visible with a `2px` top progress indicator (no layout jump), and zero-match filter combinations render an inline empty-state banner with a **`Clear All Filters`** CTA.
  3. **Ranked Management by Exception (EBM) Feed:**
     - Automatically scoped by `CrossFilterPillBar` and caller RBAC/territory, ranking high-impact anomalies by severity and financial/SLA impact with severity filter chips: `All`, `Critical` (`t.danger`, e.g., `>20% MoM revenue drop`, `SLA breached >48h`, `Ghost Chiller`), `Warning` (`t.warning`, e.g., `SLA >24h`, `Attainment 65–79%`, `2+ Re-opened Audits`), and `Watch` (`t.caution`, e.g., `Missing GPS`, `Near-target pace dip`, `Warranty expiring <30d`).
     - Each exception card uses a `4px` directional start accent bar (`BorderDirectional`), severity & category pills (`REVENUE DROP`, `SLA BREACH`, `GHOST ASSET`, `AUDIT QUALITY`), `LTR`-locked impact metric, and a positive empty state (`"All clear — no active exceptions in this scope."`) when zero anomalies match.
  4. **1-Click Corrective Action Triggers:**
     - Every exception card exposes direct actions: **`Investigate 360°`** (opens `Customer360Drawer` for the chiller/outlet or applies branch cross-filter), **`Assign`** (opens quick Rep/Technician assignment dialog), and **`Create Ticket`** (opens pre-filled Maintenance/SLA Ticket dialog).
  5. **RBAC, Territory Isolation & RTL:**
     - `supervisor` and branch-scoped `regional_manager` see cross-filters and EBM items strictly within their authorized `branch`/`team_agent_ids`; numeric counts and impact metrics remain `Directionality.ltr` in `Locale('ar')`.
