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

