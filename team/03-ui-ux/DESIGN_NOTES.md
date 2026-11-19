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

---

## 10. P6 (`v2.7.0`) — Offline-First Field Resilience & Trust UI/UX Specs

**Scope:** Field-resilience & audit-trust enhancements across the global app shell (`main.dart`), `DashboardViewScreen`, `FormFillerDialog`, `AuditPhotoGallery`, `FormResponsesViewScreen`, and `Customer360Drawer`.  
**Theme Compliance:** All colors, surfaces, radii, and spacing MUST use `AppTokens.of(context)` (`frontend/lib/theme/app_tokens.dart`) so every component works seamlessly in **Dark**, **Light**, and **Outdoor Field Contrast** modes.

---

### 10.1 Offline Sync Status Bar & Outbox Queue (`OfflineSyncBanner` + `OutboxQueueSheet`)

**Goal:** Give field reps and technicians constant, zero-anxiety visibility into connectivity and locally queued audits without blocking form entry or cluttering the workspace.

#### A. Placement & Responsive Behavior
- **Desktop / Wide Web (`>= 768px`):** Compact, full-width slim status strip (`height: 36px`–`40px`) docked at the **top of the main content pane** (to the right of `NavigationRail`, above the active view body) in `main.dart`.
- **Mobile / Narrow Web (`< 768px`):** Slim floating/docked bar (`minHeight: 40px`) positioned **directly above `NavigationBar`** (`bottomNavigationBar` slot or `Column` footer above `NavigationBar`) so it sits comfortably in thumb reach and never covers top headers or dialog actions.
- **Auto-Hide When Healthy:** When **Online** and **Outbox Queue == 0**, the bar collapses to `height: 0` (no wasted vertical space). Exception: immediately after a sync finishes, show a transient `"All audits synced ✓"` (`t.success`) confirmation strip for `3 seconds` before collapsing.

#### B. Visual States & Token Mapping
| State | Surface / Fill | Border & Left Accent | Icon | Copy | Primary CTA / Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Online (Queue Empty)** | Collapsed (`0px`) — or transient `t.success.withValues(alpha: 0.14)` for 3s | `1px` `t.success` (`0.45`) | `Icons.cloud_done_rounded` (`t.success`) | `"Online · All audits synced"` | None (auto-collapses) |
| **Offline (0 Queued)** | `t.surfaceElevated` | `1px` `t.borderSubtle`, `3px` start accent `t.caution` | `Icons.cloud_off_rounded` (`t.caution`) | `"Offline — Visits will save to device queue"` | None |
| **Offline (`N` Queued)** | `t.caution.withValues(alpha: 0.14)` | `1px` `t.caution` (`0.50`) | `Icons.cloud_off_rounded` (`t.caution`) | `"Offline — N queued audit(s)"` | `"View Queue"` (`TextButton`) |
| **Online (`N` Queued — Ready)** | `t.accentPrimary.withValues(alpha: 0.14)` | `1px` `t.accentPrimary` (`0.50`) | `Icons.cloud_upload_outlined` (`t.accentPrimary`) | `"Online — N queued audit(s) ready"` | **`"Sync Now"`** (`FilledButton` / compact pill, `minHeight: 32px`) + `"View"` |
| **Syncing (`i` of `N`)** | `t.surfaceElevated` + `2px` `LinearProgressIndicator` (`t.accentPrimary`) at bottom edge | `1px` `t.accentPrimary` (`0.40`) | `SizedBox(14, 14, child: CircularProgressIndicator)` | `"Syncing audit i of N..."` | Disabled `"Syncing..."` |
| **Sync Error / Conflict (`K` Failed)** | `t.danger.withValues(alpha: 0.14)` | `1px` `t.danger` (`0.55`) | `Icons.sync_problem_rounded` (`t.danger`) | `"Sync paused — K audit(s) need attention"` | **`"Resolve / Retry"`** (`OutlinedButton`, `t.danger`) |

