# Bassem Sales Platform — User Guide (`v2.5.0` Baseline + `v2.6.0`–`v3.2.0` Sprint 1–11)

**Product Version:** `v2.5.0` (Express API + Flutter Web + Vercel Blob) with `v2.6.0` Sprint 1–3, `v2.7.0` Sprint 4–5 (`P6`), `v2.8.0` Sprint 6–7 (`P7`), `v3.0.0` Sprint 8–9 (`P8`), & `v3.2.0` Sprint 10–11 (`P9`) Enhancements  
**Target Audience:** System Owners, Regional Managers / Operations Admins, Branch Supervisors, Field Sales Agents, and Maintenance Technicians  
**Last Updated:** 2026-11-19  

---

## Sprint Delivery Snapshot Checklist

> [!NOTE]
> Every sprint updates this guide with newly shipped features and live UI screenshots captured from `http://localhost:5000` into `docs/screenshots/`.

| Screen / Feature | Role Scope | Screenshot File | Status |
| :--- | :--- | :--- | :--- |
| **Login & Security Gate** | Public | [`01_login_screen.png`](screenshots/01_login_screen.png) | [x] Captured live from `http://localhost:5000` |
| **Interactive Geospatial Map** | Owner / Admin / Agent | [`02_map_view.png`](screenshots/02_map_view.png) | [x] Captured live from `http://localhost:5000` |
| **Upload & Validate (Excel/CSV)** | Owner / Admin | [`03_upload_validate.png`](screenshots/03_upload_validate.png) | [x] Captured live from `http://localhost:5000` |
| **Assign Locations** | Owner / Admin | [`04_assign_locations.png`](screenshots/04_assign_locations.png) | [x] Captured live from `http://localhost:5000` |
| **Sales Agents Management** | Owner / Admin | [`05_sales_agents.png`](screenshots/05_sales_agents.png) | [x] Captured live from `http://localhost:5000` |
| **Universal 36+ Column Data Table** | Owner / Admin | [`06_data_table.png`](screenshots/06_data_table.png) | [x] Captured live from `http://localhost:5000` |
| **Forms Manager (Dynamic Builder)** | Owner / Admin | [`07_forms_manager.png`](screenshots/07_forms_manager.png) | [x] Captured live from `http://localhost:5000` |
| **Visit Responses & Review Monitor** | Owner / Admin | [`08_visit_responses.png`](screenshots/08_visit_responses.png) | [x] Captured live from `http://localhost:5000` |
| **System Logs & Diagnostics** | Owner Only | `docs/screenshots/09_system_logs.png` | [ ] Pending authenticated capture |
| **Self-Service Change Password Dialog** *(Sprint 1)* | Owner / Admin / Agent | [`10_change_password.png`](screenshots/10_change_password.png) | [x] Captured live from `http://localhost:5000` |
| **Rep KPI Summary Strip & Branch Rollups** *(Sprint 1)* | Owner / Admin / Agent | `docs/screenshots/11_kpi_summary_strip.png` | [ ] Pending authenticated capture *(visible in `02_map_view.png`)* |
| **Customer 360 Drawer & NBA Card** *(Sprint 2)* | Owner / Admin / Agent | [`12_customer_360_drawer.png`](screenshots/12_customer_360_drawer.png) | [x] Captured live from `http://localhost:5000` |
| **Smart Daily Route Planner ("Plan My Day")** *(Sprint 2)* | Agent / Owner / Admin | `docs/screenshots/13_route_planner.png` | [ ] Pending authenticated capture |
| **Theme Switcher & Outdoor Field Contrast Mode** *(UI/UX P4)* | Owner / Admin / Agent | [`14_theme_outdoor_mode.png`](screenshots/14_theme_outdoor_mode.png) | [x] Captured live from `http://localhost:5000` |
| **Mobile Thumb-Zone Bottom Navigation** *(UI/UX P4)* | Owner / Admin / Agent | [`15_mobile_bottom_nav.png`](screenshots/15_mobile_bottom_nav.png) | [x] Captured live from `http://localhost:5000` |
| **Map Condition Pin Mode & Legend** *(UI/UX P4)* | Owner / Admin / Agent | [`16_map_condition_pins.png`](screenshots/16_map_condition_pins.png) | [x] Captured live from `http://localhost:5000` |
| **Drag-and-Drop Upload & Errors-Only Preview** *(UI/UX P4)* | Owner / Admin | `docs/screenshots/17_upload_dropzone_errors.png` | [ ] Pending authenticated capture |
| **Data Table Sticky Pinning, Density & Multi-Sort** *(UI/UX P5)* | Owner / Admin | `docs/screenshots/18_table_pinning_multisort.png` | [ ] Pending authenticated capture *(visible in `06_data_table.png`)* |
| **Delta View Before → After Visual Diff Cards** *(UI/UX P5)* | Owner / Admin | `docs/screenshots/19_delta_diff_cards.png` | [ ] Pending authenticated capture |
| **Audit Photo Gallery & Zoomable Lightbox** *(UI/UX P5)* | Owner / Admin / Agent | `docs/screenshots/20_photo_lightbox.png` | [ ] Pending authenticated capture |
| **`EN / عربي` Arabic RTL & WCAG AA Accessibility** *(UI/UX P5)* | Owner / Admin / Agent | `docs/screenshots/21_arabic_rtl_mode.png` | [ ] Pending authenticated capture |
| **Owner / Regional Manager Command Center Dashboard** *(Sprint 3)* | Owner / Regional Manager / Admin | [`22_dashboard_owner.png`](screenshots/22_dashboard_owner.png) | [x] Captured live from `http://localhost:5000` |
| **Supervisor Branch Team & Audit Review Hub** *(Sprint 3)* | Supervisor | [`23_dashboard_supervisor.png`](screenshots/23_dashboard_supervisor.png) | [x] Captured live from `http://localhost:5000` |
| **Field Rep "My Day" Hero Card & Priority Action List** *(Sprint 3)* | Agent | [`24_dashboard_rep_myday.png`](screenshots/24_dashboard_rep_myday.png) | [x] Captured live from `http://localhost:5000` |
| **Technician Maintenance & Scrap Work Queue** *(Sprint 3)* | Technician | [`25_dashboard_technician.png`](screenshots/25_dashboard_technician.png) | [x] Captured live from `http://localhost:5000` |
| **Offline Sync Banner & Outbox Queue** *(Sprints 4 & 5 — P6)* | Agent / Technician / Supervisor / Admin | `docs/screenshots/26_offline_sync_outbox.png` | [ ] Pending authenticated capture |
| **100m GPS Geofence Check-In Pill** *(Sprints 4 & 5 — P6)* | Agent / Technician / Supervisor / Admin | `docs/screenshots/27_geofence_checkin.png` | [ ] Pending authenticated capture |
| **Geo-Stamped Photo Watermarks & Visual Audit PDF Export** *(Sprints 4 & 5 — P6)* | Owner / Admin / Supervisor / Agent | `docs/screenshots/28_geostamp_audit_pdf.png` | [ ] Pending authenticated capture |
| **Automated Maintenance & Scrap SLA Ticketing Queue** *(Sprints 6 & 7 — P7)* | Technician / Supervisor / Admin / Owner | `docs/screenshots/29_sla_ticketing_queue.png` | [ ] Pending authenticated capture |
| **Rep Gamification Leaderboard & "Perfect Chiller" Scorecard** *(Sprints 6 & 7 — P7)* | Agent / Supervisor / Admin / Owner | `docs/screenshots/30_gamification_scorecards.png` | [ ] Pending authenticated capture |
| **Map-Lasso & Bulk Territory Rebalance** *(Sprints 6 & 7 — P7)* | Supervisor / Regional Manager / Admin / Owner | `docs/screenshots/31_bulk_territory_rebalance.png` | [ ] Pending authenticated capture |
| **AI Chiller Purity, OOS & Predictive Relocation Insights** *(Sprints 8 & 9 — P8)* | Owner / Regional Manager / Admin / Supervisor / Agent | `docs/screenshots/32_ai_purity_relocation.png` | [ ] Pending authenticated capture |
| **Data Completeness Center & Incomplete Record Filtering** *(Sprints 8 & 9 — P8)* | Owner / Regional Manager / Admin / Supervisor | `docs/screenshots/33_data_completeness_center.png` | [ ] Pending authenticated capture |
| **Sub-Branch District Rollups & Hierarchical Drill-Down** *(Sprints 8 & 9 — P8)* | Owner / Regional Manager / Admin / Supervisor | `docs/screenshots/34_sub_branch_district_rollups.png` | [ ] Pending authenticated capture |
| **Enterprise ERP/DMS Webhooks & Executive ROI Console** *(Sprints 10 & 11 — P9)* | Owner / Regional Manager / Admin | `docs/screenshots/35_erp_webhooks_roi_console.png` | [ ] Pending authenticated capture |
| **PostgreSQL/PostGIS Multi-Tenant Migration Readiness** *(Sprints 10 & 11 — P9)* | Owner / Admin | `docs/screenshots/36_pg_postgis_readiness.png` | [ ] Pending authenticated capture |

