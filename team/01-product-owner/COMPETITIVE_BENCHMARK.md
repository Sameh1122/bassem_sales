# Competitive Intelligence & Feature Benchmark Report

**Prepared By:** Product Owner (PO)  
**Baseline:** Bassem Sales Platform `v2.5.0` (Express API + Flutter Web + Vercel Blob)  
**Benchmark Date:** 2026-11-19  
**Reference:** [VISION_AND_ROADMAP.md](./VISION_AND_ROADMAP.md) | [../../docs/BRD.md](../../docs/BRD.md)

---

## 1. Executive Summary

To position **Bassem Sales Platform** as the **#1 FMCG Field Sales & Commercial Refrigeration Asset Intelligence Platform**, we benchmarked six market-leading FMCG / Retail Execution platforms:
1. **Salesforce Consumer Goods Cloud (CGC)** — Enterprise CRM-native retail execution powerhouse.
2. **Repsly** — Agile CPG retail execution & AI shelf-scanning leader.
3. **Ivy Mobility** — Purpose-built FMCG Route-to-Market (RTM) & cold-asset specialist.
4. **GoSpotCheck (by FORM)** — Mobile audit, visual reporting, and shelf-intelligence leader.
5. **Pitcher** — AI-driven guided selling & closed-loop omnichannel enablement.
6. **Pepperi** — Unified B2B commerce, DSD, and offline-first ERP-synced execution.

### Key Strategic Finding
> **Bassem Sales Platform `v2.5.0` already outperforms lightweight tools in *multi-batch spreadsheet delta auditing*, *36+ column commercial chiller financial tracking (Jan–Dec & YTD)*, and *zero-cost/fast deployment*.** However, to win against enterprise leaders (Ivy Mobility, Salesforce CGC, Repsly) and avoid churn, Bassem must close critical gaps in **Offline Mobile UX**, **Smart Route Sequencing**, **AI Chiller/Photo Auditing**, **Guided Selling**, and **Automated ERP/Alerting Loops**.

---

## 2. Competitor Profiles & Standout Capabilities

| Platform | Target Segment | Core Positioning | Standout Differentiators | Key Limitations / Friction |
| :--- | :--- | :--- | :--- | :--- |
| **Salesforce CG Cloud** | Large Enterprise CPG | End-to-end retail execution inside Salesforce CRM | Offline-first mobile sync; **Einstein Vision** offline AI shelf/cooler audit with AR overlays; traffic-aware route optimization; mobile order capture. | High TCO & licensing cost; heavy 6–12 month implementation; overkill for mid-market distributors. |
| **Repsly** | Mid-Market & Enterprise CPG | Store-level retail execution & merchandising | **ShelfScan** AI (>95% accuracy, 50% faster audits, image-to-order); Territory Advisor; GPS-verified check-ins; actionable KPI scorecards. | Less focused on deep commercial chiller financial ROI (Jan–Dec asset depreciation/recovery). |
| **Ivy Mobility** | Global FMCG & Beverage/Dairy | Cloud RTM, SFA, DSD & Cold Asset Management | **Chiller/Cooler Lifecycle & Maintenance History**; **Ivy Eye** AI cooler purity & OOS; **Ivy Compass** AI routing; Perfect Store execution. | Complex enterprise suite; steep onboarding for distributors still running on Excel/CSV. |
| **GoSpotCheck (FORM)** | CPG, Beverage-Alcohol, Retail | Mobile task management & visual intelligence | **PhotoWorks** geo/time-stamped photo library (PDF/PPT export); AI SKU & POSM recognition; branching smart checklists; Looker BI. | No native gamification or deep ERP order-taking; requires external CRM/BI integrations. |
| **Pitcher** | Enterprise CPG & Life Sciences | AI-guided selling & omnichannel enablement | **Pitcher Intelligent Agent (PIA)** Next Best Action & pre-call coaching; dynamic personalized pitch decks; AR display preview; full offline mode. | Primarily a sales-enablement layer; relies on SAP/Salesforce/Oracle for core asset/ERP data. |
| **Pepperi** | Brand Manufacturers & Distributors | Unified B2B e-commerce, SFA & DSD | **True offline-first native mobile** (local DB queue); **Guided Selling** (cross-sell/upsell + trade promos); **Seamless ERP Sync** (SAP, NetSuite, Dynamics). | Less specialized in geospatial chiller fleet auditing and historical spreadsheet delta comparison. |
| **Bassem (`v2.5.0`)** | FMCG Distributors & Chiller Fleets | Geospatial Chiller Asset Intelligence & Field Audits | **36+ col Excel/CSV ingestion + DDE protection**; **Immutable Batch Delta Auditing**; **Strict Territory Isolation**; **Dynamic Map-Integrated Audit Forms**; **Fast, low-TCO stack**. | Web-only (no offline PWA queue yet); manual route ordering; no AI photo audit; no guided selling or ERP sync. |