#### C. Outbox Queue Sheet / Dialog (`OutboxQueueSheet`)
Triggered by tapping `"View Queue"`, `"View"`, or `"Resolve / Retry"`:
- **Container:** `ModalBottomSheet` (`DraggableScrollableSheet`, `initialChildSize: 0.65`, `maxChildSize: 0.90`) on mobile (`< 768px`); `AlertDialog` (`width: 520px`, `maxHeight: 560px`) on desktop (`>= 768px`).
- **Header:** `"Offline Outbox Queue (N)"` + `"Sync All"` primary button (enabled when Online & `N > 0`).
- **Queue Item Card (`t.canvasBg`, `t.radiusMd`, `1px` `t.borderSubtle`, `padding: 12px`):**
  - **Top Row:** `Customer Name` (`14px` bold `t.textPrimary`) + `Chiller Code` (`t.caption`, `Directionality.ltr`) + Status Pill:
    - `Queued` (`t.caution`, `Icons.schedule_rounded`)
    - `Syncing` (`t.accentPrimary`, spinner)
    - `Retry Needed` (`t.warning`, `Icons.refresh_rounded` — shows brief error reason, e.g. `"Timeout — tap Retry"`)
    - `Conflict` (`t.danger`, `Icons.warning_amber_rounded` — e.g. `"Server has a newer review for this visit"`)
  - **Meta Row:** Captured timestamp (`YYYY-MM-DD HH:mm`, `Directionality.ltr`), attached photo count (`"2 photos"`), and Geofence badge (`Within 100m ✓` or `Xm away`).
  - **Item Actions (`minHeight: 40px`):**
    - On `Retry Needed`: **`"Retry"`** (`t.accentPrimary`) + `"Discard"` (`t.danger` text button with confirm dialog).
    - On `Conflict`: **`"Keep Mine (Resubmit)"`** + **`"Discard Local"`**.
- **Empty State:** `AppEmptyState` with `Icons.cloud_done_outlined` (`t.success`): `"Outbox is empty — all field audits are synced."`

---

### 10.2 100m GPS Geofence Check-In Pill (`GeofenceCheckInPill`)

**Goal:** Provide instant, transparent GPS proximity verification at the moment of visit logging and in the daily stop queue, reinforcing field audit trust without hard-blocking reps when GPS drifts indoors.

#### A. Target Locations
1. **`FormFillerDialog` (`frontend/lib/views/form_filler_dialog.dart`):**
   - Placed in the dialog header/sub-header strip directly below `$customerName ($chillerCode)` (and above the form selector / re-opened admin feedback banner).
   - Always visible while filling the form; updates live if GPS improves, and records the final distance + coordinates on submit.
2. **`DashboardViewScreen` (`frontend/lib/views/dashboard_view.dart`):**
   - **Field Sales Rep `"My Day"` Hero Card:** Inside the `"NEXT STOP"` well (`t.canvasBg`) next to the `"NEXT STOP • 1.4 km away"` eyebrow.
   - **Priority Stop Cards & Technician Work Cards:** Inline in the card's meta badge row alongside the Condition pill (when live GPS is available).

#### B. Pill States & Visual Tokens
Use the shared pill pattern (`BorderRadius.circular(t.radiusPill)`, `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)`, `1px` border, `11.5px` bold text):

| State | Condition | Fill | Border | Icon (`14px`) | Label (with `Directionality.ltr` on distance) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Within Geofence** | `distanceMeters <= 100` | `t.success.withValues(alpha: 0.14)` | `t.success.withValues(alpha: 0.50)` | `Icons.verified_user_rounded` (`t.success`) | `"Within 100m ✓"` (optional tooltip: `"Live GPS: 42m from pin"`) |
| **Outside Geofence** | `distanceMeters > 100` | `t.caution.withValues(alpha: 0.14)` | `t.caution.withValues(alpha: 0.50)` | `Icons.warning_amber_rounded` (`t.caution`) | `"Outside Geofence — 240m"` (or `"Outside Geofence — 1.4 km"` when `>= 1000m`) |
| **Locating GPS** | Initial acquisition (`< 5s`) | `t.accentPrimary.withValues(alpha: 0.12)` | `t.accentPrimary.withValues(alpha: 0.40)` | `12x12` `CircularProgressIndicator` (`t.accentPrimary`) | `"Checking GPS..."` |
| **GPS Unavailable** | Denied / unsupported / timeout | `t.surfaceHeader` | `t.borderSubtle` | `Icons.location_disabled_rounded` (`t.textMuted`) | `"GPS Unavailable"` (+ `"Retry"` tap action inside `FormFillerDialog`) |

#### C. Non-Blocking Warning Banner in `FormFillerDialog`
- When `distanceMeters > 100`, show a compact, non-blocking inline helper line directly beneath the pill (`t.caution`, `11.5px`):
  - `"You are Xm from the registered chiller pin. You can still submit — distance is logged for supervisor review."`
- **No Hard Block:** Reps can still submit `FormFillerDialog` offline or outside `100m` (e.g., indoor signal drift or relocated chiller); the supervisor sees the logged distance badge in `FormResponsesViewScreen`.

---