---

## 1. Login & Role-Based Access Control (RBAC)

### 1.1 Signing In
Open the platform in your browser (`http://localhost:5000` locally, or your deployed Vercel URL).

![Bassem Sales Platform Login Screen](screenshots/01_login_screen.png)

1. Enter your **Work Email Address** (e.g., `admin@sales.com` or your assigned agent email).
2. Enter your **Password** (use the eye icon to toggle visibility).
3. Click **Sign In** (or press `Enter`).

**Security Protections (`v2.5.0`):**
- Passwords are hashed with **PBKDF2 (100,000 iterations, SHA-512)** and unique per-user salts.
- **Brute-Force Protection:** After **5 failed login attempts**, a **5-minute lockout** is enforced per IP and account identifier.
- **Password Management:** Admins and Owners can set or reset any user's password from the **Sales Agents** tab. In addition, any logged-in user (`owner`, `regional_manager`/`admin`, `supervisor`, `agent`, or `technician`) can rotate their own password using the **Self-Service Change Password** dialog (`STORY-002`, Sprint 1):
  1. Click **Change Password** in the top `AppBar` (desktop) or navigation `Drawer` (mobile `< 768px`).
  2. Enter your **Current Password**, **New Password**, and **Confirm New Password** (using the eye icon to toggle visibility).
  3. Ensure the new password meets complexity rules (**minimum 8 characters**, at least **1 uppercase**, **1 lowercase**, **1 digit**, and **1 special character**) and click **Update Password**.
  4. On confirmation, the new credentials take effect immediately on your next sign-in.

![Self-Service Change Password Dialog](screenshots/10_change_password.png)

### 1.2 5-Tier Sales Hierarchy, RBAC & Role-Based Navigation *(Sprint 3 — `STORY-010` & UI/UX P4)*
The platform enforces a **5-tier Sales Hierarchy** across all API routes (`requireRole` / `requireSupervisorOrAbove`) and adapts navigation on both Desktop (`NavigationRail`, `>= 768px`) and Mobile (`NavigationBar` in the lower thumb zone, `< 768px`), with **`Home` (`DashboardViewScreen`)** as **Tab 0** for every role:

| Tier / Role | Permissions & Data Scope | Daily Workflow | Desktop Tabs (`>= 768px`) | Mobile Bottom Bar (`< 768px`) |
| :--- | :--- | :--- | :--- | :--- |
| **1. System Owner (`owner`)** | Full global access across all branches, teams, user/role creation (including assigning `owner`), master uploads, destructive resets, and **System Logs**. | Review fleet-wide KPIs & branch performance on `Home`, monitor at-risk chillers, audit system logs, and oversee regional managers. | **9 Tabs:** `Home`, Map View, Upload & Validate, Assign Locations, Sales Agents, Data Table, Forms Manager, Visit Responses, **System Logs** | **4 Primary Tabs** (`Home`, `Map`, `Table`, `Responses`) + **`More` Sheet** (`Upload & Validate`, `Assign Locations`, `Sales Agents`, `Forms Manager`, `System Logs`, `Theme Mode`) |
| **2. Regional Manager / Admin (`regional_manager` / `admin`)** | Full operational access (`admin` tier; `regional_manager` optionally scoped to assigned `branch`/`area`). Excludes `owner`-only System Logs and destructive resets. | Track branch targets & condition breakdowns on `Home`, ingest master Excel sheets, assign territories, manage users/roles, and configure forms. | **8 Tabs:** `Home`, Map View, Upload & Validate, Assign Locations, Sales Agents, Data Table, Forms Manager, Visit Responses | **4 Primary Tabs** (`Home`, `Map`, `Table`, `Responses`) + **`More` Sheet** (`Upload & Validate`, `Assign Locations`, `Sales Agents`, `Forms Manager`, `Theme Mode`) |
| **3. Supervisor (`supervisor`)** | Scoped strictly to their assigned `branch`/`area` or `team_agent_ids` across chillers, agents, assignments, and visit reviews. Cannot access `System Logs` or master `Upload & Validate`. | Sign off **Pending Audit Reviews** (`Approve` / `Flag` with feedback) on `Home`, monitor team rep coverage bars, and rebalance branch territories. | **5 Tabs:** `Home`, Map View, Assign Locations, Visit Responses, Data Table | **5 Tabs:** `Home`, `Map`, `Assign`, `Responses`, `Table` |
| **4. Field Sales Agent (`agent`)** | Strictly isolated to chillers/accounts assigned to their `agent_id` for map, list, Customer 360, route planner, and visit audit submission. | Check **My Day** KPIs & Next Stop on `Home`, launch **Start Route** (`Plan My Day`), visit outlets, and submit audit forms & photos. | **2 Tabs:** `Home`, **My Assigned Customers** (Map View) | **4 Ergonomic Tabs:** `Home`, `My Map`, `My List` (searchable assigned chiller cards), `Route` (opens Map & toggles Smart Daily Route Mode) |
| **5. Maintenance Technician (`technician`)** | Scoped to the **Maintenance Queue** (chillers in `Requires Maintenance`, `Damaged`, or `Scrap`, optionally filtered by `branch`/`area`). Can view Customer 360 and update chiller `Condition` / repair status; cannot edit sales financials, reassign reps, or manage forms/uploads. | Work through urgency-grouped **Maintenance & Scrap** cards on `Home`, navigate via Google Maps, and log repairs with **Mark Operational / Log Repair**. | **3 Tabs:** `Home` (Maintenance Queue), Work Map, Repair Log | **3 Tabs:** `Home`, `Work Map`, `Repair Log` |