---

## 3. Head-to-Head Capability Benchmark Matrix

**Rating Scale:** `★★★★★` Market Leader | `★★★★☆` Strong | `★★★☆☆` Capable / Basic | `★★☆☆☆` Partial / Manual | `★☆☆☆☆` Missing

| Capability Dimension | Bassem `v2.5.0` | Salesforce CGC | Repsly | Ivy Mobility | GoSpotCheck (FORM) | Pitcher | Pepperi |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Route Optimization** | ★★☆☆☆ *(Map + My Location)* | ★★★★★ *(Traffic + AI)* | ★★★★☆ *(Territory Advisor)* | ★★★★★ *(Ivy Compass AI)* | ★★☆☆☆ *(Task/Store list)* | ★★★☆☆ *(Visit planning)* | ★★★☆☆ *(Route scheduling)* |
| **2. Offline Mobile UX** | ★☆☆☆☆ *(Online Flutter Web)* | ★★★★★ *(Full offline + sync)* | ★★★★☆ *(Offline mobile)* | ★★★★★ *(Offline native)* | ★★★★☆ *(Offline mobile)* | ★★★★★ *(Full offline lifecycle)* | ★★★★★ *(Local DB queue)* |
| **3. AI Photo / Chiller Audit** | ★★☆☆☆ *(Manual photo + Admin review)* | ★★★★★ *(Einstein Vision + AR)* | ★★★★★ *(ShelfScan >95%)* | ★★★★★ *(Ivy Eye + Cooler Purity)* | ★★★★★ *(SKU + POSM AI)* | ★★★☆☆ *(AR display)* | ★★☆☆☆ *(Photo capture)* |
| **4. Gamification & Rep KPIs** | ★☆☆☆☆ *(Admin-only table)* | ★★★☆☆ *(CRM dashboards)* | ★★★★☆ *(KPI scorecards)* | ★★★★☆ *(Perfect Store scores)* | ★★★☆☆ *(BI scorecards)* | ★★★★☆ *(Coaching + goals)* | ★★★☆☆ *(Target tracking)* |
| **5. ERP / DMS Sync** | ★★☆☆☆ *(Manual Excel/CSV batch)* | ★★★★★ *(MuleSoft / ERP)* | ★★★☆☆ *(API / Connectors)* | ★★★★★ *(SAP / Oracle / AWS)* | ★★★☆☆ *(API / BI sync)* | ★★★★★ *(SAP / SFDC / Dynamics)* | ★★★★★ *(Real-time ERP sync)* |
| **6. Guided Selling & NBA** | ★☆☆☆☆ *(None)* | ★★★★☆ *(Automated restock)* | ★★★☆☆ *(Actionable tasks)* | ★★★★☆ *(Perfect Store)* | ★★★☆☆ *(Branching logic)* | ★★★★★ *(PIA AI Coach)* | ★★★★★ *(Promos + Upsell)* |
| **7. Chiller Asset & Batch Delta** | ★★★★★ *(36+ col + Batch Delta)* | ★★★☆☆ *(Asset objects)* | ★★☆☆☆ *(Basic store tags)* | ★★★★★ *(Cold Asset Lifecycle)* | ★★☆☆☆ *(Photo/form tags)* | ★☆☆☆☆ *(Not core)* | ★☆☆☆☆ *(Not core)* |