### 10.3 Geo-Stamped Photo Watermark & 1-Click Audit PDF Export

#### A. Geo-Stamped Photo Watermark (`AuditPhotoGallery` & `_AuditPhotoLightbox`)
Target file: `frontend/lib/widgets/audit_photo_gallery.dart`.

1. **Thumbnail Grid (`AuditPhotoGallery`):**
   - **Top Row (Existing):** Keep `Photo N/M` pill (`top: 4, start: 4`) and GPS Verified `10x10` `t.success` dot (`top: 4, end: 4`). If `!photo.isGpsVerified`, render a `10x10` `t.caution` dot with `Tooltip(message: 'GPS Unverified')`.
   - **Bottom Geo-Stamp Watermark Strip:** Replace the flat single-line date bar (`bottom: 0, start: 0, end: 0`) with a subtle bottom gradient scrim (`LinearGradient` from `Colors.transparent` to `Colors.black.withValues(alpha: 0.82)`) containing **2 compact lines** wrapped in `Directionality(textDirection: TextDirection.ltr)`:
     - **Line 1 (`9.5px`, `Colors.white`, `FontWeight.w600`):** `${chillerCode ?? ''} · $shortDateTime` (e.g. `CH-1042 · 2026-11-19 14:32`).
     - **Line 2 (`9px`, `Colors.white70`):** If `photo.isGpsVerified`: `"📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}"`; else `"📍 GPS Unverified"` in `t.caution`.

2. **Fullscreen Lightbox (`_AuditPhotoLightbox`):**
   - **Bottom Watermark Metadata Card:** Docked at `bottom: 16, start: 16, end: 16` above the safe area, styled with `Colors.black.withValues(alpha: 0.76)`, `BorderRadius.circular(t.radiusMd)`, `1px` `Colors.white24` border, `padding: 12px`:
     - **Left Column (`Directionality.ltr` for codes/coords/dates):**
       - Row 1: `Chiller Code` (`13px` bold white) + `Condition` badge + `Geofence` pill (`Within 100m ✓` or `Xm away` if available).
       - Row 2: `"🕒 YYYY-MM-DD HH:mm  ·  👤 Agent Name"` (`12px` `Colors.white70`).
       - Row 3: `"📍 30.044412, 31.235708"` (`12px` monospace/tabular `t.accentPrimary` or `"📍 GPS coordinates not captured"` in `t.caution`).
     - **Right Actions:** Compact `"Open in Maps"` (`Icons.open_in_new_rounded`, `44x44` touch target) when `photo.isGpsVerified`.

#### B. 1-Click `"Export Visual Audit PDF"` CTA (`FormResponsesViewScreen` & `Customer360Drawer`)

