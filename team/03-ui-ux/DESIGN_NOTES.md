# UI/UX Design Notes & Specs — Bassem Sales Platform

**Owner:** UI/UX Designer  
**Collaborators:** Product Owner, Business Analyst, Frontend Developers  
**Inspected Baselines:**
- [`main.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/main.dart)
- [`map_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/map_view.dart)
- [`data_table_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/data_table_view.dart)
- [`upload_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/upload_view.dart)
- [`assign_locations_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/assign_locations_view.dart)
- [`forms_manager_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/forms_manager_view.dart)
- [`customer_360_drawer.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/customer_360_drawer.dart)
- [`delta_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/delta_view.dart)
- [`form_responses_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/form_responses_view.dart)

---

## 1. Design Principles & Existing Visual Tokens

- Keep field sales workflows fast, mobile/web-responsive, and zero-clutter.
- Match the dark slate & cyan Material/Flutter aesthetic already established in `MapViewScreen` and `DataTableViewScreen`.

### Shared Color & Surface Tokens
| Token | Hex / Flutter Color | Usage |
| :--- | :--- | :--- |
| **Canvas Background** | `#0F172A` (`Color(0xFF0F172A)`) | Scaffold background, inner input/card wells, panel headers |
| **Table Header Surface** | `#0B132B` (`Color(0xFF0B132B)`) | `DataTable` heading row background |
| **Elevated Surface** | `#1E293B` (`Color(0xFF1E293B)`) | KPI strip, dialogs, floating panels (`0.96` opacity), cards |
| **Primary Accent (Cyan)** | `#06B6D4` (`Color(0xFF06B6D4)`) | Primary actions, active highlights, column headers, progress |
| **Success / Verified / Performing** | `#10B981` (`Color(0xFF10B981)`) | Emerald green — visited/accepted, performing, positive delta |
| **Warning / Pending / Re-opened** | `#F97316` (`Color(0xFFF97316)`) | Orange — pending audits, re-opened admin feedback |
| **Caution / Amber** | `#F59E0B` (`Color(0xFFF59E0B)`) | Medium priority, caution indicators |
| **Danger / Non-Performing** | `#EF4444` (`Color(0xFFEF4444)`) | Rose red — non-performing, urgent NBA, destructive actions |
| **Achievement / Analytics** | `#A78BFA` (`Color(0xFFA78BFA)`) | Soft purple — Avg Achievement % / completion metrics |
| **Navigation / Maps Blue** | `#4285F4` (`Color(0xFF4285F4)`) | Google Maps directions & "Start Route" CTAs |
| **Live GPS Blue** | `#0284C7` / `#38BDF8` | User GPS dot, radius ring, route polyline |
| **Borders & Dividers** | `Colors.white12` / `Colors.white24` | Subtle card & strip dividers |
| **Text Hierarchy** | `Colors.white` / `white70` / `white60` / `white38` | Primary / secondary / muted labels / empty or disabled |

### Shared Component Patterns
- **Badges / Pills (`_buildBadge` / `_buildKpiPill`)**: `BorderRadius.circular(20)`, `color.withValues(alpha: 0.12–0.15)` fill, `1px` border at `0.45–0.50` opacity, `11–12px` bold text.
- **Floating Panels (`_buildSurroundingLocationsPanel`)**: `BorderRadius.circular(16)`, `#1E293B` (`0.96` opacity), `1px` cyan border (`0.4` opacity), `BoxShadow(color: Colors.black54, blurRadius: 16)`, `#0F172A` top header bar with icon, title/subtitle, and close `IconButton`.
- **Responsive Breakpoints**:
  - **Desktop / Wide Web**: `>= 768px` (side-by-side strip, right slide-over drawers `420–460px`, bottom-left floating panels `380px`).
  - **Mobile / Narrow Web**: `< 768px` (or `< 600px` for full-width sheets: 2x2 KPI grid, `DraggableScrollableSheet` / modal bottom sheets at `85%` viewport height).

---

## 2. Active Design Specs Summary

| Story ID | Screen / Flow | Design Summary | Status |
| :--- | :--- | :--- | :--- |
| `STORY-003` | Map & Table Top Workspace | Rep KPI Summary Strip enhancements: Avg Achievement %, Admin Branch Target Rollup selector, and click-to-filter active pill states | `READY FOR DEV` |
| `STORY-004` | Map Pin & Table Row Detail | Customer 360 Slide-Over Drawer (Desktop) / Bottom Sheet (Mobile) with NBA Guided Selling Card, Chiller Metadata, Jan–Dec Invoice Trend, and Audit History | `READY FOR DEV` |
| `STORY-005` | Agent Map Route Mode | Smart Daily Route Planner panel, numbered map pins, `#38BDF8` polyline, priority/distance badges, and Google Maps multi-stop deep-link | `READY FOR DEV` |

---

## 3. `[STORY-003]` Rep KPI Summary Strip Enhancements

**Target Location:** Top of `MapViewScreen` (`_buildRepKpiStrip` in `map_view.dart`) and optionally mirrored at the top of `DataTableViewScreen`.

### 3.1 Layout & Responsive Behavior
- **Container:** Full-width `#1E293B`, `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)`, `border: Border(bottom: BorderSide(color: Colors.white12))`.
- **Desktop (`>= 768px`):** Single horizontal row (`Wrap` / `Row` with `spaceBetween`):
  - **Left cluster:** `Icons.speed` (`#06B6D4`) + Title `Rep KPI Summary (My Territory)` or `(All Territories)` + Admin Branch Target Rollup selector (when `role == admin | owner`) + active filter reset chip (when a pill filter is active).
  - **Right cluster:** 4 KPI pills in a horizontal row.
- **Mobile (`< 768px`):**
  - Title + Branch selector row on top.
  - **2x2 Compact Grid** (`GridView.count` / `LayoutBuilder` 2 columns, `spacing: 8`) for the 4 KPI pills so labels and numbers never wrap awkwardly or overflow horizontally.

### 3.2 KPI Pills & `Avg Achievement %`
1. **Assigned** (`#06B6D4`, `Icons.location_on_outlined`): Total assigned chillers (or branch-filtered count).
2. **Visited** (`#10B981`, `Icons.verified_outlined`): Count + `%` (e.g., `18 (45%)`).
3. **Pending** (`#F97316`, `Icons.pending_actions_outlined`): Count of unvisited this month + `Re-opened` audits.
4. **Avg Achievement %** (`#A78BFA`, `Icons.trending_up_rounded` or `Icons.pie_chart_outline`):
   - Replaces/upgrades the generic `Completion` label to `Avg Ach.`.
   - Formatted to **1 decimal place** (e.g., `84.3%`).
   - **Null / Non-numeric Handling:** If no valid numeric achievement values exist in the scope, display `N/A` in `Colors.white60` (never `NaN%` or `0.0%` misleadingly). Include a `Tooltip` showing `"Mean YTD/Monthly achievement across X valid chillers"`.

### 3.3 Click-to-Filter Active Pill States
- **Interactive Pills:** `Visited` and `Pending` pills are clickable (`InkWell` with `BorderRadius.circular(20)`). Clicking `Assigned` clears the KPI visit-status filter (resets to All).
- **Default State:**
  - Fill: `color.withValues(alpha: 0.12)`
  - Border: `1px solid color.withValues(alpha: 0.45)`
  - Cursor: `SystemMouseCursors.click`
- **Active (Selected) State:**
  - Fill: `color.withValues(alpha: 0.28)`
  - Border: `1.5px solid color` (full opacity)
  - Leading/trailing indicator: Small check/filter dot or `Icons.filter_alt` (`13px`) + subtle glow (`BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)`).
  - **Active Filter Chip:** When `Visited` or `Pending` is active, show a compact `"Filter: Pending ×"` `InputChip` / pill next to the strip title (or in the filter bar) so the user can reset with one click. Clicking the same active pill again also toggles the filter off.

### 3.4 Admin Branch Target Rollup Selector (`role = admin | owner`)
- **Visibility:** Hidden for `agent` role; visible only for `admin` and `owner`.
- **Trigger Button:** Compact pill/dropdown button in the left cluster:
  - Icon: `Icons.account_tree_outlined` (`#06B6D4`, `15px`)
  - Label: `Branch: All` (or `Branch: Cairo East` when selected) + `Icons.keyboard_arrow_down`.
  - Surface: `#0F172A`, `Border.all(color: Colors.white24)`, `BorderRadius.circular(8)`.
- **Popover / Dialog (`Menu` or `AlertDialog` on mobile):**
  - Header: `Branch Target Rollup` with `All Branches` reset option.
  - Table / List rows sorted by branch name (or lowest achievement first):
    - `Branch Name` (bold white)
    - `Chillers` count (`#06B6D4`)
    - `Visited %` (`#10B981`)
    - `Avg Ach %` (`#A78BFA`, or `N/A`)
    - Mini horizontal progress bar (`LinearProgressIndicator`, height `4px`) under each branch row.
  - **Interaction:** Clicking a branch row filters the KPI strip, Map pins, and Data Table to that branch, and updates the trigger label to `Branch: <Name>`.

### 3.5 Loading, Empty & Error States
- **Loading:** Inline `12x12` `CircularProgressIndicator` (`#06B6D4`) next to the strip title while preserving last known numbers (or `—` placeholders on initial load).
- **Empty (0 chillers):** Show `0` for counts and `N/A` for `Avg Ach. %`; clicking `Visited`/`Pending` shows a subtle toast `"No chillers match this filter"`.
- **Error:** Keep strip visible with `—` values and a compact amber retry icon (`Icons.refresh`, `#F59E0B`) with tooltip `"Failed to load KPIs. Tap to retry."`.

---

## 4. `[STORY-004]` Customer 360 Slide-Over Drawer

**Entry Points:**
1. Tapping any chiller pin on `MapViewScreen` (replaces the centered `AlertDialog` with a non-blocking or modal right-side slide-over drawer on desktop so the map remains visible).
2. Tapping a row (or a `"360°"` action icon in the first column) on `DataTableViewScreen`.

### 4.1 Responsive Container & Geometry
- **Desktop / Tablet (`>= 600px`):** Right-side slide-over drawer (`width: 440px`, full height, `#1E293B` background, `Border(left: BorderSide(color: Colors.cyan.withValues(alpha: 0.35)))`, `BoxShadow(color: Colors.black54, blurRadius: 24)`). Animates in from the right (`220ms easeOutCubic`). Dismissible via close `X` button, `Esc` key, or tapping outside scrim.
- **Mobile (`< 600px`):** `showModalBottomSheet` with `DraggableScrollableSheet` (`initialChildSize: 0.85`, `maxChildSize: 0.95`, `minChildSize: 0.5`), `#1E293B` background, top drag handle (`40x4px`, `Colors.white24`), `BorderRadius.vertical(top: Radius.circular(20))`.

### 4.2 Drawer Vertical Structure (Top to Bottom)

#### A. Sticky Header (`#0F172A`)
- Left: `40x40` rounded-8 icon container (`_getMarkerColor(efficiency).withValues(alpha: 0.2)`) with `Icons.ac_unit`.
- Middle:
  - `Customer Name` (`16px`, bold white, max 2 lines with ellipsis).
  - `Chiller Code` + `Branch` (`12px`, `Colors.white70`).
- Right: Close `IconButton` (`Icons.close`, `Colors.white70`).
- Below title row: `Wrap` of status badges (`_buildBadge`):
  - Visit Status (`✅ Verified` `#10B981` / `⏳ Submitted` `#06B6D4` / `⚠️ Re-opened` `#F97316` / `⭕ Not Visited` `white54`)
  - Efficiency (`Performing` / `Non-Performing` / `Zero`)
  - `Customer Type` (`Retail`, `LS`, `SM`, `LG`)
  - `Distance from You` (if GPS active, `#06B6D4`)

#### B. Highlighted "Next Best Action" (NBA) Guided Selling Card
- Positioned prominently right below the header so reps see what to do before scrolling.
- **Card Styling:** `BorderRadius.circular(12)`, `padding: 14px`, tinted background (`severityColor.withValues(alpha: 0.14)`), `1.5px` border (`severityColor`), subtle left accent bar (`4px` wide).
- **Severity Variants:**
  - **Urgent / Action Required (`#EF4444` or `#F97316`):** e.g., *Visit Re-opened by Admin* (shows admin feedback inline) or *Condition = Requires Maintenance / Scrap*.
  - **Revenue Opportunity (`#06B6D4`):** e.g., *YTD dropped >20% MoM* -> `"Pitch Restock / Promo Bundle"`.
  - **On Track (`#10B981`):** e.g., *Performing & Verified* -> `"Maintain Share & Check POSM"`.
- **Card Content:**
  - Top eyebrow row: `Icons.auto_awesome` (or `Icons.warning_amber_rounded`) + `NEXT BEST ACTION` (`10px`, uppercase, bold, letter-spacing `0.8`, `severityColor`).
  - Headline: Clear 1-line action (`14px`, bold white).
  - Rationale: 1–2 line data-backed reason (`12px`, `Colors.white70`, e.g., *"Nov invoice dropped 28% vs Oct; chiller is Good condition."*).
  - Quick Action Link/Button (optional): e.g., `"Fill Audit Form →"` or `"Open Directions →"`.

#### C. Chiller Asset Metadata & GPS Card
- `#0F172A` inner card (`BorderRadius.circular(12)`, `border: Border.all(color: Colors.white12)`).
- 2-column key-value grid (`Chiller Status`, `Condition`, `Chiller Type`, `Month Ach. Status`, `Serial / Asset ID`, `Assigned Rep`).
- GPS row at bottom of card: `Lat, Lng` + compact `#4285F4` `Directions` button (`Icons.navigation_rounded`).
- Collapsible `ExpansionTile` below: `"All Row Attributes (36+ Columns)"` preserving full raw Excel record inspection without cluttering the main view.

#### D. Jan–Dec Invoice Trend & Summary
- Section Header: `Jan–Dec Invoice Trend` + right-aligned `YTD Total` pill (`#06B6D4`).
- **Summary Metrics Row (3 compact stat boxes in `#0F172A`):**
  1. `YTD Total` (formatted currency/number, white bold)
  2. `Latest Month` (e.g., `Dec: 14,200`)
  3. `MoM Change` (`+12.4%` in `#10B981` or `-18.2%` in `#EF4444`, or `N/A` in `white38`)
- **12-Month Mini Bar / Sparkline Chart:**
  - 12 slim vertical bars (`Jan`–`Dec`) inside a `100px` tall `#0F172A` container.
  - Bar color: `#06B6D4` for normal months, `#10B981` for peak month, `#EF4444` if latest month dropped >20% vs prior month, `Colors.white12` for `0` / missing months.
  - Hover/tap tooltip on each bar showing `Month: Value`.
- **Empty Invoice State:** If all Jan–Dec columns are missing/empty, show a compact `48px` muted box: `"No Jan–Dec invoice history available for this record."`

#### E. Recent Visit Audit History
- Section Header: `Recent Visit Audits` + count badge.
- Vertical timeline list (most recent first, max 5 shown with `"Show all"` if more):
  - Left timeline dot colored by status (`Accepted` `#10B981`, `Submitted` `#06B6D4`, `Re-opened` `#F97316`).
  - Card (`#0F172A`, `BorderRadius.circular(10)`):
    - Date/time + Rep name + Status pill.
    - If `Re-opened`: inline `#F97316` feedback callout.
    - Expandable summary of submitted form fields + photo attachment thumbnails (tap thumbnail to preview full-screen).
- **Empty Audit State:** Dashed/muted `#0F172A` box with `Icons.history` and `"No visit audits recorded yet. Tap 'Complete Visit' below to log the first audit."`

#### F. Sticky Footer (`#0F172A`, `border-top: white12`)
- Full-width or split action bar:
  - **Primary CTA:** `Complete Visit (Fill Form)` (`#06B6D4` with black bold text; `#F97316` for `Resubmit Visit Audit`; `#10B981` for `Update Audit Form`) — opens existing `FormFillerDialog`.
  - **Secondary CTA:** `Google Maps` (`#4285F4` icon button or outlined button).

### 4.3 Loading & Error States
- **Loading:** Header renders immediately from the tapped chiller object; Invoice Trend & Audit History sections show shimmer/skeleton placeholders (`#0F172A` pulsing boxes) if fetched asynchronously.
- **Error:** Inline `#EF4444` banner inside the affected section with `"Retry"` button; never blocks the rest of the drawer or `FormFillerDialog`.

---

## 5. `[STORY-005]` Smart Daily Route Planner

**Entry Point:** `"Plan My Day"` button in `MapViewScreen` (compact outlined/filled button in the bottom-right FAB stack above `Surrounding Locations`, or in the top-left map toolbar).

### 5.1 Map Layer Visualization
- **Route Polyline (`PolylineLayer`):**
  - Connects `User Live GPS` (if available) → `Stop 1` → `Stop 2` → ... → `Stop N`.
  - Stroke: `4.0px` solid or dashed `#38BDF8` (`Color(0xFF38BDF8)`) with a subtle `7.0px` `#0F172A` outer casing for high contrast against OpenStreetMap tiles.
- **Numbered Route Pins (`MarkerLayer`):**
  - Replaces or overlays standard pins for stops in the active route with `30x30` circular badges:
    - Background: `#06B6D4` (or priority border ring: `#EF4444` for Urgent, `#F97316` for Re-opened/High).
    - Center text: Bold white sequence number (`1`, `2`, `3`, ...).
    - Active/hovered stop scales to `36x36` with white outer ring.
  - Non-route pins dim to `0.35` opacity while Route Mode is active so the rep's eye locks onto their sequence.

### 5.2 Route Planner Panel
- **Position & Sizing:**
  - **Desktop (`>= 600px`):** Bottom-left floating panel (`width: 380px`, `maxHeight: 500px`), matching `_buildSurroundingLocationsPanel` (`#1E293B` at `0.96` opacity, `BorderRadius.circular(16)`, cyan border). Opening Route Planner automatically closes Surrounding Panel (and vice versa) to prevent overlap.
  - **Mobile (`< 600px`):** `DraggableScrollableSheet` (`initialChildSize: 0.45`, `maxChildSize: 0.85`) so the rep can see the map polyline above and scroll stops below.

- **Panel Header (`#0F172A`):**
  - Icon: `Icons.route_rounded` (`#06B6D4`).
  - Title: `Smart Daily Route`
  - Subtitle: `X stops • ~Y.Y km total`
  - Close / Exit Route Mode `IconButton` (`Icons.close`).

- **Quick Controls Bar (compact row below header):**
  - **Max Stops Chip/Dropdown:** `5` | `8` | `10` | `15` stops.
  - **Sort Mode Toggle:** `Smart Priority` (Urgency + Proximity) vs `Shortest Path` (Nearest Neighbor).
  - **Pending Only Toggle:** Switch/chip (`Pending Only` ON by default so already-verified stores are skipped).

- **Ordered Stop List (`ListView.separated`):**
  - Each stop card (`#0F172A`, `BorderRadius.circular(10)`, `padding: 10px`):
    - **Left:** `26x26` circular sequence badge (`1`, `2`, `3`...) in `#06B6D4` with black bold text.
    - **Center:**
      - `Customer Name` (`13px`, bold white, ellipsis)
      - `Chiller Code` + `Branch` (`11px`, `Colors.white60`)
      - **Badges Row:**
        - **Distance Badge:** e.g., `1.2 km` (`#06B6D4`, `Icons.near_me`) from previous stop / user.
        - **Priority Badge:**
          - `Re-opened` (`#F97316`)
          - `Non-Performing` / `Urgent` (`#EF4444`)
          - `Pending` (`#F59E0B`)
          - `Standard` (`Colors.white54`)
    - **Right:** Up/Down reorder micro-buttons (or drag handle) + Remove from today's route (`Icons.close`, `16px`, `white38`).
  - **Tap Stop Behavior:** Pans & zooms map (`zoom: 15.5`) to the stop and opens the **Customer 360 Drawer** (`STORY-004`).

- **Sticky Footer CTA (`#0F172A`):**
  - Primary Button: **`Start Route in Google Maps`** (`#4285F4`, `Icons.directions_rounded`, full width).
  - Deep-link format: `https://www.google.com/maps/dir/?api=1&origin=<userLat,userLng>&destination=<lastStopLat,lastStopLng>&waypoints=<stop1|stop2|...>&travelmode=driving`.
  - *Note for Dev:* Google Maps URLs support up to 9 waypoints cleanly on mobile/web; if >10 stops are selected, show a subtle helper caption `"Opening first 10 stops in Google Maps"` or provide `"Next Leg"` support.

### 5.3 Empty, No-GPS & Error States
- **No Live GPS Detected:** Show an inline banner at the top of the Route Panel (`#0284C7` with `0.15` fill): `"GPS off — routing from map center. Tap to enable Live GPS"` with a 1-tap `Locate Me` button (reusing `_locateUser`).
- **No Matching Stops (e.g., all visited):** Empty state inside panel with `Icons.check_circle_outline` (`#10B981`), `"All assigned chillers are visited!"` and a `"Show All Chillers"` button to toggle off `Pending Only`.
- **Error Launching Maps:** Show `SnackBar` (`Colors.redAccent`) with `"Could not open Google Maps. Check popup blocker or copy route link."`.

---

## 6. UI/UX Sprint 1 (P4) — Design System, Navigation & Field Ergonomics

> **Sprint Goal:** Eliminate hardcoded style drift across views, improve outdoor field legibility, modernize file ingestion, and move mobile navigation into the ergonomic thumb zone.

### 6.1 Unified Design Tokens & Theme Modes (`main.dart` → `lib/theme/app_tokens.dart`)

**Current Gap:** [`main.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/main.dart) hardcodes `ThemeData.dark()` with inline `Color(0xFF0F172A)` / `Color(0xFF1E293B)` across every view (`map_view.dart`, `data_table_view.dart`, `upload_view.dart`, `assign_locations_view.dart`, `forms_manager_view.dart`). There is no spacing scale, typography scale, or light/outdoor high-contrast mode for field reps working in direct sunlight.

**Spec:** Introduce `AppThemeMode` (`dark`, `light`, `outdoor`) persisted in `storage.dart` and exposed via a compact theme switcher icon in the `AppBar` (next to Change Password). Implement a `ThemeExtension<AppTokens>` so widgets read `Theme.of(context).extension<AppTokens>()!`.

#### A. Spacing & Radius Scale
| Token | Value | Usage |
| :--- | :--- | :--- |
| `spaceXs` | `4.0` | Micro gaps (badge icon-to-text, inline chip spacing) |
| `spaceSm` | `8.0` | Compact card inner gaps, mobile grid spacing |
| `spaceMd` | `12.0` | Default form field / list item spacing |
| `spaceLg` | `16.0` | Standard card padding, strip padding |
| `spaceXl` | `24.0` | Page section padding (`upload_view.dart`, `delta_view.dart`) |
| `radiusSm` | `8.0` | Inputs, table badges, small action buttons |
| `radiusMd` | `12.0` | Cards, NBA callout, dropzone, primary CTAs |
| `radiusLg` | `16.0` | Floating map panels (`_buildSurroundingLocationsPanel`, Route Panel) |
| `radiusPill` | `20.0` | KPI pills, status badges, filter chips |

#### B. Typography Scale (Material 3 `TextTheme` + `tabularFigures`)
- **`displayTitle`**: `22px`, `FontWeight.w700`, `-0.3` letter-spacing (Page headers).
- **`sectionTitle`**: `16px`, `FontWeight.w700` (Drawer/panel headers).
- **`cardTitle`**: `14px`, `FontWeight.w600` (Customer name, card headings).
- **`bodyDefault`**: `13px`, `FontWeight.w400`, height `1.4` (Table cells, descriptions).
- **`caption`**: `11.5px`, `FontWeight.w500` (Subtitles, secondary metadata).
- **`eyebrow`**: `10px`, `FontWeight.w700`, `+0.8` letter-spacing, uppercase (e.g., `NEXT BEST ACTION`).
- **`metricNum`**: `13–15px`, `FontWeight.w700`, `fontFeatures: [FontFeature.tabularFigures()]` (KPI counts, percentages, YTD invoice totals — prevents jitter on updates).

#### C. Color Modes: Dark (Default) / Light / Outdoor Field Contrast
| Semantic Role | Dark Mode (Default) | Light Mode (Office/Web) | Outdoor Field Contrast (Sunlight) |
| :--- | :--- | :--- | :--- |
| `canvasBg` | `#0F172A` | `#F8FAFC` | `#FFFFFF` (pure white, zero glare washout) |
| `surfaceElevated` | `#1E293B` | `#FFFFFF` | `#F1F5F9` with `1.5px` `#0F172A` border |
| `surfaceHeader` | `#0B132B` | `#E2E8F0` | `#0F172A` (high-contrast header bar) |
| `textPrimary` | `#FFFFFF` | `#0F172A` | `#020617` (`>= 14:1` contrast) |
| `textSecondary` | `white70` (`#B3FFFFFF`) | `#475569` | `#1E293B` (never muted grey in sunlight) |
| `borderSubtle` | `white12` (`#1FFFFFFF`) | `#CBD5E1` | `#64748B` (`1.5px` crisp outlines) |
| `accentPrimary` | `#06B6D4` | `#0891B2` | `#0369A1` (deepened cyan for WCAG AA on white) |
| `success` | `#10B981` | `#059669` | `#047857` |
| `warning` | `#F97316` | `#EA580C` | `#C2410C` |
| `danger` | `#EF4444` | `#DC2626` | `#B91C1C` |

---

### 6.2 Skeleton Loaders & Empty States (Cross-App Standard)

**Current Gap:** `map_view.dart`, `upload_view.dart`, `assign_locations_view.dart`, and `data_table_view.dart` all render bare centered `CircularProgressIndicator` spinners with no structural preview, and empty states vary between plain `Text` and ad-hoc containers.

**Spec:** Create two reusable shared widgets: `AppSkeleton` and `AppEmptyState`.
- **Skeleton Loaders (`AppSkeleton`):**
  - Pulsing `AnimatedOpacity` / `LinearGradient` shimmer (`1100ms` loop) using `surfaceElevated` → `surfaceElevated.withValues(alpha: 0.5)`.
  - **Map View:** Keep the OSM tile layer visible; overlay a subtle top progress bar (`2px` `#06B6D4`) + skeleton KPI strip pills (`84x28` rounded pills).
  - **Data Table View:** Render 8 skeleton rows (`48px` height) with alternating `120px` / `80px` / `60px` rounded bars matching column widths.
  - **Assign Locations / Forms Manager:** Render 5 skeleton list cards (`72px` height, `radiusMd`).
  - **Customer 360 Drawer:** Header renders immediately; Invoice Trend & Audit History show `100px` and `72px` skeleton blocks while loading.
- **Empty States (`AppEmptyState`):**
  - Centered container (`maxWidth: 420px`, `padding: 32px`), `surfaceElevated` fill, `1px` `borderSubtle`, `radiusLg`.
  - **Slots:** `48px` circular tinted icon well (`accentPrimary.withValues(alpha: 0.14)`), Title (`16px` bold), 1–2 line helpful subtitle (`textSecondary`), and optional **Primary CTA** (e.g., `"Clear Active Filters"`, `"Upload Master Excel"`, `"Create First Form"`).
  - Differentiate **"No data uploaded yet"** (Admin CTA to `UploadViewScreen`) vs **"No records match current filters"** (1-tap `"Reset Filters"` CTA).

---

### 6.3 Condition Pin Coloring (`map_view.dart`)

**Current Gap:** [`_getMarkerColor`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/map_view.dart#L390-L400) in `map_view.dart` only maps `efficiency` (`Performing`, `Non-Performing`, `Zero`). Field reps and maintenance supervisors cannot visually distinguish chiller physical **Condition** (`Operational`, `Requires Maintenance`, `Scrap`) on the map.

**Spec:** Add a **Pin Color Mode Toggle** in the `MapViewScreen` top-left control bar (compact segmented pill: `Efficiency` | `Condition`).
- **Condition Color & Icon Mapping:**
  | Condition Value (case-insensitive match) | Pin Fill Color | Inner Pin Icon | Legend Label |
  | :--- | :--- | :--- | :--- |
  | `Operational` / `Good` / `Working` | `#10B981` (Emerald) | `Icons.check_circle_outline` | `Operational` |
  | `Requires Maintenance` / `Maintenance` / `Needs Repair` | `#F97316` (Orange) | `Icons.build_circle_outlined` | `Requires Maint.` |
  | `Scrap` / `Damaged` / `Decommissioned` | `#EF4444` (Rose Red) | `Icons.dangerous_outlined` | `Scrap` |
  | `Unknown` / empty / `-` | `#64748B` (Slate Grey) | `Icons.help_outline` | `Unspecified` |
- **Dual-Signal Accessibility:** Never rely on color alone — render the distinct `13px` inner icon inside the `28x28` marker pin in `Condition` mode, and update the floating map legend dynamically when switching between `Efficiency` and `Condition` modes.
- **Filter Chip:** Add a quick `Condition` filter dropdown/chip alongside existing efficiency/visit filters so reps can isolate `Requires Maintenance` + `Scrap` chillers in 1 tap.

---

### 6.4 Drag-and-Drop CSV/Excel Upload UX (`upload_view.dart`)

**Current Gap:** [`upload_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/upload_view.dart#L141-L172) has a comment `// Dropzone & Action Bar` but only renders two buttons (`Quick Load Sample Excel` and `Browse & Upload Custom Excel (.xlsx)`), with no actual drag-and-drop target, no `.csv` visual affordance, and no staged upload feedback.

**Spec:** Replace the top button row with a **2-Column Responsive Dropzone + Quick Actions Card** (stacks vertically on `< 768px`):
- **Interactive Dropzone (`desktop_drop` / HTML5 Web drag-drop listener):**
  - Container: `minHeight: 160px`, dashed border (`2px`, `Colors.white24` default → `#06B6D4` with `0.12` cyan tint on `dragOver` → `#10B981` on valid drop → `#EF4444` on invalid extension).
  - Center content: `44px` upload cloud icon (`Icons.cloud_upload_outlined`), `"Drag & drop your .xlsx, .xls, or .csv file here"`, secondary `"or click to browse files (max 25 MB)"`, and accepted format pills (`.XLSX`, `.XLS`, `.CSV`).
  - **File Selected / Parsing State:** Show selected filename, file size badge, a determinate/indeterminate `LinearProgressIndicator` (`#06B6D4`), and step indicator: `1. Uploading` → `2. Validating Columns` → `3. Ready for UPSERT`.
- **Validation Preview Enhancements:** Keep the 4 KPI summary cards (`Uploaded File`, `Total Rows`, `Valid Rows`, `Incomplete / Missing`) and add a **Validation Filter Toggle** (`All Rows` | `Errors Only`) above the preview table so admins can immediately inspect only the failing rows before choosing strict vs bypassed save.

---

### 6.5 Mobile Thumb-Zone Navigation (`main.dart`)

**Current Gap:** In [`main.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/main.dart#L176-L188), mobile (`screenWidth < 768`) hides `NavigationRail`, gives **Admins** a top-left hamburger `Drawer` (hard to reach one-handed), and gives **Sales Agents** only 1 tab with no bottom bar.

**Spec:** Add a bottom `NavigationBar` (Material 3) on `< 768px` with `SafeArea` bottom padding (`height: 64px`, `surfaceElevated` background, `1px` top `borderSubtle`), keeping primary actions in the lower thumb zone:
- **Admin / Owner Mobile Bottom Bar (4 primary tabs + `More` sheet):**
  1. `Map` (`Icons.map_outlined` / `Icons.map`)
  2. `Table` (`Icons.table_chart_outlined` / `Icons.table_chart`)
  3. `Assign` (`Icons.assignment_ind_outlined` / `Icons.assignment_ind`)
  4. `Responses` (`Icons.rate_review_outlined` / `Icons.rate_review`)
  5. `More` (`Icons.grid_view_rounded`) → Opens a `showModalBottomSheet` grid with: `Upload & Validate`, `Sales Agents`, `Forms Manager`, `System Logs` (Owner only), and `Theme Mode` toggle.
- **Sales Agent Mobile Bottom Bar (3 ergonomic tabs / quick actions):**
  1. `My Map` (`Icons.map`) — `MapViewScreen`
  2. `My List` (`Icons.list_alt`) — Filtered mobile card list of assigned chillers (or `DataTableViewScreen` mobile card mode) for quick search without panning the map.
  3. `Route` (`Icons.route_rounded`) — Jumps to Map and toggles Smart Daily Route Mode (`STORY-005`).
- **Desktop (`>= 768px`):** Preserve the existing `NavigationRail` (`extended: screenWidth >= 1100`).

---

## 7. UI/UX Sprint 2 (P5) — Visual Intelligence, Micro-Interactions & Polish

> **Sprint Goal:** Upgrade power-user data workflows, surface visual evidence and before/after diffs, standardize inline validation/toasts, and prepare the app for WCAG AA accessibility and Arabic RTL.

### 7.1 Data Table Column Pinning, Density Toggle & Multi-Sort UI (`data_table_view.dart`)

**Current Gap:** [`DataTableViewScreen`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/data_table_view.dart#L28-L30) supports single-column sorting (`_sortColumn`, `_sortAscending`) and basic column hiding, but horizontal scrolling across 36+ Excel columns loses `Customer Name` / `Chiller Code` context, and there is no row density control.

**Spec:**
1. **Column Pinning (Sticky Left Freeze):**
   - Pin `360° Action + Chiller Code + Customer Name` (configurable via a `"Pin"` icon in the existing Column Visibility dialog) into a fixed left `DataTable` / `ListView` synchronized vertically with the horizontally scrollable remaining columns.
   - Visual separator: `2px` right shadow/border (`#06B6D4` at `0.25` opacity) on the pinned edge so users clearly see the frozen boundary.
2. **Row Density Toggle:**
   - Segmented icon button in the table toolbar: `Compact` (`36px` row height, `12px` font), `Standard` (`48px`, `13px` — current default), `Comfortable` (`60px`, `13.5px` + wrapped address). Persist preference in `storage.dart`.
3. **Multi-Sort UI:**
   - Replace single `_sortColumn` with `List<SortRule>` (max 3 levels: Primary, Secondary, Tertiary).
   - **Interaction:** Clicking a column header sets/toggles primary sort; `Shift + Click` (Desktop) or tapping `+ Sort` in the column header menu (Mobile/Touch) appends a secondary/tertiary sort rule.
   - **Header Indicator:** Show numbered sort badge (`1 ↑`, `2 ↓`) next to sorted column titles, plus a dismissible `"Sorted by: Branch ↑, YTD ↓ ×"` chip bar above the table.

---

### 7.2 Audit Photo Gallery & Before/After Delta Visual Diff Cards (`customer_360_drawer.dart`, `form_responses_view.dart`, `delta_view.dart`)

**Current Gap:** [`form_responses_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/form_responses_view.dart#L281-L322) renders basic `Image.network` thumbnails with a simple zoom dialog, `customer_360_drawer.dart` lists text audit history, and [`delta_view.dart`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/delta_view.dart) displays batch diffs as plain text tables.

**Spec:**
1. **Audit Photo Gallery & Lightbox (`customer_360_drawer.dart` & `form_responses_view.dart`):**
   - **Thumbnail Grid:** `3-column` (Drawer) or `4-column` (Responses) `80x80` rounded-8 thumbnails with subtle overlay badge (`Photo 1/4`, timestamp, and `GPS Verified` green dot if geotagged).
   - **Lightbox Modal:** Full-screen dark scrim (`Colors.black87`), `InteractiveViewer` (pinch/scroll zoom `1x–4x`), Left/Right keyboard & swipe navigation (`<` / `>`), metadata footer (Rep name, Chiller Code, Audit Date, Condition), and a `Download` button.
   - **Broken/Loading Image State:** Shimmer placeholder while loading; styled `Icons.broken_image_outlined` card with `"Image unavailable"` on error.
2. **Before/After Delta Visual Diff Cards (`delta_view.dart`):**
   - Replace dense raw diff rows with **Visual Diff Cards** (`surfaceElevated`, `radiusMd`, `1px` `borderSubtle`):
     - **Card Header:** Chiller Code (`#06B6D4`) + Customer Name + Change Type pill (`Added` `#10B981`, `Removed` `#EF4444`, `Modified` `#F59E0B`).
     - **Field Diff Chips (Before → After):** Side-by-side pill comparison:
       - `Condition`: `[Operational]` (strikethrough/muted) `→` `[Requires Maintenance]` (`#F97316` highlight).
       - `Efficiency`: `[Non-Performing]` `→` `[Performing]` (`#10B981` highlight with `Icons.trending_up`).
       - `YTD Invoice`: Numeric delta badge (`+14,500 / +18.2%` in `#10B981` or `-6,200 / -11.0%` in `#EF4444`).
     - **Quick Action:** `"Open 360°"` button on each card to inspect full chiller history.

---

### 7.3 Inline Validation & Toast Feedback System (Cross-App Standard)

**Current Gap:** Views (`upload_view.dart`, `assign_locations_view.dart`, `forms_manager_view.dart`, `data_table_view.dart`) call `ScaffoldMessenger.of(context).showSnackBar(...)` directly with inconsistent colors (`Colors.redAccent`, `Colors.green`, etc.) and no inline field-level error recovery.

**Spec:**
1. **Unified Toast / Banner Helper (`AppToast.show(context, type: ..., message: ..., actionLabel: ...)`):**
   - Floating `SnackBarBehavior.floating` (`maxWidth: 460px` on desktop, bottom-aligned above `NavigationBar` on mobile), `radiusMd`, `4px` left semantic accent bar, leading icon + concise message + optional `Undo` / `Retry` action button.
   - **4 Semantic Types:** `success` (`#10B981`, `Icons.check_circle`), `info` (`#06B6D4`, `Icons.info`), `warning` (`#F59E0B`, `Icons.warning_amber`), `error` (`#EF4444`, `Icons.error`).
   - Auto-dismiss: `3s` for `success`/`info`, `5s` for `warning`/`error` (with manual close `X`).
2. **Inline Form Validation (`forms_manager_view.dart`, `form_filler_dialog.dart`, `login_view.dart`):**
   - Use `AutovalidateMode.onUserInteraction` after first submit attempt.
   - Highlight invalid fields with `1.5px` `#EF4444` border + inline helper text below the input (`11.5px` `#EF4444`, `Icons.error_outline` `13px`) and auto-scroll to the first invalid field on submit.
   - In `forms_manager_view.dart`, show an inline warning badge on `"choose"` fields that have `< 2` options instead of failing silently or only showing a toast on save.

---

### 7.4 Accessibility (WCAG AA) & Arabic RTL Layout Readiness (`main.dart` + All Views)

**Current Gap:** No `Directionality` / `EdgeInsetsDirectional` audit has been done; several views use hardcoded `EdgeInsets.only(left: ...)` / `Alignment.centerLeft` / `Border(left: ...)`, and icon-only buttons lack consistent `Semantics` labels or `44x44` minimum touch targets.

**Spec:**
1. **Arabic RTL Layout Readiness:**
   - Add `Locale('en')` and `Locale('ar')` to `MaterialApp.supportedLocales` with `flutter_localizations` delegates, plus a language toggle (`EN` / `عربي`) in the `AppBar` / `More` sheet.
   - **Directional Layout Rules (Audit Checklist for Dev):**
     - Replace `EdgeInsets.only(left: ..., right: ...)` with `EdgeInsetsDirectional.only(start: ..., end: ...)`.
     - Replace `Alignment.centerLeft` / `Alignment.topRight` with `AlignmentDirectional.centerStart` / `AlignmentDirectional.topEnd`.
     - Replace `Border(left: ...)` (e.g., NBA card accent bar, pinned column border) with `BorderDirectional(start: ...)` / `BorderDirectional(end: ...)`.
     - Mirror directional icons (`Icons.arrow_forward`, `Icons.chevron_right`) via `matchTextDirection: true` or `Icon(Icons.arrow_forward_ios)` inside `Directionality`.
     - Keep **Chiller Codes, GPS coordinates, and numeric KPIs** (`LTR` via `TextDirection.ltr` or `Directionality`) so codes like `CH-1042` and `-12.4%` never reverse in Arabic mode.
2. **Accessibility (WCAG AA & Touch Targets):**
   - Enforce `minWidth: 44, minHeight: 44` (`MaterialTapTargetSize.padded`) on all mobile `IconButton`s, pin markers, and filter chips.
   - Wrap custom `InkWell` / `GestureDetector` elements (KPI pills, map pins, photo thumbnails) in `Semantics(button: true, label: '...')` for screen readers.
   - Support keyboard `Tab` focus rings (`focusColor: accentPrimary.withValues(alpha: 0.25)`) and `Esc` to close `Customer360Drawer` and Lightbox modals.

---

## 8. P4 & P5 Implementation Priority & Acceptance Checklist

| Sprint | Item | Target Files | Acceptance Criteria |
| :--- | :--- | :--- | :--- |
| **P4** | Unified Design Tokens & 3 Theme Modes | `main.dart`, `lib/theme/app_tokens.dart` | Zero hardcoded `0xFF0F172A` in new code; Dark/Light/Outdoor toggle works & persists |
| **P4** | Skeleton Loaders & Empty States | `lib/widgets/app_skeleton.dart`, `app_empty_state.dart` | All async views show structured skeletons; empty filters offer 1-tap reset |
| **P4** | Condition Pin Coloring | `map_view.dart` | Toggle between `Efficiency` and `Condition` (`Operational` / `Requires Maintenance` / `Scrap`) with icons + legend |
| **P4** | Drag-and-Drop CSV/Excel Upload | `upload_view.dart` | Drag-over highlight, `.xlsx/.xls/.csv` support, progress bar, `Errors Only` preview filter |
| **P4** | Mobile Thumb-Zone Navigation | `main.dart` | `< 768px` uses bottom `NavigationBar` + `More` sheet; Agents get `My Map` / `My List` / `Route` |
| **P5** | Data Table Pinning, Density & Multi-Sort | `data_table_view.dart` | Sticky left columns, 3 density modes, up to 3-level sort with numbered badges |
| **P5** | Audit Photo Gallery & Delta Diff Cards | `customer_360_drawer.dart`, `form_responses_view.dart`, `delta_view.dart` | Zoomable lightbox gallery; Before→After visual diff cards in Delta view |
| **P5** | Inline Validation & Toast System | `lib/widgets/app_toast.dart`, form views | Unified floating toasts; inline field errors + auto-scroll on invalid submit |
| **P5** | Accessibility & Arabic RTL Readiness | `main.dart` + all views | `EdgeInsetsDirectional` / `BorderDirectional` migration; `44x44` touch targets; `EN/AR` toggle |

---

## 9. Step-Change Role-Tailored Home Dashboard & Workflow UI/UX (`DashboardViewScreen`)

> **Design Objective:** Replace the cold "land straight on a dense map/table" experience with a calm, executive-grade, role-tailored **`DashboardViewScreen`** as **Tab 0 (Home)** for every role. Prioritize **generous whitespace**, **crisp typographic hierarchy**, **scannable cards**, **zero visual clutter**, and **1-tap primary workflows** — built 100% on [`AppTokens`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/theme/app_tokens.dart) (Dark, Light, and Outdoor Field Contrast) with pure Flutter charts (no new `pubspec.yaml` dependencies).

### 9.1 Navigation & Shell Integration (`main.dart`)

- **First Tab (`index = 0`) for All Roles:**
  - **Desktop (`>= 768px`):** `NavigationRail` index `0` = `Home` (`Icons.dashboard_outlined` / `Icons.dashboard_rounded`).
  - **Mobile (`< 768px`):** Bottom `NavigationBar` index `0` = `Home` (`Icons.dashboard_outlined` / `Icons.dashboard_rounded`), keeping the thumb zone clean:
    - **Owner / Regional Manager / Admin:** `Home` · `Map` · `Table` · `Responses` · `More` (sheet holds `Upload`, `Assign`, `Agents`, `Forms`, `Logs`).
    - **Supervisor:** `Home` · `Map` · `Assign` · `Responses` · `Table`.
    - **Field Sales Rep (`agent`):** `Home` · `My Map` · `My List` · `Route`.
    - **Technician (`technician`):** `Home` · `Work Map` · `Repair Log`.
- **Page Shell & Whitespace Budget:**
  - Outer background: `t.canvasBg`.
  - Centered scrollable canvas (`SingleChildScrollView` with `RefreshIndicator` for pull-to-refresh):
    - `ConstrainedBox(constraints: BoxConstraints(maxWidth: 1360))` centered on wide desktop screens so cards never stretch across ultrawide monitors.
    - Page padding: `EdgeInsetsDirectional.symmetric(horizontal: isMobile ? t.spaceLg : t.spaceXl, vertical: t.spaceLg)`.
    - Vertical rhythm between major sections: `t.spaceXl` (`24px`).
    - Grid gutter between cards: `t.spaceLg` (`16px`).
  - **Clean Greeting Header (All Roles):**
    - Left: Role eyebrow (`t.eyebrow`, e.g., `EXECUTIVE OVERVIEW` / `BRANCH SUPERVISOR` / `MY FIELD DAY` / `MAINTENANCE QUEUE`) + Greeting title (`t.displayTitle`, e.g., `"Good morning, <FirstName>"`) + subtle context subtitle (`t.caption`, e.g., `"Cairo East Branch • Updated 2m ago"`).
    - Right: Compact `Last Synced` / `Refresh` `IconButton` (`44x44` touch target) + optional time/branch filter pill (Owner/Regional Manager).

---

### 9.2 Shared Card & Chart Primitives (Pure Flutter + `AppTokens`)

To ensure visual consistency and zero external chart package bloat, build these reusable primitives in `frontend/lib/widgets/dashboard_widgets.dart`:

1. **`DashboardCard`:**
   - Surface: `t.surfaceElevated`, `BorderRadius.circular(t.radiusLg)` (`16px`), `Border.all(color: t.borderSubtle, width: t.borderWidth)`.
   - Padding: `EdgeInsets.all(t.spaceLg)` (`16px` mobile) or `EdgeInsets.all(20)` (desktop).
   - Subtle elevation only in Light mode (`BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: Offset(0, 4))`); flat crisp border in Dark & Outdoor modes.
2. **`HeroKpiCard`:**
   - Top row: `t.eyebrow` uppercase label (e.g., `TOTAL ASSETS`) + `32x32` tinted icon well (`accent.withValues(alpha: 0.14)`, `radiusSm`).
   - Middle: Large tabular figure (`28px`, `FontWeight.w700`, `FontFeature.tabularFigures()`, `t.textPrimary`) wrapped in `Directionality(textDirection: TextDirection.ltr)` for RTL safety.
   - Bottom row: Delta/context pill (`+4.2% vs last mo` in `t.success`, or `12 critical` in `t.danger`) + `t.caption` helper text.
   - Optional `onTap` with `InkWell(borderRadius: BorderRadius.circular(t.radiusLg))` to jump directly to the filtered Map/Table view.
3. **`ProgressRingPainter` (`CustomPainter`):**
   - Smooth rounded-cap arc (`StrokeCap.round`, `strokeWidth: 8–10px`), track in `t.borderSubtle`, active sweep in `t.accentPrimary` or `t.success`, centered `%` in `t.metricNum`.
4. **`MiniBarChart` & `DonutChartPainter` (`CustomPainter`):**
   - Pure `CustomPainter` + `MouseRegion` / `Tooltip` for hover/tap inspection on web & mobile.

---

### 9.3 Role 1: Owner / Regional Manager (`owner` / `regional_manager` / `admin`)

**Mental Model:** *"How is the business performing across branches, where is revenue or asset health slipping, and which chillers need attention?"*

#### Layout Grid
- **Row 1 — 4 Hero KPI Cards:**
  - Desktop (`>= 1100px`): 4 equal columns (`Row` / `GridView` with `16px` gap).
  - Tablet (`768px–1099px`): 2×2 grid.
  - Mobile (`< 768px`): 2×2 compact grid (`12px` gap).
  1. **Total Assets:** Count of chillers in scope (`t.accentPrimary`, `Icons.ac_unit_rounded`). Subtitle: `"Across X branches"`.
  2. **YTD Achievement %:** Mean YTD achievement (`t.achievement`, `Icons.trending_up_rounded`), formatted `XX.X%` (`N/A` if no numeric data). Delta pill vs target (`>= 85%` green, `65–84%` amber, `< 65%` red).
  3. **Active Visit Rate:** `Visited / Total` % (`t.success`, `Icons.verified_outlined`), e.g., `68.4%` with subtitle `"342 of 500 visited"`.
  4. **Maintenance Alerts:** Count of `Requires Maintenance` + `Scrap` (`t.warning` / `t.danger`, `Icons.build_circle_outlined`). Tapping opens `MapViewScreen` pre-filtered to Maintenance + Scrap.

- **Row 2 — Visual Analytics (2-Column Asymmetric Split on Desktop `>= 900px`: 7/12 Left, 5/12 Right; Stacked on Mobile):**
  - **Left Card: Branch Performance Bar Chart**
    - Header: `Branch Performance` + segmented toggle (`YTD Ach %` | `Visit Rate %`).
    - Visual: Horizontal or vertical animated rounded bars (`8px` radius) per branch, sorted highest-to-lowest (max 8 visible with `"View all branches"` expander).
    - Bar coloring by threshold: `>= 85%` `t.success`, `65–84%` `t.accentPrimary`, `< 65%` `t.warning`.
    - Interactive: Tapping any branch bar filters the Dashboard (or drills into `MapViewScreen` for that branch) and highlights the selected bar with a `1.5px` `t.accentPrimary` outline.
  - **Right Card: Condition & Efficiency Breakdown**
    - Header: `Fleet Health Breakdown` + segmented tab (`Condition` | `Efficiency`).
    - Visual: `140x140` **`DonutChartPainter`** on the left (or top on narrow mobile) with center total count, paired with a clean 3–4 row interactive legend on the right:
      - *Condition mode:* `Operational` (`t.success`), `Requires Maintenance` (`t.warning`), `Scrap` (`t.danger`), `Unspecified` (`t.textMuted`).
      - *Efficiency mode:* `Performing` (`t.success`), `Non-Performing` (`t.danger`), `Zero` (`t.textMuted`).
    - Below donut: Slim `8px` stacked proportional bar for instant visual ratio scanning.

- **Row 3 — Top / At-Risk Chillers Card (Full Width):**
  - Header: `Chiller Watchlist` + segmented pill toggle (`At-Risk` [default] | `Top Performing`).
  - **At-Risk Criteria:** `Scrap` / `Requires Maintenance` condition, `Non-Performing` / `Zero` efficiency, or `> 20%` MoM invoice drop.
  - **Top Performing Criteria:** Highest YTD Achievement % & `Operational` + `Performing`.
  - **List Items (max 5 rows, clean 1-line-per-attribute density):**
    - Left: Semantic status dot (`10px`) + `Customer Name` (`t.cardTitle`) & `Chiller Code • Branch` (`t.caption`).
    - Middle: Risk/Performance badge (`_buildBadge` style using `t.danger` / `t.warning` / `t.success`) + YTD Ach % (`t.metricNum`).
    - Right: Compact `"360° →"` ghost button (`TextButton`) opening [`showCustomer360Drawer`](file:///c:/Users/skamal/Documents/antigravity/gallant-maxwell/frontend/lib/views/customer_360_drawer.dart#L9-L15).

---

### 9.4 Role 2: Supervisor (`supervisor`)

**Mental Model:** *"Which audits need my sign-off right now, how is each rep on my team progressing today, and do I need to rebalance territories?"*

#### Layout Grid
- **Row 1 — Branch KPI Strip (4 compact cards, 4-col desktop / 2×2 mobile):**
  1. **Branch Assets** (`t.accentPrimary`)
  2. **Branch Visit Rate %** (`t.success`)
  3. **Pending Audit Reviews** (`t.warning` — pulses subtly if `> 0`)
  4. **Branch Maint. Alerts** (`t.danger`)

- **Row 2 — Primary Workspace (2-Column Split on Desktop `>= 900px`: 6/12 Left, 6/12 Right; Stacked on Mobile):**
  - **Left Card: Pending Audit Reviews Queue**
    - Header: `Pending Audit Reviews` + count pill (`t.warning`) + `"View All"` link to `FormResponsesViewScreen`.
    - Each queue card (`t.canvasBg` inner container, `radiusMd`, `padding: 12px`, `borderSubtle`):
      - **Top row:** `Customer Name` (`t.cardTitle`) + `Chiller Code` (`t.caption`) + relative timestamp (`"14m ago"`).
      - **Meta row:** Rep name chip + Condition badge + thumbnail strip (up to 3 `40x40` rounded-6 audit photos, tap to open lightbox).
      - **1-Click Action Row:**
        - **`Approve`** (`FilledButton`, `t.success` background, `Icons.check_rounded`, `minHeight: 40`) — immediately marks audit `Accepted` with optimistic UI update + `AppToast` undo/confirmation.
        - **`Flag`** (`OutlinedButton`, `t.warning` border/text, `Icons.flag_outlined`, `minHeight: 40`) — opens a compact 1-field inline/modal reason prompt (`"What needs correction?"`) and marks audit `Re-opened`.
        - **`360°`** (`IconButton`, `44x44` touch target) — opens Customer 360 Drawer.
  - **Right Card: Team Rep Progress Bars + Quick Territory Rebalance CTA**
    - Header: `Team Rep Progress` + subtitle `"Today / Current Cycle"`.
    - **Rep Rows (sorted by lowest completion % first so laggards surface):**
      - Top line: Rep Avatar (`28x28` initials circle) + `Rep Name` (`t.cardTitle`) + `Visited / Assigned` (`"12 / 20"`, `t.metricNum`) + `%` pill.
      - Progress bar: `8px` rounded track (`t.borderSubtle`) + animated fill (`t.success` if `>= 80%`, `t.accentPrimary` if `40–79%`, `t.warning` if `< 40%`).
      - Bottom caption: `"Avg Ach: 82.4% • 2 Re-opened"` (`t.caption`).
    - **Card Footer — Quick Territory Rebalance CTA:**
      - Full-width `OutlinedButton.icon` (`Icons.swap_horiz_rounded`, `t.accentPrimary`, `minHeight: 44`): **`Rebalance Territories`** → Navigates directly to `AssignLocationsViewScreen` pre-filtered to the supervisor's branch.

---

### 9.5 Role 3: Field Sales Rep (`agent`)

**Mental Model:** *"What do I need to do today, where is my next stop, and how fast can I start my route or log a visit?"*

#### Layout Grid (Single-Column Focused Flow on Mobile; 2-Column Split on Desktop `>= 900px`)
- **Top — Clean "My Day" Hero Card (Full Width, `t.surfaceElevated` with subtle `t.accentPrimary` top/start accent):**
  - **Left / Top Cluster:**
    - Eyebrow: `MY FIELD DAY` (`t.eyebrow`) + Territory/Branch pill (`t.caption`).
    - **3 Clean Stat Counters:** `Assigned` (`t.accentPrimary`), `Visited Today` (`t.success`), `Pending` (`t.warning`).
  - **Center — Completion Ring (`96x96` `ProgressRingPainter`):**
    - Shows `XX%` completion in bold `20px` `t.metricNum` + `"Done"` caption.
  - **Right / Bottom — Next Stop Callout + 1-Tap Primary CTAs:**
    - Mini `Next Stop` well (`t.canvasBg`, `radiusMd`, `padding: 12px`):
      - `"NEXT STOP • 1.4 km away"` (`t.eyebrow`)
      - `Customer Name` (`t.cardTitle`, 1 line ellipsis) + `Chiller Code • Condition` (`t.caption`).
    - **Dual 1-Tap Action Row (`minHeight: 48px` outdoor-friendly touch targets):**
      1. **`Start Route`** (`FilledButton.icon`, `#4285F4` Maps Blue or `t.accentPrimary`, `Icons.route_rounded`) — Jumps to `MapViewScreen` with Smart Daily Route Mode (`STORY-005`) active.
      2. **`Log Visit`** (`FilledButton.icon`, `t.success`, `Icons.edit_note_rounded`) — Opens `FormFillerDialog` directly for the Next Stop (or opens quick stop picker if Next Stop is already visited).

- **Below — Priority Action List (`DashboardCard`):**
  - Header: `Priority Stops` + quick filter pills (`All` | `Re-opened` | `Overdue` | `High Value`).
  - **Ordered Stop Cards (max 8 shown + `"View Full List"` link to `My List`):**
    - Left: Priority indicator bar (`4px` `BorderDirectional.start`):
      - `Re-opened` (`t.warning`) — displays admin feedback snippet inline!
      - `Maintenance / Scrap` (`t.danger`)
      - `High-Value / MoM Drop` (`t.accentPrimary`)
      - `Overdue / Unvisited` (`t.caution`)
    - Center: `Customer Name` (`t.cardTitle`), `Chiller Code • Distance (e.g. 1.2 km)` (`t.caption`), Priority badge.
    - Right: Compact `Log` button (`44x44` min touch target) + `Navigate` icon (`Icons.navigation_rounded`, `#4285F4`) + tap card to open `Customer360Drawer`.

---

### 9.6 Role 4: Technician (`technician`)

**Mental Model:** *"Which chillers are broken or need maintenance right now, how do I drive to them, and how do I mark them operational after repair?"*

#### Layout Grid
- **Row 1 — Compact Work Summary Strip (3 KPI pills/cards):**
  1. **Critical / Scrap** (`t.danger`, `Icons.dangerous_outlined`)
  2. **Requires Maintenance** (`t.warning`, `Icons.build_circle_outlined`)
  3. **Repaired This Week** (`t.success`, `Icons.check_circle_outline`)

- **Row 2 — Maintenance & Scrap Work Queue (Grouped by Urgency):**
  - Clean filter/jump tabs at top of queue: `All Open (X)` · `Critical / Scrap` · `Requires Maint.` · `Recently Serviced`.
  - **Urgency Group Headers:**
    - Group 1: **`CRITICAL — SCRAP / DOWN`** (`t.danger` eyebrow + count badge).
    - Group 2: **`URGENT — REQUIRES MAINTENANCE`** (`t.warning` eyebrow + count badge).
    - Group 3: **`RECENTLY SERVICED`** (`t.success` eyebrow, collapsed by default).
  - **Technician Work Card (`t.surfaceElevated`, `radiusMd`, `1px` `borderSubtle`, `4px` `BorderDirectional.start` in urgency color):**
    - **Left:** `Customer Name` (`t.cardTitle`) + `Chiller Code • Branch • Serial ID` (`t.caption`) + Last reported issue/audit note (`t.bodyDefault`, max 2 lines).
    - **Meta Badges:** Condition pill (`Scrap` / `Requires Maintenance`), Distance from live GPS (`2.8 km`), Days since flagged (`"Flagged 3d ago"`).
    - **Right / Bottom Action Bar (`minHeight: 44px` buttons):**
      1. **`Mark Operational / Log Repair`** (`FilledButton.icon`, `t.success`, `Icons.build_rounded`) — Opens a streamlined **Repair Log Modal** (status toggle: `Operational` / `Requires Follow-up` / `Confirm Scrap` + repair notes + optional photo upload) with 1-tap submit and `AppToast` feedback.
      2. **`Navigate`** (`OutlinedButton.icon`, `#4285F4`, `Icons.directions_rounded`) — Deep-links directly to Google Maps driving directions (`lat,lng`).
      3. **`360°`** (`IconButton`, `44x44`) — Opens Customer 360 Drawer for full chiller history & past audit photos.

---

### 9.7 Loading, Empty, Error, Accessibility & RTL States

| State | Behavior in `DashboardViewScreen` |
| :--- | :--- |
| **Initial Loading** | Render role-matching **`AppSkeleton`** layout (4 KPI card skeletons `110px` tall + 2 chart/list card skeletons `240px` tall) so layout never jumps. |
| **Pull-to-Refresh / Syncing** | Keep existing KPIs & cards visible; show thin `2px` `LinearProgressIndicator` (`t.accentPrimary`) at top of body. |
| **Empty (No Data Uploaded)** | Render **`AppEmptyState`** with role-appropriate CTA: Owner/Admin → `"Upload Master Excel"` (navigates to Upload tab); Agent/Tech/Supervisor → `"No chillers assigned to your scope yet. Contact your administrator."` |
| **Empty (Queue Clear — e.g. 0 Pending Reviews or 0 Maintenance Alerts)** | Positive celebratory micro-card (`t.success.withValues(alpha: 0.10)`): `"All caught up! No pending reviews / maintenance alerts."` |
| **API Error** | Non-blocking top inline banner (`t.danger` left accent, `Icons.error_outline`) with `"Retry"` button; preserve cached dashboard data if available. |
| **Accessibility (WCAG AA)** | All interactive cards, KPI tiles, and buttons use `Semantics(button: true, label: '...')` and `>= 44x44` touch targets. Chart bars & donut segments include `Tooltip` + text legend (never color-only). |
| **Arabic RTL (`Locale('ar')`)** | Use `EdgeInsetsDirectional`, `BorderDirectional`, `AlignmentDirectional`; wrap all numeric KPIs, percentages, and Chiller Codes in `Directionality(textDirection: TextDirection.ltr)` so `-12.4%` and `CH-1042` never reverse. |

---

### 9.8 Acceptance Checklist for `DashboardViewScreen`

- [ ] `DashboardViewScreen` is Tab `0` (`Home`) on both Desktop `NavigationRail` and Mobile `NavigationBar` for all roles (`owner`, `regional_manager`, `admin`, `supervisor`, `agent`, `technician`).
- [ ] Zero hardcoded hex colors (`0xFF...`) — 100% `AppTokens.of(context)` compliant across **Dark**, **Light**, and **Outdoor Field Contrast** modes.
- [ ] Owner/Regional Manager sees 4 Hero KPIs, Branch Performance Bar Chart, Condition/Efficiency Donut + Stacked Bar, and Top/At-Risk Chillers watchlist.
- [ ] Supervisor sees Branch KPI strip, 1-click Approve/Flag Pending Audit Reviews Queue, Team Rep Progress Bars, and Rebalance Territories CTA.
- [ ] Field Sales Rep sees "My Day" Hero Card with Completion Ring + Next Stop, Priority Action List, and 1-tap `Start Route` + `Log Visit`.
- [ ] Technician sees Maintenance & Scrap Work Queue grouped by urgency, 1-tap `Mark Operational / Log Repair`, and Google Maps `Navigate` button.
- [ ] Responsive verified at `375px` (mobile), `768px` (tablet), and `1280px+` (desktop) with zero horizontal overflow.