---

## 4. Deep-Dive Analysis Across the 6 Core Dimensions

### 4.1 Route Optimization
- **What Leaders Do:** Ivy Mobility (*Ivy Compass*) and Salesforce CGC automatically sequence daily store visits using proximity, traffic, visit frequency rules, and store priority—cutting "windshield time" by 20–35%. Repsly pairs route planning with **GPS-verified check-ins** to prove physical store presence.
- **Bassem `v2.5.0` Gap:** Reps see their assigned chillers on OpenStreetMap/Leaflet with `"My Location"`, but must manually decide visit order and copy/open directions one by one.
- **High-ROI Opportunity:** Add **"Plan My Day"** auto-sequencing (nearest-neighbor + urgency weighting for `Underperforming` / `Requires Maintenance` chillers) with one-tap Google Maps/Waze multi-stop handoff and **GPS check-in geofencing (100m radius)**.

### 4.2 Offline Mobile UX
- **What Leaders Do:** Pepperi, Pitcher, and Salesforce CGC treat offline as non-negotiable. Field reps in supermarket basements or rural routes browse store history, fill branching audits, capture high-res photos, and queue submissions in a local database (IndexedDB / SQLite) that auto-syncs when signal returns.
- **Bassem `v2.5.0` Gap:** Flutter Web currently requires an active network connection for API calls and photo uploads; a dropped signal mid-visit risks lost audit work.
- **High-ROI Opportunity:** Convert Flutter Web into an **Offline-First PWA** (Service Worker + IndexedDB sync queue) caching the rep's assigned territory, map pins, and dynamic forms locally.

### 4.3 AI Photo / Chiller Audit
- **What Leaders Do:** Repsly (*ShelfScan*), Ivy Mobility (*Ivy Eye*), and GoSpotCheck use Computer Vision to turn a single cooler photo into structured data in seconds:
  - **Cooler "Purity" Check:** Detects competitor bottles/products inside company-branded chillers.
  - **Out-of-Stock (OOS) & Planogram Compliance:** Flags empty shelves and missing hero SKUs.
  - **POSM & Branding Health:** Verifies decals, price strips, and unobstructed glass doors.
  - **PhotoWorks (GoSpotCheck):** Compiles geo-stamped, time-stamped photos into exportable PDF/deck reports for executives.
- **Bassem `v2.5.0` Gap:** Reps attach photos manually, and Admins must visually inspect every submission in the Visit Review Monitor.
- **High-ROI Opportunity:**
  1. *Near-Term (`v2.6.0`/`v2.7.0`):* **Geo-stamped & time-stamped photo watermarking**, blur/duplicate check, and **1-click Visual Audit PDF Export** (inspired by GoSpotCheck *PhotoWorks*).
  2. *Long-Term (`v3.0.0`):* **AI Chiller Purity & OOS Vision** (detecting competitor intrusion, low stock, and broken/unplugged units from audit photos).

### 4.4 Gamification & Rep Engagement
- **What Leaders Do:** Ivy Mobility (*Perfect Store* scorecards), Repsly, and Pitcher drive rep adoption through transparent daily KPIs, store compliance scores, visit streaks, and branch leaderboards.
- **Bassem `v2.5.0` Gap:** Reps have no personal performance dashboard, visit counter, or target attainment visibility—they only see a filtered table and map.
- **High-ROI Opportunity:** Launch a **Rep KPI Summary Strip** (`Assigned`, `Visited This Month`, `Avg Achievement %`, `Audit Approval Rate`) in `v2.6.0`, followed by **Gamified Visit Streaks, "Perfect Chiller" Badges, and Branch Leaderboards** in `v2.7.0`.