1. **Placement in `FormResponsesViewScreen` (`frontend/lib/views/form_responses_view.dart`):**
   - **Response Card (List View):** Add a compact `IconButton` (`Icons.picture_as_pdf_outlined`, `t.accentPrimary`, `tooltip: 'Export Visual Audit PDF'`, `44x44` min touch target) in the card header/action row so supervisors can export in 1 click without opening the modal.
   - **Visit Response Detail Dialog (`actions` row):** Add an `OutlinedButton.icon` **to the left of `Re-open to Agent` / `Accept & Verify`**:
     - Icon: `Icons.picture_as_pdf_outlined` (`16px`)
     - Label: `"Export Visual Audit PDF"`
     - Style: `foregroundColor: t.accentPrimary`, `side: BorderSide(color: t.accentPrimary.withValues(alpha: 0.6))`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusSm))`.

2. **Placement in `Customer360Drawer` (`frontend/lib/views/customer_360_drawer.dart`):**
   - **Recent Visit Audit History Section Header:** Add a right-aligned compact `OutlinedButton.icon` / `TextButton.icon` (`"Export Visual Audit PDF"`, `Icons.picture_as_pdf_outlined`, `t.accentPrimary`, `minHeight: 36px`) visible whenever `visitHistory.isNotEmpty`. Clicking it exports the most recent audit (or lets the user click the per-audit PDF icon on any historical visit card).
   - **Per-Visit History Card:** Add a compact `44x44` `IconButton` (`Icons.picture_as_pdf_outlined`, `tooltip: 'Export Visual Audit PDF'`) on each audit entry header.

3. **Export Button Interaction States:**
   | State | Visual Behavior | Feedback |
   | :--- | :--- | :--- |
   | **Idle** | Enabled button with `Icons.picture_as_pdf_outlined` | Tooltip: `"Download PDF with geo-stamped photos"` |
   | **Generating** | Button disabled; icon replaced with `14x14` `CircularProgressIndicator(strokeWidth: 2)` + label `"Generating PDF..."` | Prevents duplicate requests |
   | **Success** | Returns to Idle; triggers browser download / share sheet (`Audit_${chillerCode}_${date}.pdf`) | `AppToast.show(context, type: AppToastType.success, message: 'Visual Audit PDF exported.')` |
   | **Error** | Returns to Idle | `AppToast.show(context, type: AppToastType.error, message: 'PDF export failed.', actionLabel: 'Retry', onAction: ...)` |

4. **Visual Audit PDF Document Layout Spec (A4 Portrait):**
   - **Header Band:** Platform title (`Bassem Sales Platform — Visual Visit Audit`), Export Timestamp, Audit Status badge (`VERIFIED` / `SUBMITTED` / `RE-OPENED`).
   - **Site & Check-In Summary Box:** Customer Name, Chiller Code, Branch, Assigned Rep, Visit Timestamp, and **GPS Check-In Verification** (`Within 100m ✓` or `Outside Geofence — Xm` + Lat/Lng).
   - **Audit Form Responses Table:** 2-column zebra-striped table (`Question / Field` | `Recorded Answer`).
   - **Geo-Stamped Photo Evidence Grid:** 2-column photo grid; every image includes a **burned-in bottom watermark bar** (`Chiller Code · Timestamp · Lat, Lng · Agent Name`) directly on/below the frame so exported PDFs remain tamper-evident when shared externally via WhatsApp or email.

---

### 10.4 P6 Accessibility, RTL & Acceptance Checklist

- **Arabic RTL (`Locale('ar')`):** Use `PositionedDirectional`, `EdgeInsetsDirectional`, and `BorderDirectional` for all banners, pills, and photo overlays. Wrap all numeric distances (`84m`, `1.4 km`), timestamps (`2026-11-19 14:32`), Chiller Codes (`CH-1042`), and GPS coordinates (`30.0444, 31.2357`) in `Directionality(textDirection: TextDirection.ltr)`.
- **WCAG AA & Touch Targets:** All interactive pills/buttons (`Sync Now`, `View Queue`, `Retry`, `Export Visual Audit PDF`, `Open in Maps`) must have `>= 44x44` hit targets (or `36px` visual height with `MaterialTapTargetSize.padded`) and descriptive `Semantics(button: true, label: '...')`.
- **Checklist:**
  - [ ] `OfflineSyncBanner` & `OutboxQueueSheet` implemented in `main.dart` shell using `AppTokens.of(context)` (auto-hides when online & queue empty; supports `Sync Now`, `Retry`, and `Conflict` resolution).
  - [ ] `GeofenceCheckInPill` displays live `Within 100m ✓` (`t.success`) vs `Outside Geofence — Xm` (`t.caution`) in `FormFillerDialog` (with non-blocking helper note) and `DashboardViewScreen`.
  - [ ] `AuditPhotoGallery` & `_AuditPhotoLightbox` render the 2-line / full geo-stamped watermark overlay (`Chiller Code`, `Timestamp`, `Lat/Lng`, `Agent Name`).
  - [ ] `"Export Visual Audit PDF"` CTA available in both `FormResponsesViewScreen` (list card + detail dialog) and `Customer360Drawer` (audit history header + per-visit card) with Loading/Success/Error `AppToast` states.

---

## 11. Next-Level BI & Cross-Filtering Control Tower UI/UX (Sprint 12 / `v4.0-alpha`)

> **Scope & Alignment:** Translates `VISION_AND_ROADMAP.md` §8 (`v4.0` 360° Enterprise Command Center) into concrete Flutter Web & Mobile UI/UX specs for `DashboardViewScreen` (`frontend/lib/views/dashboard_view.dart`) and `dashboard_widgets.dart`, built 100% on `AppTokens` and pure Flutter `CustomPainter` (zero external chart dependencies).

### 11.1 Cross-Filter Pill Bar & "Drill-Anywhere" Interaction Model

Currently, `DashboardViewScreen` only supports a single `_selectedBranch` filter on `MiniBarChart` (`_buildBranchPerformanceCard`). Sprint 12 upgrades this to a **multi-dimensional bidirectional cross-filter state** (`DashboardCrossFilter`) where clicking any visual element filters **all** dashboard widgets in real time.

#### A. Filterable Dimensions & Interactive Triggers
| Dimension | Trigger Widget in `DashboardViewScreen` | Visual Selection Cue |
| :--- | :--- | :--- |
| **Branch** | Any bar row in `MiniBarChart` (`_buildBranchPerformanceCard`) | Active row gets `t.accentPrimary.withValues(alpha: 0.08)` fill + `1.5px` `t.accentPrimary` border; unselected bars dim to `0.45` opacity |
| **District** | Any territory row in `_buildDistrictRollupsCard` | Active row gets `t.accentPrimary.withValues(alpha: 0.10)` fill + `1.5px` `t.accentPrimary` border + trailing `Icons.filter_alt` (`14px`) |
| **Condition** | Any donut slice **or** legend row in `_buildFleetHealthCard` (`_healthMode == 0`: `Operational`, `Requires Maint.`, `Scrap`) | Selected slice expands strokeWidth (`18px -> 22px`) with `2px` `t.textPrimary` outer halo; unselected slices dim to `0.35` alpha; matching legend row highlights |
| **Efficiency** | Any donut slice **or** legend row in `_buildFleetHealthCard` (`_healthMode == 1`: `Performing`, `Underperforming`, `Critical`, `Other / N/A`) | Same donut halo + legend row highlight behavior; switching `_healthMode` preserves active filter in the pill bar |

- **Toggle & Multi-Select Rule:** Clicking an unselected item sets/adds that dimension predicate; clicking the **currently active** item toggles it off. Multiple dimensions stack with `AND` semantics (e.g., `Branch: Cairo` + `District: Nasr City` + `Condition: Requires Maint.`).
- **Donut Hit-Testing (`InteractiveDonutChart`):** Wrap `CustomPaint(painter: DonutChartPainter(...))` in `GestureDetector(onTapUp: ...)` using polar angle math (`atan2(dy, dx)`) against segment start/sweep angles, **plus** make every legend row an `InkWell` (`minHeight: 36px`) so keyboard, screen-reader, and mobile touch users never have to aim at thin donut arcs.

#### B. Sticky `CrossFilterPillBar` Layout & Tokens
- **Placement:** Rendered immediately below `_buildGreetingHeader` and above the `HeroKpiCard` grid. Auto-collapses (`AnimatedSize` + `AnimatedOpacity`, `180ms` `Curves.easeOut`) with **zero vertical footprint** when no filters are active.
- **Container:** `t.surfaceElevated` background, `1px` `t.borderSubtle` border, `t.radiusMd` (`12px`), `padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm)`.
- **Contents (Left to Right / `Wrap` on Mobile):**
  1. Leading label: `Icons.filter_list_rounded` (`16px`, `t.accentPrimary`) + `"Active Filters"` (`t.eyebrow`) + live matched count badge (`"42 / 320 assets"`, `t.caption` with `tabularFigures`).
  2. **Filter Chips (`InputChip` / custom pill):**
     - Format: `[Dimension]: [Value]` (e.g., `Branch: Giza`, `Condition: Scrap`).
     - Style: `t.accentPrimary.withValues(alpha: 0.14)` fill, `1px` `t.accentPrimary.withValues(alpha: 0.45)` border, `t.radiusPill`, `32px` visual height (`MaterialTapTargetSize.padded` for `>= 44px` touch target), trailing `Icons.close_rounded` (`14px`) to remove that single dimension.
  3. **Quick-Pivot & Clear Actions (Trailing):**
     - `"Open in Map"` (`TextButton.icon`, `Icons.map_outlined`, `16px`) — passes active `branch` / `condition` / `district` filters to `widget.onOpenMap`.
     - `"Open in Table"` (`TextButton.icon`, `Icons.table_chart_outlined`, `16px`) — passes active predicate to `DataTableViewScreen`.
     - **`"Clear All"`** (`TextButton`, `t.danger` foreground, `fontWeight: w600`) — 1-click reset of all active cross-filters, returning all widgets to full scope.

#### C. Loading, Empty & Error States for Cross-Filtering
- **Live Refreshing:** When a cross-filter changes, keep existing cards visible and show a `2px` `LinearProgressIndicator` (`t.accentPrimary`) along the top edge of `CrossFilterPillBar` (`_isRefreshing == true`) so the layout never jumps.
- **Zero-Match Empty State:** If stacked filters yield `0` matching chillers, show an inline `DashboardCard` empty banner below `CrossFilterPillBar`: `Icons.filter_alt_off_outlined` (`t.textMuted`), `"No chillers match the current filter combination."`, and a primary `"Clear All Filters"` button.

---

### 11.2 Period-over-Period Variance & 90-Day Forecast Card

Replaces static YTD-only visibility with forward-looking pace-to-goal intelligence inside `Executive` and `Commercial 360°` views (`DashboardCard`).

#### A. Header & `MoM | QoQ | YoY` Toggle
- **Left:** Eyebrow `"PACE & FORECAST"` (`t.eyebrow`) + Title `"Period Variance & 90-Day Projection"` (`t.sectionTitle`).
- **Right:** `SegmentedButton<String>` with segments `MoM` | `QoQ` | `YoY` (matching the compact `SegmentedButton` style in `_buildBranchPerformanceCard`).
- **Status Pill (Inline):** Projected finish badge based on 90-day run-rate vs. target:
  - `>= 95%`: `"On Track"` (`t.success`)
  - `80% – 94.9%`: `"At Risk"` (`t.caution`)
  - `< 80%`: `"Behind Pace"` (`t.danger`)

#### B. Period-over-Period Variance Strip & Waterfall Delta Indicators
On desktop (`>= 900px`), render a 3-part horizontal summary strip above the forecast chart (2x2 `Wrap` on mobile):
1. **Current Period Actual:** Large `tabularFigures` metric (`$1.42M` or `89.4%`) + delta pill (`▲ +12.4% vs. Prior MoM` in `t.success`, or `▼ -4.8%` in `t.danger`, or `● 0.0%` in `t.textMuted`).
2. **Mini Waterfall Bridge (`Prior` → `Drivers` → `Current`):** Compact 4-bar horizontal/stepped waterfall indicator (`CustomPainter` or proportional `Container` bars, `28px` height):
   - `Prior`: `t.textMuted`
   - `+ Expansion / New`: `t.success` (`+$210K`)
   - `- Contraction / Churn`: `t.danger` (`-$68K`)
   - `Current`: `t.accentPrimary` (`$1.42M`)
3. **90-Day Projected Finish:** Target `$1.80M` vs. Projected `$1.77M (98.3%)` with confidence range (`$1.69M – $1.85M`).

#### C. 90-Day Projected Attainment Line/Band Chart (`ForecastBandPainter` via `CustomPainter`)
Pure Flutter `CustomPainter` (`height: 210px` desktop, `180px` mobile) with zero external packages:
- **Grid & Axes:** Subtle horizontal dashed gridlines (`t.borderSubtle`, `1px`) at `0%`, `50%`, `100%` target, with `t.caption` `tabularFigures` Y-axis labels and X-axis month/week markers (`-90d`, `-60d`, `-30d`, `Today`, `+30d`, `+60d`, `+90d`).
- **Today Divider:** Vertical `1px` dashed line at `Today` with a `"TODAY"` micro-pill (`t.surfaceHeader` fill, `t.textSecondary` text).
- **Historical Actuals Line:** Solid `2.5px` smooth path in `t.accentPrimary`, with subtle gradient area fill (`t.accentPrimary.withValues(alpha: 0.14)` → `0.0`).
- **Target / Quota Line:** Horizontal or sloped `1.5px` dashed line in `t.textMuted` labeled `"Quota (100%)"`.
- **90-Day Confidence Band (`P10–P90`):** Shaded polygon from `Today` to `+90d` in `t.achievement.withValues(alpha: 0.14)` (or `t.success` / `t.caution` matching pace status).
- **Projected Run-Rate Line:** `2.5px` dashed line in `t.achievement` (with `4px` dot markers at `+30d`, `+60d`, `+90d`).
- **Interactive Scrub / Tap Tooltip:** `GestureDetector(onPanUpdate / onTapDown)` snaps to nearest data point, draws a vertical hairline + `5px` glowing node, and shows a compact floating card (`t.surfaceHeader`, `1px` `t.borderSubtle`) with `Period`, `Actual / Projected`, `Quota`, and `Confidence Band`.
- **Empty / Insufficient History State:** If `< 2` periods of historical data exist (e.g., filtered to a brand-new branch), render a muted baseline with centered message `"Need at least 2 billing periods to project 90-day run-rate."`

---

### 11.3 Management by Exception (EBM) Feed

Surfaces *only* high-impact anomalies requiring intervention, ranked by severity and financial/SLA impact, and automatically scoped by the active `CrossFilterPillBar`.

#### A. Card Header & Severity Filter Strip
- **Header:** Eyebrow `"EXCEPTION-BASED MANAGEMENT"` (`t.eyebrow`) + Title `"Actionable Exception Feed"` (`t.sectionTitle`) + live count badge.
- **Severity Filter Chips:** `All (12)` | `Critical (3)` | `Warning (5)` | `Watch (4)` using `FilterChip` / pill buttons with color-coded count dots.

#### B. Severity Tokens & Card Anatomy
Each exception item renders as a compact `DashboardCard` (or `t.canvasBg` inner tile with `1px` `t.borderSubtle` and a **`4px` directional start accent bar** via `BorderDirectional`):

| Severity | Accent Token | Icon | Example Triggers |
| :--- | :--- | :--- | :--- |
| **Critical** | `t.danger` (`#EF4444` dark) | `Icons.error_outline_rounded` | `>20% MoM revenue drop`, `SLA breached >48h`, `Ghost Chiller (Condition=Good, $0 YTD 60d)` |
| **Warning** | `t.warning` (`#F97316` dark) | `Icons.warning_amber_rounded` | `SLA >24h`, `Attainment 65–79%`, `2+ Re-opened Audits on same outlet` |
| **Watch** | `t.caution` (`#F59E0B` dark) | `Icons.visibility_outlined` | `Missing GPS / Incomplete Data`, `Near-target pace dip (-5% WoW)`, `Warranty expiring <30d` |