![Mobile Thumb-Zone Bottom Navigation](screenshots/15_mobile_bottom_nav.png)

### 1.3 Theme Switcher & Outdoor Field Contrast Mode *(UI/UX P4 — `STORY-006`)*
Click the **Theme Mode** switcher icon in the top `AppBar` (or inside the mobile `More` sheet) to cycle between three persisted visual modes:
- **Dark Mode (Default):** Deep slate (`#0F172A`) and cyan (`#06B6D4`) workspace optimized for indoor/evening review.
- **Light Mode:** Clean light slate (`#F8FAFC`) surface for bright office environments.
- **Outdoor Field Contrast Mode:** Pure white (`#FFFFFF`) canvas with high-contrast dark ink (`#020617`, `>= 14:1` contrast) and deepened accents (`#0369A1`) engineered for direct sunlight legibility on field routes.

![Theme Switcher and Outdoor Field Contrast Mode](screenshots/14_theme_outdoor_mode.png)

### 1.4 `EN / عربي` Arabic RTL Toggle & WCAG AA Accessibility *(UI/UX P5 — `STORY-009`)*
- **Bilingual `EN / عربي` Toggle:** Switch between English (`LTR`) and Arabic (`RTL`) from the top `AppBar` (desktop) or mobile `More` sheet (`Locale('en')` / `Locale('ar')` with `flutter_localizations`).
- **Directional Layout & LTR Data Protection:** Directional spacing, alignments, borders, and navigation icons mirror automatically in Arabic mode, while **Chiller Codes** (e.g., `CH-1042`), **GPS coordinates**, and **numeric KPIs** (e.g., `-12.4%`) remain locked to `TextDirection.ltr` so values never reverse.
- **WCAG AA Accessibility & Ergonomics:**
  - All mobile icon buttons, map pins, and filter chips enforce a minimum **`44x44` touch target**, with screen-reader `Semantics` labels on interactive controls.
  - Full keyboard **`Tab` focus rings** and **`Esc` dismissal** for drawers and lightbox modals.
  - **Unified Toasts & Inline Form Validation:** Floating `AppToast` notifications (`success`, `info`, `warning`, `error`) and inline field validation (`AutovalidateMode.onUserInteraction`, `#EF4444` error borders, and auto-scroll to the first invalid field on submit).

> *[Screenshot Placeholder: Add `docs/screenshots/21_arabic_rtl_mode.png` showing Arabic RTL layout mode and WCAG AA accessibility controls.]*

### 1.5 Role-Tailored `Dashboard` Home Tab (`DashboardViewScreen`) *(Sprint 3 — `STORY-011`, `STORY-012`)*
Upon signing in, every user lands on **`Home`** (**`DashboardViewScreen`** at Tab `0`), backed by the role-scoped `GET /api/stats/dashboard` analytics endpoint. It adapts automatically to Dark, Light, and Outdoor Field Contrast themes, supports pull-to-refresh, and honors Arabic RTL (`Locale('ar')`) with `LTR`-locked numeric KPIs and chiller codes.

#### 1.5.1 Owner / Regional Manager Command Center (`owner` / `regional_manager` / `admin`)
- **4 Hero KPI Cards:**
  1. **Total Assets:** Fleet-wide (or branch-filtered) chiller count across branches.
  2. **YTD Achievement %:** Mean YTD achievement (`XX.X%` or `N/A`) with color-coded target delta pill (`>= 85%` green, `65–84%` amber, `< 65%` red).
  3. **Active Visit Rate:** `Visited / Total` percentage and raw counts.
  4. **Maintenance Alerts:** Total `Requires Maintenance` + `Scrap` chillers; tapping drills directly into `Map View` pre-filtered to maintenance alerts.
- **Branch Performance Bar Chart:** Interactive horizontal/vertical bars sorted highest-to-lowest with a **`YTD Ach %` | `Visit Rate %`** segmented toggle. Tapping any branch bar filters the dashboard or drills into `Map View` for that branch.
- **Condition & Efficiency Breakdown:** `DonutChartPainter` + proportional stacked bar and interactive legend with a **`Condition` (`Operational`, `Requires Maintenance`, `Scrap`, `Unspecified`) | `Efficiency` (`Performing`, `Non-Performing`, `Zero`)** toggle.
- **Chiller Watchlist:** Full-width card with an **`At-Risk` | `Top Performing`** toggle (max 5 priority rows) and a **`360° →`** button on each row to open the **Customer 360 Drawer**.

![Owner / Regional Manager Command Center Dashboard](screenshots/22_dashboard_owner.png)

#### 1.5.2 Supervisor Branch Team & Audit Review Hub (`supervisor`)
- **Branch KPI Strip:** **Branch Assets**, **Branch Visit Rate %**, **Pending Audit Reviews**, and **Branch Maint. Alerts**.
- **Pending Audit Reviews Queue:** Prioritized queue of `Pending` and `Re-opened` team visit audits showing customer, `Chiller Code`, relative timestamp, rep chip, condition badge, and up to 3 audit photo thumbnails (tap to open Lightbox), plus 1-click actions:
  - **`Approve`:** Immediately marks the audit `Accepted` with optimistic UI update and `AppToast` confirmation.
  - **`Flag`:** Opens a 1-field reason prompt (`"What needs correction?"`) and marks the audit `Re-opened`.
  - **`360°`:** Opens the **Customer 360 Drawer**.
- **Team Rep Progress & Territory Rebalance:** Rep completion bars sorted by lowest completion `%` first (`Visited / Assigned`, `Avg Ach %`, and `Re-opened` count), plus a **`Rebalance Territories`** footer button that jumps directly to `Assign Locations` pre-filtered to the supervisor's branch.

