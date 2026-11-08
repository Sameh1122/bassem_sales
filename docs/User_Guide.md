# User Guide & Component Testing Manual: Multi-Store Facilitator & Outsourced Delivery PoC

## 1. Quick Access URLs (Live on Vercel Cloud & Local Services)

| Service Name | Live Vercel Production URL | Local URL | Purpose |
| :--- | :--- | :--- | :--- |
| **1. Multi-Store Marketplace Facilitator PoC** | **[https://egypt-ecommerce-poc.vercel.app](https://egypt-ecommerce-poc.vercel.app)** | **[http://localhost:4000](http://localhost:4000)** | Main application with **6 dedicated workspaces**: Client Storefront, My Orders & Tracking, Mobile App, Partner Store Portal, Outsourced Delivery Hub, and Facilitator Control Tower. |
| **2. Egyptian Fintech & Outsourced 3PL Mockup Server** | **[https://egypt-ecommerce-poc.vercel.app/mock-dashboard](https://egypt-ecommerce-poc.vercel.app/mock-dashboard)** | **[http://localhost:4001](http://localhost:4001)** | Sandbox simulating **Paymob Split**, **FawryPay**, **valU**, **WhatsApp COD OTP**, **Bosta Store-to-Client Delivery**, and **Cash Settlement**. |
| **3. Architecture & 1st-Year Liability Study** | **[https://egypt-ecommerce-poc.vercel.app/study](https://egypt-ecommerce-poc.vercel.app/study)** | **[http://localhost:8080](http://localhost:8080)** | Comparative study of the Top 5 platforms and 1st-Year Liability Calculator. |

---

## 2. Step-by-Step Guide to the 6 Dedicated Workspaces on `http://localhost:4000`

Open **[http://localhost:4000](http://localhost:4000)** in your browser and press **`Ctrl + R`** (refresh) to load the new **Eye-Friendly Light/Dark UI**.
* **☀️ Light / 🌙 Dark Theme Switcher:** The platform defaults to a crisp, high-contrast **Light Mode** that is easy on the eyes, with a **🌙 Dark Mode / ☀️ Light Mode** button in the top-right header.
* **🌐 Bilingual English & Arabic RTL:** Switch between English and native Arabic layout with one click on `🌐 العربية`.

### Tab 1: `🛒 1. Client Storefront` (Spacious Catalog + 3-Step Checkout)
1. **Filter by Product Category:** Click any category pill:
   * `🌐 All Categories`, `📱 Electronics & Mobile`, `🧥 Egyptian Fashion & Cotton`, `☕ Home & Coffee Appliances`, `✨ Beauty & Skincare`, `👟 Sports & Footwear`.
2. **Filter by Partner Store:** Use the **Filter by Partner Store** dropdown to view products from a specific store (*Cairo Tech Hub*, *Giza Cotton Atelier*, *Alex Glow & Home*).
3. **Multi-Store Cart Split:** Add items from multiple partner stores; notice automatic Bosta multi-pickup dispatch, facilitator commission calculation, and net store payout preview.
4. **Place Order:** Click **🔒 Place Order & Dispatch to Partner Store(s)** and complete the payment simulation (Paymob 3DS, Fawry Kiosk Cash, valU OTP, InstaPay, or WhatsApp COD OTP).
5. **Direct Tracking Link:** Click **📦 Track My Orders** in the hero banner or order modal to instantly jump to your orders dashboard.

---

### Tab 2: `📦 2. My Orders & Tracking` (Active Shipments & Historical Closed Archive)
1. **Click `📦 2. My Orders & Tracking` in the top navigation bar.**
2. **High-Level KPI Summary:**
   * **Total Client Orders:** Lifetime order count.
   * **Active & In-Transit (Pulsing Cyan):** Orders currently undergoing store packaging or transit with Bosta.
   * **Completed & Closed (Emerald):** Delivered, settled, or archived orders.
   * **Total Purchase Value (EGP):** Cumulative fulfilled purchases.
3. **Active vs. Closed Scope Filtering:**
   * Click **🌟 All Orders**, **🚚 Active & In-Transit**, or **✅ Completed & Closed** to filter orders instantly.
4. **Live Search Bar:**
   * Type in the search box to filter live by **Order Number** (e.g. `EG-36711-31`), **Recipient Phone** (`010...`), or **Partner Store Name**.
5. **5-Stage Visual Progress Stepper:**
   * Each order card displays a visual milestone pipeline (`1. Order Placed` $\rightarrow$ `2. Payment Verified & Split` $\rightarrow$ `3. Store Packaged` $\rightarrow$ `4. Out for Delivery` $\rightarrow$ `5. Delivered & Settled`) with status indicators, percentages, and timestamps.
6. **Partner Store Sub-Manifests & Bosta AWBs:**
   * Inspect each fulfilling partner store branch, merchant packaging state, and click the **Bosta Waybill (`BST-xxxxxxx ↗`)** to open the 3PL sandbox tracker.
7. **Auditable Tax Invoice Modal (`#invoiceModal`):**
   * Click **📄 View / Print Tax Invoice** to display the official commercial invoice featuring NileConnect Tax ID (`492-817-309`), Commercial Register (`184920`), itemized store origins, VAT 14%, and a 1-click **🖨️ Print / Save PDF** button.
8. **1-Click Support Chat & Cart Reorder:**
   * Click **💬 Inquire with Support** to open the customer support drawer pre-populated with your order number.
   * Click **🔁 Reorder Items** to reload all products into your shopping cart.

---

### Tab 3: `📱 3. Mobile App` (iOS & Android Shopping & Live Push Stream)
1. Click **📱 3. Mobile App** in the top bar.
2. Switch between **🍎 iOS (Apple Pay)** and **🤖 Android (Google Play)**.
3. Tap product categories, add items to cart, and tap ** Pay / Place Mobile Order**.
4. Watch the **live push notification banner** update in real-time as stores pack your items and couriers pick them up.

---

### Tab 4: `🏪 4. Partner Store Portal` (Dedicated Screen for Partner Stores)
1. Click **🏪 4. Partner Store Portal** in the top bar.
2. Switch between onboarded stores (*Cairo Tech Hub*, *Giza Cotton Atelier*, *Alex Glow & Home*).
3. Adjust inventory (`+5 Stock` / `-1`) or publish new products under any category.
4. In the **Incoming Sub-Orders to Pack** table, click **📦 Mark Packaged for Bosta** to ready parcels for 3PL pickup.

---

### Tab 5: `🚚 5. Outsourced Delivery Hub` (Dedicated Screen for Bosta 3PL Delivery)
1. Click **🚚 5. Outsourced Delivery Hub** in the top bar.
2. View direct **Store Pickup Origin $\rightarrow$ Client Drop-off Destination** manifests.
3. Follow the **Guided Next-Step Pipeline Button**:
   * `Step 1: Store Packed` $\rightarrow$ `Step 2: Bosta Picked Up` $\rightarrow$ `Step 3: Out for Delivery` $\rightarrow$ `Step 4: Delivered` $\rightarrow$ `💸 Step 5: Settle Cash & Commission`.
4. Each transition triggers HMAC-signed webhooks, updates Bosta waybills, and notifies clients.

---

### Tab 6: `⚙️ 6. Facilitator Control Tower` (360° Visibility, Commercial Policy Engine & Support Desk)
1. Click **⚙️ 6. Facilitator Control Tower**.
2. **8 Executive KPI Cards:** Realized vs. pending commissions, store escrow payouts, Egypt VAT ledger (14%), and webhook health.
3. **Commercial Policy Engine:**
   * Set Commission %, Egypt VAT %, VAT Mode (`INCLUSIVE` vs. `ADDITIVE`), Delivery Fee Override, COD Fee, and Settlement Cycle across **ALL Stores** or a **Specific Store**.
4. **Governorate Delivery Rates & Bulk Cash Settlement:**
   * Adjust Bosta rates per governorate and settle all eligible delivered sub-orders in 1 click.
5. **Customer Support Live Desk:**
   * Review incoming Client support tickets (`SUP-xxxx`), reply live to shoppers, or mark tickets resolved.
6. **Master Tables & Webhooks Inspector:**
   * Inspect all orders, deliveries, inventory items, and HMAC-SHA512 webhook logs.

---

## 3. Running the Automated 11-Stage End-to-End (E2E) Test Suite

Run the full E2E lifecycle test suite anytime in PowerShell:

```powershell
python "C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc\test_poc.py"
```

### Verified E2E Lifecycle Stages (`11/11 Passing`)
* **E2E Stage 1 (Store Adds Product):** Partner Store (`Cairo Tech Hub`) publishes a new product (`Samsung Galaxy Watch 7 Ultra`, `24,000 EGP`, `10` stock) into Category `Electronics & Mobile`.
* **E2E Stage 2 (Client Buy & Payment):** Client buys `2x` Watch (`Store 1`) + `1x` Giza Hoodie (`Store 2`), verifies commission split (`4,014 EGP` Facilitator / `45,436 EGP` Stores), approves Paymob 3DS, and verifies permanent store stock deduction (`10 -> 8`).
* **E2E Stage 3 (Store Fulfillment):** Both Partner Stores pack and mark their sub-orders `READY_FOR_COURIER_PICKUP`.
* **E2E Stage 4 (Outsourced 3PL Delivery):** Bosta picks up from both store branches (`PICKED_UP_FROM_STORE` $\rightarrow$ `OUT_FOR_DELIVERY` $\rightarrow$ `DELIVERED`) and marks both sub-orders `ELIGIBLE_FOR_SETTLEMENT`.
* **E2E Stage 5 (Cash Settlement & Commission Realization):** Executes `POST /wp-json/wc/v3/deliveries/{id}/settle`, generating HMAC-verified `STL-xxxxxx` settlement records, paying `+44,160 EGP` to Store 1 and `+1,276 EGP` to Store 2, realizing `+4,014 EGP` Facilitator Commission, and marking the order `completed-settled`.
* **E2E Stage 6 (Full COD E2E Cycle):** Verifies WhatsApp OTP (`4455`) $\rightarrow$ Store Packaging $ightarrow$ Bosta COD Collection (`24,070 EGP`) $\rightarrow$ Bosta COD Remittance & InstaPay Store Payout (`22,080 EGP` to Store 1 + `1,920 EGP` Facilitator Fee, final stock `7`).
* **E2E Stage 7 (Fawry 48h Expiry Protection):** Verifies 3 reserved units are automatically returned to the Partner Store's available stock (`7`) when a Fawry reference code expires.
* **E2E Stage 8 (Webhook Security):** Verifies forged HMAC-SHA512 settlement webhooks are rejected with `HTTP 401`.
* **E2E Stage 9 (Commercial Policy Engine — Per-Store & All-Stores):** Verifies applying custom commission (`15%`), `ADDITIVE` Egypt VAT (`+14%`), Free Delivery override (`0 EGP`), and custom COD fee (`25 EGP`) to Store `#1`, then restoring global rules across `all` stores and executing bulk settlement (`POST /wp-json/wc/v3/settlements/settle-bulk`).
* **E2E Stage 10 (Two-Way Live Customer Support Chat):** Verifies Client opening a support ticket on the Storefront (`POST /wp-json/wc/v3/support/tickets`), Facilitator Admin replying from the Support Desk, Client responding, and Admin marking the ticket `RESOLVED`.
* **E2E Stage 11 (Client Order Monitoring & History Archive):** Verifies `/wp-json/wc/v3/orders/track` endpoint aggregation, active vs. closed order partitioning, 5-stage milestone pipelines, Bosta waybills, single order tracking, and live query filtering.

---

## 4. Deploying the Full Environment to Vercel

The project at `C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc` includes `vercel.json`, `api/index.py`, `requirements.txt`, and a Git repository so all 3 services (`:4000` Core Platform, `:4001` Mock Integrations Sandbox, and `:8080` Study Report) deploy under a single production URL: **`https://egypt-ecommerce-poc.vercel.app`**.