- **Exception Card Layout (2-row responsive structure):**
  - **Top Row:** Severity Pill (`CRITICAL` / `WARNING` / `WATCH`, `10px` uppercase bold) + Category Tag (`REVENUE DROP`, `SLA BREACH`, `GHOST ASSET`, `AUDIT QUALITY`) + Impact Metric (`-$14,200 MoM` or `52h overdue` in `t.metricNum`, `Directionality.ltr`) + Timestamp (`2h ago`).
  - **Middle Row:** Clear 1-line title (`"Al-Noor Hypermarket — 34% MoM Revenue Drop"`) + concise scope subtitle (`"Branch: Cairo • District: Nasr City • Chiller: CH-1042 • Rep: Ahmed Hassan"`).
  - **Action Row (Direct 1-Click Triggers, `Wrap` with `t.spaceSm`):**
    1. **`"Investigate 360°"`** (`FilledButton.tonalIcon` or `OutlinedButton.icon` with `t.accentPrimary`, `Icons.person_search_outlined`, `minHeight: 36px`) → Opens `Customer360Drawer` directly for that chiller/outlet (or applies `CrossFilterPillBar` if branch-level).
    2. **`"Assign"`** (`OutlinedButton.icon`, `Icons.assignment_ind_outlined`, `minHeight: 36px`) → Opens quick Rep/Technician assignment dialog pre-scoped to the outlet.
    3. **`"Create Ticket"`** (`OutlinedButton.icon`, `Icons.build_circle_outlined`, `minHeight: 36px`) → Opens pre-filled Maintenance/SLA Ticket dialog (`chillerCode`, `priority` mapped from severity, `issueSummary`).