![Supervisor Branch Team & Audit Review Hub](screenshots/23_dashboard_supervisor.png)

#### 1.5.3 Field Rep "My Day" Hero Card & Priority Action List (`agent`)
- **"My Day" Hero Card:** Displays your territory/branch pill, **Assigned / Visited Today / Pending** counters, a **`96x96` Completion Ring**, a **Next Stop** callout (customer, `Chiller Code`, condition, and distance in `km`), and dual 1-tap outdoor-friendly (`>= 48px`) CTAs:
  1. **`Start Route`:** Launches `My Map` with **Smart Daily Route Mode ("Plan My Day")** active.
  2. **`Log Visit`:** Opens the **Visit Audit Form** directly for the Next Stop.
- **Priority Action List:** Ordered stop cards with quick filter pills (**`All`** | **`Re-opened`** | **`Overdue`** | **`High Value`**). `Re-opened` cards display admin review feedback inline; each card provides **`Log`**, **`Navigate`**, and tap-to-open **`Customer 360°`**.

![Field Rep My Day Hero Card and Priority Action List](screenshots/24_dashboard_rep_myday.png)

#### 1.5.4 Technician Maintenance & Scrap Work Queue (`technician`)
- **Work Summary Strip:** **Critical / Scrap**, **Requires Maintenance**, and **Repaired This Week** KPI cards.
- **Urgency-Grouped Maintenance & Scrap Queue:** Filterable by **`All Open`** · **`Critical / Scrap`** · **`Requires Maint.`** · **`Recently Serviced`**, and grouped under **`CRITICAL — SCRAP / DOWN`**, **`URGENT — REQUIRES MAINTENANCE`**, and **`RECENTLY SERVICED`** headers.
- **Work Card Actions:** Each card displays customer, `Chiller Code`, branch, serial ID, last reported issue note, condition badge, live GPS distance, and days since flagged, with 3 actions:
  1. **`Mark Operational / Log Repair`:** Opens the streamlined **Repair Log Modal** (status toggle: `Operational`, `Requires Follow-up`, or `Confirm Scrap` + repair notes + optional photo upload) with 1-tap submit, `AppToast` confirmation, and instant queue/KPI refresh.
  2. **`Navigate`:** Deep-links to Google Maps driving directions (`lat,lng`).
  3. **`360°`:** Opens the **Customer 360 Drawer** for full chiller history and past audit photos.

![Technician Maintenance & Scrap Work Queue](screenshots/25_dashboard_technician.png)

---

## 2. Excel / CSV Ingestion & Batch History

**Tab:** `Upload & Validate` *(Owner & Admin only)*

### 2.1 Uploading a Master Sheet *(UI/UX P4 — `STORY-007`)*
1. **Drag & Drop or Browse:** Drag a `.xlsx`, `.xls`, or `.csv` file (up to **25 MB**) onto the interactive **Dropzone** (or click to browse files / use **Quick Load Sample Excel**). The dropzone highlights cyan on drag-over, green on valid drop, and red if an unsupported extension is dropped.
2. **Staged Upload & Validation Preview:** The platform tracks progress (`1. Uploading` → `2. Validating Columns` → `3. Ready for UPSERT`) via `POST /api/excel/parse`, extracts all **36+ dynamic FMCG columns** (e.g., `Branch`, `Chiller Code`, `Condition`, `Jan–Dec Invoice`, `YTD`, `Month Ach. Status`, GPS coordinates), and displays the 4 validation summary cards (`Uploaded File`, `Total Rows`, `Valid Rows`, `Incomplete / Missing`).
3. **Errors-Only Preview Filter:** Use the **`All Rows` | `Errors Only`** toggle above the preview table to immediately isolate failing or incomplete rows before choosing strict vs. bypassed save and clicking **Confirm Ingestion** (`POST /api/excel/confirm`).

> *[Screenshot Placeholder: Add `docs/screenshots/17_upload_dropzone_errors.png` showing the Drag-and-Drop Upload Dropzone and Errors-Only validation preview.]*

### 2.2 Data Safety & Batch Immutability
- **Incremental `UPSERT` Mode Only:** All uploads in `v2.5.0` perform an incremental `UPSERT` (`onlyThisBatch: false`) so existing chiller records and assignments are never accidentally wiped by a partial sheet.
- **DDE / Formula Injection Protection:** Leading formula characters (`=`, `+`, `-`, `@`) are neutralized during ingestion to prevent spreadsheet execution exploits.
- **Immutable Batch History:** Every confirmed upload creates an immutable historical batch snapshot. Individual batch deletion (`DELETE /api/batches/:id`) is permanently disabled (`403 Forbidden`) to preserve audit integrity. Full dataset resets are restricted to `admin`/`owner` via `POST /api/admin/clear-all-batches`.

![Upload & Validate Preview Screen](screenshots/03_upload_validate.png)

### 2.3 Delta View `Before → After` Visual Diff Cards *(UI/UX P5 — `STORY-008`)*
When comparing batch updates in the **Delta View**, changes are presented as structured **Visual Diff Cards** instead of raw text tables:
- **Card Header:** Displays `Chiller Code`, `Customer Name`, and a color-coded Change Type pill (`Added`, `Removed`, or `Modified`).
- **Side-by-Side `Before → After` Field Diff Pills:** Highlights changes across `Condition` (e.g., `Operational → Requires Maintenance`), `Efficiency` (`Non-Performing → Performing`), and numeric `YTD Invoice` deltas (amount and `%`).
- **Quick Action:** Click **Open 360°** on any diff card to open the **Customer 360 Drawer** and inspect the chiller's full history.

> *[Screenshot Placeholder: Add `docs/screenshots/19_delta_diff_cards.png` showing the Delta View Before → After Visual Diff Cards.]*

---

## 3. Interactive Geospatial Map

**Tab:** `Map View` *(Owner/Admin)* / `My Assigned Customers` *(Sales Agent)*

The interactive **OpenStreetMap / Leaflet** canvas plots every chiller with valid GPS coordinates:
- **Pin Color Mode Toggle (`Efficiency` | `Condition`) *(UI/UX P4 — `STORY-007`)*:** Switch the top-left map control between **Efficiency** (`Performing` / `Non-Performing` / `Zero`) and **Condition** mode. In **Condition** mode, pins use dual-signal color + inner icons (`Operational` = Emerald check, `Requires Maintenance` = Orange wrench/build, `Scrap` = Rose red danger, `Unspecified` = Slate `?`), the floating legend updates dynamically, and a quick **Condition** filter chip isolates maintenance/scrap chillers in one tap.
- **Visit Completion State:** Pins dynamically turn **Green** once a field visit audit form is submitted for that chiller.
- **My Location:** Click **My Location** to center the map on your current browser GPS position and inspect nearby retail outlets.
- **Map Canvas Controls:** Use the minimize/maximize toggle controls to expand the map for full-screen territory review or collapse it when focusing on tabular details.
- **Pin Details & Actions:** Click any marker pin to inspect the customer/chiller details, open directions, or launch an assigned **Visit Audit Form**.