### 4.5 ERP / DMS Sync
- **What Leaders Do:** Pepperi and Ivy Mobility maintain bidirectional sync with SAP, Oracle, NetSuite, and Microsoft Dynamics so pricing, credit limits, and invoice actuals flow automatically without manual spreadsheets.
- **Bassem `v2.5.0` Gap:** Relies on manual `.xlsx`/`.xls`/`.csv` batch uploads. While Bassem's **Batch Delta Auditing** is a huge strength for distributors *without* an ERP API, growing enterprises eventually want automated feeds.
- **High-ROI Opportunity:** Keep manual Excel/CSV + Delta Auditing as a zero-friction superpower for onboarding, and add **Scheduled Webhook / REST ERP Ingestion Connectors** in `v3.0.0` (while preserving immutable batch snapshots for every sync).

### 4.6 Guided Selling & Next Best Action (NBA)
- **What Leaders Do:** Pitcher (*PIA*) and Pepperi act as an in-pocket coach before the rep walks into the store: *"Store X's YTD dropped 25% vs. last month, chiller is Good—pitch SKU Promo B and check stockroom."*
- **Bassem `v2.5.0` Gap:** Bassem already has the rich financial data (`Jan–Dec` invoices, `YTD`, `Month Ach. Status`, `Condition`), but it sits in 36+ table columns rather than an actionable pre-visit brief.
- **High-ROI Opportunity:** Build a **Customer 360 Drawer** (`v2.6.0`) with an automated **Next Best Action (NBA) Card** derived from existing chiller & invoice columns (e.g., *Drop >20% MoM -> Upsell/Restock Alert*; *Condition = Requires Maintenance -> Log Service Ticket*; *Inactive + High Potential -> Relocate Chiller*).

---

## 5. Strategic Recommendations for Bassem Sales Platform

To beat enterprise suites on **time-to-value** while matching them on **field intelligence**, Bassem should prioritize these newly discovered high-ROI enhancements:

| Priority | Enhancement | Inspired By | Why It's High-ROI for Bassem | Target Release |
| :---: | :--- | :--- | :--- | :---: |
| **P1** | **Customer 360 Drawer + Rule-Based Next Best Action (NBA)** | Pitcher / Pepperi | Uses *already-ingested* Jan–Dec & Condition data to give reps instant pre-visit talking points without needing ML yet. | `v2.6.0` |
| **P1** | **Smart Route Sequencing + GPS Check-In Verification** | Ivy Compass / Repsly | Cuts travel time 20–35% and guarantees physical visit authenticity via 100m geofence. | `v2.6.0` / `v2.7.0` |
| **P1** | **Offline-First PWA + Background Sync Queue** | Pepperi / Salesforce CGC | Eliminates lost audits in zero-signal retail stores without native app store friction. | `v2.7.0` |
| **P2** | **Geo-Stamped Photo Watermarking & Visual Audit PDF Export** | GoSpotCheck *PhotoWorks* | Instant executive/client proof-of-execution reports from existing audit attachments. | `v2.7.0` |
| **P2** | **Gamified "Perfect Chiller" Scorecards & Rep Leaderboards** | Repsly / Ivy Mobility | Boosts daily rep adoption, visit completion, and audit quality. | `v2.7.0` |
| **P3** | **AI Chiller "Purity", OOS & POSM Vision Audit** | Ivy Eye / Repsly *ShelfScan* | Automated detection of competitor products, empty shelves, and branding compliance in chiller photos. | `v3.0.0` |
| **P3** | **Scheduled ERP/DMS API & Webhook Ingestion** | Pepperi / Ivy Mobility | Eliminates manual Excel uploads for connected distributors while retaining Batch Delta Auditing. | `v3.0.0` |