- **Empty State (Zero Exceptions):** Positive reinforcement card with `Icons.check_circle_outline_rounded` (`t.success`), `"All clear — no active exceptions in this scope."`, and `"View Full Fleet"` secondary link.

---

### 11.4 360° Control Tower Navigation Preview (Clutter-Free Hierarchy)

Unifies **Executive**, **Commercial**, **Asset Lifecycle**, and **Workforce** analytics inside `DashboardViewScreen` without bloating the top-level `NavigationRail` or breaking the 5-item mobile `NavigationBar` cap.

#### A. Navigation Architecture (No Shell Bloat)
- **App Shell (`main.dart`) Stays Clean:** Keep existing top-level destinations (`Home / Control Tower`, `Map`, `Table`, `Responses`, `Assign`, etc.) unchanged.
- **In-Dashboard Control Tower Mode Switcher (`owner` / `regional_manager` / `supervisor`):**
  - Placed directly below `_buildGreetingHeader` (and above `CrossFilterPillBar`).
  - **Desktop (`>= 900px`):** Segmented pill strip (`t.surfaceElevated`, `1px` `t.borderSubtle`, `t.radiusPill`) with 4 tabs:
    1. `Executive` (`Icons.dashboard_rounded`) — Default landing view
    2. `Commercial 360°` (`Icons.trending_up_rounded`)
    3. `Asset Lifecycle 360°` (`Icons.ac_unit_rounded`)
    4. `Workforce 360°` (`Icons.groups_outlined`)
  - **Mobile (`< 768px`):** Horizontally scrollable `SingleChildScrollView` pill bar (`40px` pill height, `44px` tap target, `t.spaceSm` gap) so all 4 pillars remain 1 tap away without wrapping into 2 messy rows.
  - **Role Scoping:** `agent` and `technician` retain their focused `"My Day"` and `"Service Dispatch"` workspaces with zero Control Tower tab clutter.