![Interactive Geospatial Map](screenshots/02_map_view.png)

![Map Condition Pin Mode and Dynamic Legend](screenshots/16_map_condition_pins.png)

### 3.1 Rep KPI Summary Strip & Branch Rollups *(Sprint 1 — `STORY-003`)*
Positioned at the top of the Map / Data Table workspace (horizontal cards on desktop, compact 2x2 grid on mobile `< 768px`), the **Rep KPI Summary Strip** provides live execution metrics:
- **Sales Agent View (`agent`):** Strictly scoped to your assigned chillers:
  - **Assigned Chillers:** Total chillers assigned to your territory.
  - **Visited This Month:** Count and `%` of assigned chillers with a submitted visit audit in the current calendar month.
  - **Pending Audits:** Assigned chillers with no visit this month or a `Re-opened` audit status.
  - **Avg Achievement %:** Mean monthly/YTD achievement across your assigned chillers.
- **Admin / Owner View (`admin` | `owner`):** Displays fleet-wide totals for the same 4 KPIs plus a **Branch Target Rollup** selector/popover grouped by `Branch`.
- **Interactive Filtering:** Click **Visited This Month** or **Pending Audits** to filter the active Map / Data Table view to matching chillers (click the active-filter chip to reset).

> *[Screenshot Placeholder: Add `docs/screenshots/11_kpi_summary_strip.png` showing the Rep KPI Summary Strip and Branch Rollup popover.]*

### 3.2 Customer 360 Drawer & Next Best Action (NBA) Card *(Sprint 2 — `STORY-004`)*
Clicking any chiller pin on the map (or any row in the `Data Table` for `admin`/`owner`) opens the **Customer 360 Drawer** (slide-over panel on desktop, bottom sheet on mobile):
- **Asset Profile:** Outlet/Customer Name, `Chiller Code`, `Branch`, `Condition`, `Month Ach. Status`, serial metadata, and assigned agent.
- **Financial Velocity:** 12-month (`Jan–Dec`) invoice sparkline trendline, `YTD` total, and month-over-month (MoM) delta `%`.
- **Next Best Action (NBA) Guided Selling Card:** Rule-based prompt prioritizing the highest-value action for the store (e.g., *Log Service / Maintenance Ticket* if `Requires Maintenance`/`Damaged`; *Pitch Restock / Promo* if MoM invoice dropped `> 20%`; *Complete Monthly Visit Audit* if unvisited/re-opened; or *Reinforce Relationship & Check POSM*).
- **Visit History & Quick Actions:** Chronological past audit responses with photo thumbnails, plus one-tap **Start / Open Audit Form** and **Get Directions**.

![Customer 360 Drawer and Next Best Action Card](screenshots/12_customer_360_drawer.png)

### 3.3 Smart Daily Route Planner ("Plan My Day") *(Sprint 2 — `STORY-005`)*
Click **Plan My Day** on the `Map View` / `My Assigned Customers` toolbar to sequence your daily store visits:
1. **Priority & Proximity Sequencing:** Automatically filters assigned chillers with valid GPS coordinates, prioritizes urgent stops (unvisited this month, `Re-opened` audits, `Requires Maintenance`, or underperforming), and orders them by shortest path from your current GPS location (or territory centroid if geolocation is unavailable).
2. **Interactive Stop Selection:** Toggle individual chillers in or out of today's route (default up to 10 stops, max 25) and view updated total estimated distance (`km`). Chillers missing GPS coordinates are clearly reported as excluded.
3. **Map Polyline & Google Maps Handoff:** Displays numbered route pins (`1, 2, 3...`) connected by a polyline on the map. Click **Start Navigation (Google Maps)** for multi-stop turn-by-turn directions, or click **Navigate** on any individual stop.

> *[Screenshot Placeholder: Add `docs/screenshots/13_route_planner.png` showing the Smart Daily Route Planner panel and numbered map polyline.]*

---

## 4. Universal 36+ Column Data Table & Search

**Tab:** `Data Table` *(Owner & Admin only)*

1. **Universal Omni-Search:** Type any keyword (chiller code, customer name, branch, serial number, phone, etc.) into the global search bar to filter across all **36+ columns** simultaneously.
2. **Per-Column Interactive Filters:** Click any column header filter icon to open a filter dialog featuring:
   - Text search within that column.
   - **Value-Frequency Chips** displaying distinct values and their occurrence counts.
3. **Sticky Left Column Pinning *(UI/UX P5 — `STORY-008`)*:** `360° Action + Chiller Code + Customer Name` (configurable via the **Pin** icon in Column Visibility) stay frozen on the left with a `2px` cyan boundary while you scroll horizontally across the remaining 36+ columns, synchronized vertically.
4. **Row Density Toggle *(UI/UX P5 — `STORY-008`)*:** Use the segmented toolbar toggle to switch between **`Compact`** (`36px` row height, `12px` font), **`Standard`** (`48px`, `13px`), and **`Comfortable`** (`60px`, `13.5px` with wrapped address); your preference persists across sessions.
5. **3-Level Multi-Sort *(UI/UX P5 — `STORY-008`)*:** Click a column header to set/toggle the primary sort, and use **`Shift + Click`** (desktop) or **`+ Sort`** in the column header menu (mobile/touch) to stack up to **3 sort levels** (`Primary`, `Secondary`, `Tertiary`) with numeric-aware sorting for `Jan–Dec` and `YTD`. Sorted headers show numbered badges (`1 ↑`, `2 ↓`) alongside a dismissible active-sort chip bar above the table.

![Universal 36+ Column Data Table](screenshots/06_data_table.png)

> *[Screenshot Placeholder: Add `docs/screenshots/18_table_pinning_multisort.png` for a dedicated closeup of sticky column pinning, Row Density toggle, and 3-level Multi-Sort (also visible in `06_data_table.png`).]*

---

## 5. Territory Assignments & Sales Agent Management

### 5.1 Managing Sales Agents (`Sales Agents` Tab)
*(Owner & Admin only)*
- **Create / Edit / Delete Agents:** Maintain each representative's name, assigned **Territory / Area**, phone number, and login email.
- **Set / Reset Login Password:** Click the key/password action (`Set / Reset Login Password`) on an agent card to provision or rotate their login credentials (enforcing strict password complexity).
- **Assigned Count Badge:** Each agent card displays their current `assigned_count` of chillers.

![Sales Agents Management](screenshots/05_sales_agents.png)