#### B. Layout Hierarchy per Control Tower Pillar
1. **`Executive` (Command Overview — Sprint 12 Primary):**
   - `CrossFilterPillBar` (when active)
   - `4x` `HeroKpiCard` strip (`Total Assets`, `YTD Achievement`, `Active Visit Rate`, `Maint. Alerts`)
   - `Period Variance & 90-Day Forecast` card (`MoM | QoQ | YoY`)
   - 2-Column Analytical Split: `Branch Performance` (`MiniBarChart`) + `Fleet Health Breakdown` (`DonutChartPainter`)
   - `Management by Exception` ranked feed (`Critical | Warning | Watch`)
   - `Territory & District Rollups` + `Data Completeness`
2. **`Commercial 360°` (Revenue, Quota & Credit):**
   - Hero KPIs: `Primary vs. Secondary Sales`, `Quota Attainment %`, `Promo / Discount ROI`, `Credit Aging (DSO)`
   - `Period Variance & 90-Day Forecast` (Commercial slice) + `Branch/Rep Quota Leaderboard`
   - `Outlet Order & Credit Health` watchlist (`Credit-Hold NBA` badges; *Sprint 15 live data / Sprint 12–14 preview state with `Preview` pill*)
3. **`Asset Lifecycle 360°` (CALM: CapEx → TCO → Disposal):**
   - Hero KPIs: `Fleet CapEx / Net Book Value`, `Avg. Cost-to-Serve (TCO)`, `Sales-to-Cooler Lift ROI`, `Shrinkage / Ghost Assets`
   - `Executive ROI & ERP Sync` card + `Depreciation & Fleet Age` breakdown
   - `Relocation & Scrap Candidates` actionable table (*Sprint 14 full CALM ledger*)
4. **`Workforce 360°` (Reps, Techs, Coaching & Incentives):**
   - Hero KPIs: `Active Rep Coverage %`, `Audit Approval Rate`, `Perfect Chiller Compliance`, `Avg. Tech MTTR`
   - `Rep Gamification & Incentive Tier` leaderboard + `Technician SLA Queue` summary
   - `1:1 Supervisor Coaching Queue` (*Sprint 15 coaching logs*)

- **Progressive Disclosure Rule:** Any sub-card backed by an upcoming Sprint 13–15 endpoint displays a subtle `t.textMuted` `"Preview"` badge (`10px`) and renders realistic scoped summary placeholders or current partial metrics—never dead buttons or broken spinners.

---

### 11.5 Sprint 12 Accessibility, RTL & Acceptance Checklist

- **Arabic RTL (`Locale('ar')`):**
  - Use `BorderDirectional(start: BorderSide(color: severityColor, width: 4))` on Exception cards, `EdgeInsetsDirectional` on all filter chips and waterfall bars, and `Directionality(textDirection: TextDirection.ltr)` on all numeric deltas (`+12.4%`, `-$14,200`), chart axes, and chiller codes (`CH-1042`).
- **WCAG AA & Touch Targets:**
  - All `CrossFilterPillBar` chips, `Clear All`, `MoM | QoQ | YoY` segments, Exception action buttons (`Investigate 360°`, `Assign`, `Create Ticket`), and Control Tower pillar pills must meet `>= 44x44` effective touch targets (`MaterialTapTargetSize.padded`) and include descriptive `Semantics` labels.
- **Color-Blind Safe Indicators:**
  - Never rely on color alone: variance pills pair `▲ / ▼ / ●` icons with color; Exception cards pair severity icons + text labels (`CRITICAL`, `WARNING`, `WATCH`) with `t.danger / t.warning / t.caution`.
- **Acceptance Checklist:**
  - [ ] `CrossFilterPillBar` updates live when clicking any Branch bar, District row, Condition donut slice/legend, or Efficiency bucket/legend, with 1-click `"Clear All"` and `"Open in Map"` / `"Open in Table"` handoff.
  - [ ] `Period Variance & 90-Day Forecast` card renders `MoM | QoQ | YoY` toggle, waterfall delta bridge, and pure-Flutter `CustomPainter` (`ForecastBandPainter`) with confidence band + interactive tap/scrub tooltip.
  - [ ] `Management by Exception` feed renders `Critical | Warning | Watch` cards filtered by global `CrossFilterPillBar` with working `"Investigate 360°"`, `"Assign"`, and `"Create Ticket"` triggers.
  - [ ] Control Tower mode switcher (`Executive | Commercial 360° | Asset Lifecycle 360° | Workforce 360°`) renders cleanly on desktop and mobile (`<= 5` bottom nav items preserved in `main.dart`).