### 5.2 Assigning Locations (`Assign Locations` Tab)
*(Owner & Admin only)*
1. Filter the paginated location list by **All**, **Assigned Only**, or **Unassigned** accounts, or search by customer/chiller code.
2. **Single Assignment:** Click **Assign Agent** (or **Reassign**) on any row, choose the target sales agent, and confirm. Click the unassign icon to remove an assignment.
3. **Bulk Assignment:** Check multiple rows and click **Assign Selected (N)** to assign an entire batch of locations to a sales agent in one operation.

![Assign Locations Table](screenshots/04_assign_locations.png)

---

## 6. Dynamic Form Builder & Field Visit Audits

### 6.1 Creating Audit Forms (`Forms Manager` Tab)
*(Owner & Admin only)*
1. Create custom visit audit forms with any combination of field types:
   - **`text`**: Short or multi-line observations, serial number checks, or numeric readings (e.g., chiller temperature).
   - **`choose`**: Single-select dropdowns/chips (e.g., hygiene rating, operational condition).
   - **`attachments`**: Camera/photo or file uploads (e.g., chiller front and condition photos).
2. Assign each form **globally** to all sales agents or **individually** to selected agents.

![Dynamic Form Builder](screenshots/07_forms_manager.png)

### 6.2 Submitting a Field Visit (Sales Agent Map)
1. On the **My Assigned Customers** map, tap an assigned chiller pin.
2. Open the assigned audit form, complete all required fields, attach on-site photos, and click **Submit**.
3. Upon submission, the chiller pin updates to a **Green completed visit state**.

### 6.3 Reviewing Visits (`Visit Responses` Tab) & Audit Photo Lightbox *(UI/UX P5 — `STORY-009`)*
*(Owner & Admin only)*
- Inspect all submitted field visit audits, including form answers and uploaded photo attachments.
- **Audit Photo Gallery:** Both `Visit Responses` (`4-column` grid) and the `Customer 360 Drawer` (`3-column` grid) render `80x80` rounded thumbnails with `Photo N/M`, timestamp, and `GPS Verified` dot badges, plus shimmer loading and graceful `Image unavailable` fallback states.
- **Zoomable Lightbox (`1x–4x`):** Tap any photo thumbnail to open the full-screen dark-scrim lightbox featuring pinch/scroll zoom (`1x–4x`), Left/Right keyboard and swipe navigation, a metadata footer (Rep, Chiller Code, Audit Date, Condition), `Esc` to close, and a **Download** button.
- **Approve** verified visits or **Re-open** an audit with review feedback so the field agent can correct and resubmit.

![Visit Responses & Review Monitor](screenshots/08_visit_responses.png)

> *[Screenshot Placeholder: Add `docs/screenshots/20_photo_lightbox.png` showing the Audit Photo Gallery and zoomable Lightbox.]*

---

## 7. System Logs & Admin Diagnostics

### 7.1 System Logs (`System Logs` Tab — Owner Only)
- View platform-wide audit events (logins, uploads, assignments, password resets, visit approvals).
- Export audit logs as a timestamped JSON file (`audit_logs_<timestamp>.json`).

> *[Screenshot Placeholder: Add `docs/screenshots/09_system_logs.png` showing the Owner-only System Logs view.]*

### 7.2 Health & Diagnostics API Endpoints
- **Public Health Check (`GET /api/health`):** Sanitized endpoint returning only `status`, `version` (`2.5.0`), `storage` summary (`type`, `cloudSync`, `lastSync`, `chillersCount`, `batchesCount`, `blobConfigured`), and `timestamp`. No user emails, roles, salts, or token prefixes are exposed.
- **Admin Diagnostics (`GET /api/admin/diagnostics`):** Protected by `requireAdmin` Bearer authentication. Returns storage details (including `hasBlobToken` boolean), `usersCount`, and non-sensitive user directory metadata (`email`, `role`, `name`, `username`).

---

## 8. Offline-First Field Resilience & Audit Trust *(Sprints 4 & 5 — `P6`)*

### 8.1 Offline Sync Banner & Outbox *(`STORY-013`)*
Field Sales Agents and Maintenance Technicians can continue logging visit audits and chiller condition updates even in zero-signal retail backrooms or rural routes:
- **Incremental Delta Sync (`GET /api/sync/pull`):** On sign-in and reconnect, the app pulls only records (`chillers`, `forms`, `assignments`, and deletion `tombstones`) updated since the last `serverTime` cursor, scoped strictly to your role and territory.
- **`OfflineSyncBanner` Placement & States:**
  - **Desktop (`>= 768px`):** Slim status strip docked at the top of the main content pane.
  - **Mobile (`< 768px`):** Slim bar docked directly above the bottom `NavigationBar` for one-handed thumb reach.
  - **Auto-Hide When Healthy:** Collapses to `0px` when **Online** with an empty outbox (displaying a `3s` `"All audits synced ✓"` confirmation right after a sync completes).
  - **Connectivity & Queue States:** Shows clear status copy and actions for **`Offline — Visits will save to device queue`**, **`Offline — N queued audit(s)`** (`View Queue`), **`Online — N queued audit(s) ready`** (**`Sync Now`** + `View`), **`Syncing audit i of N...`**, and **`Sync paused — K audit(s) need attention`** (**`Resolve / Retry`**).
- **`OutboxQueueSheet` Management & Idempotent Batch Flush (`POST /api/sync/batch`):**
  - Tap **`View Queue`**, **`View`**, or **`Resolve / Retry`** to open the Outbox Queue sheet/dialog.
  - Inspect each queued item's Customer Name, `Chiller Code`, capture timestamp, photo count, geofence badge, and status pill (`Queued`, `Syncing`, `Retry Needed`, or `Conflict`).
  - Tap **`Sync All`** when back online to flush up to 50 operations per batch with idempotency keys (`Idempotency-Key`) preventing duplicate submissions, or use **`Retry`**, **`Discard`**, and **`Keep Mine (Resubmit)`** / **`Discard Local`** for individual items.

> *[Screenshot Placeholder: Add `docs/screenshots/26_offline_sync_outbox.png` showing the Offline Sync Banner and Outbox Queue Sheet.]*

### 8.2 100m GPS Geofence Check-In *(`STORY-014`)*
To verify physical on-site presence without blocking reps when indoor GPS drifts, the platform evaluates live **100-meter GPS proximity** against the registered chiller coordinates:
- **Where It Appears:**
  - Inside the **Visit Audit Form** (`FormFillerDialog`) directly below the Customer Name and `Chiller Code`.
  - On **Dashboard** (`Home`) inside the Field Rep **"My Day"** Next Stop well, Priority Stop cards, and Technician Work cards.
- **Geofence Pill States:**
  - **`Within 100m ✓`** *(Green)*: Your live GPS is `<= 100m` from the chiller pin.
  - **`Outside Geofence — Xm`** *(Amber)*: Your live GPS is `> 100m` away (shows `km` at `>= 1000m`). A non-blocking helper note reminds you that you can still submit—the exact distance is logged for supervisor review.
  - **`Checking GPS...`** *(Cyan)*: Acquiring live browser/device coordinates.
  - **`GPS Unavailable`** *(Neutral + `Retry`)*: Location permission denied or timed out.
- **Backend Verification:** Submissions record `checkInLat`, `checkInLng`, `checkInDistanceM`, and `geofenceVerified` (`<= 100m`) on the audit response (omitting coordinates remains backward-compatible with `null` values).

> *[Screenshot Placeholder: Add `docs/screenshots/27_geofence_checkin.png` showing the 100m GPS Geofence Check-In pill inside the Visit Audit Form and Dashboard stop cards.]*

### 8.3 Geo-Stamped Photos & Audit PDF Export *(`STORY-015`)*
Every field photo and completed visit audit can be inspected and exported as a tamper-evident dossier:
- **Geo-Stamped Photo Watermarks (`AuditPhotoGallery` & Lightbox):**
  - Captured audit photos automatically embed structured watermark metadata (`capturedAt`, `lat`, `lng`, `agentName`, `chillerCode`) alongside a visible geo-stamp overlay.
  - **Thumbnail Grid:** Displays a bottom gradient scrim with `Chiller Code · Timestamp` and `📍 Lat, Lng` (or `📍 GPS Unverified` in amber).
  - **Fullscreen Lightbox:** Displays a bottom watermark metadata card with `Chiller Code`, `Condition` badge, `Geofence` pill (`Within 100m ✓` or `Xm away`), `Timestamp · Agent Name`, `Lat, Lng`, and a **`Open in Maps`** button when GPS is verified.
- **1-Click Visual Audit PDF Export (`GET /api/form-responses/:id/report`):**
  - Available from **`Visit Responses`** (compact PDF icon on each list card + **`Export Visual Audit PDF`** button inside the detail dialog) and the **`Customer 360 Drawer`** (Visit Audit History header + per-visit card icon).
  - Generates a print-optimized A4 audit dossier (`Print / Save as PDF`) containing the audit status, site & GPS check-in verification summary, full Q&A table, geo-stamped photo evidence, and supervisor review decision.

> *[Screenshot Placeholder: Add `docs/screenshots/28_geostamp_audit_pdf.png` showing geo-stamped photo watermarks in the gallery/lightbox and the Export Visual Audit PDF action.]*

---

## 9. Automated Service Operations, Gamification & Bulk Territory Rebalance *(Sprints 6 & 7 — `P7`)*

### 9.1 Automated Maintenance & Scrap SLA Ticketing *(`STORY-016`)*
When any chiller is flagged as **`Requires Maintenance`**, **`Damaged`**, or **`Scrap`** (via a Technician condition update, a Field Rep visit audit, or a master Excel/CSV upload delta), the platform automatically opens and tracks a service ticket with live SLA timers:
- **SLA Targets by Severity:**
  - **Critical (`Scrap` / `Damaged`):** **24-hour** SLA resolution target.
  - **Urgent (`Requires Maintenance`):** **48-hour** SLA resolution target.
- **Automated Escalation:** Tickets that breach their `24h` or `48h` SLA window automatically escalate to **`Escalated`** (`L1 → Branch Supervisor`, `L2 → Regional Manager / Admin`) and surface in the **SLA Escalation Queue** on the Supervisor and Executive Dashboards.
- **Technician Resolution & MTTR:** Technicians can **`Acknowledge`** (`In Progress`), attach repair notes/photos, and **`Resolve`** tickets (marking the chiller `Operational` or confirming `Scrap`), automatically recording Mean Time to Repair (**MTTR**). Sales Agents see read-only ticket status on their assigned chillers inside **`Customer 360`**.

> *[Screenshot Placeholder: Add `docs/screenshots/29_sla_ticketing_queue.png` showing the Automated Maintenance & Scrap SLA Ticketing Queue and escalation badges.]*

### 9.2 Rep Gamification & "Perfect Chiller" Scorecards *(`STORY-017`)*
To drive consistent field execution and high-quality on-site audits, every chiller and field rep is scored transparently:
- **"Perfect Chiller" Composite Score (`0–100`):** Calculated across 4 pillars—**Physical Condition (`30 pts`)**, **Visit Compliance (`30 pts`)**, **On-Site Geofence & Photo Verification (`20 pts`)**, and **Commercial Performance (`20 pts`)**. Chillers scoring **`>= 90`** display the **`Perfect Chiller ★`** badge in **`Customer 360`** and on Dashboard stop cards with a tap-to-inspect pillar breakdown.
- **Rep Visit Streaks & Badges:** Tracks consecutive active visit days (`Current Streak` / `Best Streak`), monthly Perfect Chiller counts, and milestone badges (`On-Site Pro`, `Zero Re-opens`, `7-Day Streak`).
- **Branch-Scoped Rep Leaderboard:** Available on **`Home`** (`Dashboard`) for Sales Agents (peer rank within branch), Supervisors (team leaderboard), and Admins/Owners (filterable by `Branch`).

> *[Screenshot Placeholder: Add `docs/screenshots/30_gamification_scorecards.png` showing the Rep Gamification Leaderboard and "Perfect Chiller" Scorecard breakdown.]*

### 9.3 Bulk Territory Rebalance & Map-Lasso Reassignment *(`STORY-018`)*
Branch Supervisors, Regional Managers, Admins, and Owners can rebalance territories in seconds without editing chillers one by one:
- **Map-Lasso & Multi-Select (`Map View`):** Toggle **Rebalance / Lasso Select** on the map toolbar to draw a freehand polygon/lasso around a cluster of pins (or multi-select pins) and highlight all chillers inside the boundary.
- **Before → After Workload Preview:** Before confirming, the rebalance sheet previews the selected chiller count and each affected rep's **Before → After** chiller count (e.g., `Rep A: 48 → 35`, `Rep B: 22 → 35`) alongside a target **Sales Agent** selector (or **Bulk Unassign**).
- **Scoped Guardrails & Audit Log:** `supervisor` selections and target agents are strictly scoped to their assigned `branch`/`team_agent_ids`, and every bulk rebalance logs an atomic audit trail entry in **`System Logs`**.

> *[Screenshot Placeholder: Add `docs/screenshots/31_bulk_territory_rebalance.png` showing Map-Lasso selection and the Before → After workload preview sheet.]*

---

## 10. AI Retail Execution Intelligence, Data Completeness & District Rollups *(Sprints 8 & 9 — `P8`)*

### 10.1 AI Chiller Purity, OOS & Predictive Relocation Insights *(`STORY-019`)*
Turn field audit photos and chiller YTD sales history into automated retail execution scoring and relocation recommendations:
- **AI Vision Audit Analysis (`Visit Responses` & `Customer 360`):**
  - Submitted audit photos are evaluated for **Shelf Purity %** (company vs. competitor products), **Out-of-Stock (OOS) Alerts**, **POSM / Branding Compliance**, and **Image Blur / Quality** (non-blocking capture-time warning).
  - Semantic badges (`Purity >= 85%` Green, `70–84%` Amber, `< 70%` or `OOS Detected` Red) appear on audit cards and in **`Customer 360`**; unprocessed photos show `Pending AI Scan` without blocking submission.
- **Predictive Chiller Relocation Engine ("Ghost Chiller" Detection):**
  - Identifies low-ROI **"Ghost" Chillers** (`Operational` / `Good` condition with persistently low or declining `YTD` sales) and ranks nearby high-potential candidate outlets/zones within the same `Branch` / `District`.
  - Surfaces a **Relocation Recommendation** card inside **`Customer 360`** and a ranked **Relocation Watchlist** on **`Home`** (`Dashboard`) for Supervisors, Regional Managers, Admins, and Owners, with 1-click drill-down to **`Map View`** and logged approve/dismiss actions.

> *[Screenshot Placeholder: Add `docs/screenshots/32_ai_purity_relocation.png` showing AI Chiller Purity/OOS badges and Predictive Relocation Watchlist insights.]*

### 10.2 Data Completeness Center & Incomplete Record Filtering *(`STORY-020`)*
Keep master chiller datasets clean and actionable across all 36+ columns:
- **Fleet & Branch Completeness Scorecard (`Home` Dashboard):**
  - Tracks overall **Data Completeness %** and per-dimension gap counts across **Valid GPS (`lat`/`lng`)**, **Assigned Agent**, **Chiller Condition**, **Serial / Asset Metadata**, and **Financial / Branch-District Mapping** (scoped to the user's branch for `supervisor` and `regional_manager`).
- **1-Click Incomplete Record Filtering (`Data Table` & `Map View`):**
  - Click any missing-dimension pill (e.g., `Missing GPS`, `Unassigned`, `Unspecified Condition`, `Missing Serial`)—or toggle the **`Incomplete Only`** filter chip in **`Data Table`**—to isolate incomplete records with highlighted missing-cell indicators.
  - Perform inline remediation (`Assign Agent`, `Open 360°`) or export the filtered incomplete subset to CSV/Excel for cleanup.

> *[Screenshot Placeholder: Add `docs/screenshots/33_data_completeness_center.png` showing the Data Completeness Center scorecard and Data Table Incomplete Only filtering.]*

### 10.3 Sub-Branch District Rollups *(`STORY-021`)*
Drill beneath top-level branches to spot local coverage gaps and district-level performance trends:
- **Hierarchical Branch → Sub-Branch / District Drill-Down (`Home` Dashboard):**
  - Expand any `Branch` row in the Branch Performance table to inspect nested **Sub-Branch / District** rollups (**Chiller Count**, **Assigned %**, **Visited This Month %**, **Avg Achievement %**, **YTD Revenue**, and **Maintenance Alerts**). Records without a district value group cleanly under `Unspecified District`.
- **1-Click District Filtering (`Map View` & `Data Table`):**
  - Click any Sub-Branch / District row to drill directly into **`Map View`** or **`Data Table`** pre-filtered to that `Branch + District`, or use the **District** filter dropdown alongside the `Branch` filter.

> *[Screenshot Placeholder: Add `docs/screenshots/34_sub_branch_district_rollups.png` showing expandable Branch → Sub-Branch District rollups and district filtering.]*

---

## 11. Enterprise ERP/DMS Webhooks, Executive ROI Console & PostgreSQL/PostGIS Readiness *(Sprints 10 & 11 — `P9`)*

### 11.1 Enterprise ERP/DMS Webhooks & Executive ROI Console *(`STORY-022`)*
Connect field execution and asset telemetry to external ERP/DMS systems while tracking capital unit economics at the executive level:
- **ERP/DMS Webhook Subscriptions & Delivery Log (`Owner` / `Admin`):**
  - Register, enable/disable, rotate signing secrets for, and test-fire outbound webhooks on lifecycle events (`batch.uploaded`, `visit.submitted`, `ticket.created`, `ticket.resolved`, `relocation.approved`, `restock.triggered`).
  - Payloads are signed with HMAC-SHA256 (`X-Bassem-Signature`) and tracked in a **Webhook Delivery Log** (`2xx` success, retry backoff, dead-letter state). Inbound ERP/DMS sync preserves immutable Batch Delta snapshots (`BR-02`), and outbound delivery failures never block field visit submissions.
- **Executive ROI & Fleet Depreciation Console (`Home` Dashboard):**
  - Available to `owner`, `admin`, and branch-scoped `regional_manager` to evaluate **Estimated Asset Cost / Depreciation**, **Maintenance Cost-to-Serve** (from SLA tickets), **YTD Revenue & Net Contribution**, **Payback Period (Months)**, and **Branch Asset Health Index**.
  - Includes branch-by-branch benchmarking and Top/Bottom ROI chiller rankings with 1-click drill-down into **`Customer 360`** or **`Map View`**.

> *[Screenshot Placeholder: Add `docs/screenshots/35_erp_webhooks_roi_console.png` showing ERP/DMS webhook subscriptions/delivery logs and the Executive ROI & Fleet Depreciation Console.]*

### 11.2 PostgreSQL/PostGIS Multi-Tenant Migration Readiness *(`STORY-023`)*
Prepare the platform for enterprise multi-tenant scale and relational geospatial persistence (`ADR-002`):
- **Multi-Tenant Isolation (`tenant_id` & RLS Context):**
  - Domain records (`chillers`, `batches`, `users`, `form_responses`, `tickets`, `audit_logs`, `webhooks`) carry a deterministic `tenant_id` and enforce tenant-scoped boundaries compatible with PostgreSQL Row-Level Security (`SET LOCAL app.tenant_id`, `app.role`, `app.branch`).
- **PostGIS Spatial Parity & Pre-Flight Diagnostics (`System Logs & Diagnostics`):**
  - Coordinates (`lat`/`lng`) validate cleanly for PostGIS `GEOGRAPHY(Point, 4326)` / `ST_Distance` spatial queries (100m geofencing, route planning, and relocation radius scoring).
  - Owners and Admins can inspect active storage mode (`JSON/Blob` vs. `PostgreSQL/PostGIS`), `tenant_id` context, and pre-flight parity checks (missing coordinates, unmapped tenants, record counts) in **System Logs & Diagnostics** (`GET /api/admin/diagnostics`), while public `GET /api/health` remains sanitized (`TC-05`).

> *[Screenshot Placeholder: Add `docs/screenshots/36_pg_postgis_readiness.png` showing multi-tenant diagnostics, PostGIS spatial parity, and migration readiness checks.]*


