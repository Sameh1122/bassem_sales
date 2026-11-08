# User Guide & Component Testing Manual: Multi-Store Facilitator & Outsourced Delivery PoC

## 1. Quick Access URLs & Running Services

| Service Name | Local URL | Purpose |
| :--- | :--- | :--- |
| **1. Multi-Store Marketplace Facilitator PoC** | **[http://localhost:4000](http://localhost:4000)** | Main application with **5 dedicated tabs**: Client Storefront, iOS/Android App, Partner Store Portal, Outsourced Delivery Hub, and Facilitator Admin. |
| **2. Egyptian Fintech & Outsourced 3PL Mockup Server** | **[http://localhost:4001](http://localhost:4001)** | Standalone sandbox simulating **Paymob Split**, **FawryPay**, **valU**, **WhatsApp COD OTP**, and **Bosta Store-to-Client Delivery API**. |
| **3. Architecture & 1st-Year Liability Study** | **[http://localhost:8080](http://localhost:8080)** | Comparative study of the Top 5 platforms and 1st-Year Liability Calculator. |

---

## 2. Step-by-Step Guide to the Redesigned 5 Workspaces on `http://localhost:4000`

Open **[http://localhost:4000](http://localhost:4000)** in your browser and press **`Ctrl + R`** (refresh) to load the new **Eye-Friendly Light/Dark UI**.
* **☀️ Light / 🌙 Dark Theme Switcher:** The platform now defaults to a crisp, high-contrast **Light Mode** that is easy on the eyes, with a **🌙 Dark Mode / ☀️ Light Mode** button in the top-right header.
* **Guided 4-Step Badges:** Each screen displays its exact role in the business flow (`STEP 1 OF 4: CLIENT SHOPPING` $\rightarrow$ `STEP 2 OF 4: PARTNER STORE PORTAL` $\rightarrow$ `STEP 3 OF 4: OUTSOURCED 3PL LOGISTICS` $\rightarrow$ `STEP 4 OF 4: 360° FACILITATOR CONTROL TOWER`).

### Tab 1: `🛒 1. Client Storefront` (Spacious Catalog + 3-Step Checkout)
1. **Filter by Product Category:** Click any of the category pills at the top:
   * `🌐 All Categories`, `📱 Electronics & Mobile`, `🧥 Egyptian Fashion & Cotton`, `☕ Home & Coffee Appliances`, `✨ Beauty & Skincare`, `👟 Sports & Footwear`.
2. **Filter by Partner Store:** Use the **Filter by Partner Store** dropdown to view products from a specific store (*Cairo Tech Hub — Nasr City*, *Giza Cotton Atelier — Dokki*, *Alex Glow & Home — Smouha*).
3. **Inspect Product Cards:** Each card shows its **Category Badge**, **Partner Store Origin Badge (`🏪 Store Name • Governorate`)**, **Store Available Stock**, and **valU 12-month installment preview**.
4. **Multi-Store Cart & Commission Split:**
   * Add items from **2 different Partner Stores** to your cart.
   * Notice in the Cart summary on the right:
     * **Partner Stores in Cart:** Shows `2 Partner Store(s) -> 2 Bosta Pickup(s)`.
     * **Your Facilitator Commission:** Shows your exact platform revenue (`8%–12%` of items).
     * **Stores Net:** Shows the net payout owed to the Partner Stores.
5. **Place Order & Simulate Egyptian Payment:** Click **🔒 Place Order & Dispatch to Partner Store(s)** and complete the payment in the interactive modal (Paymob 3DS, Fawry Kiosk Cash, valU OTP, InstaPay, or WhatsApp COD OTP).

---

### Tab 2: `📱 2. iOS & Android App` (Mobile Category Pills & Store Badges)
1. Click **📱 2. iOS & Android App** in the top bar.
2. Tap the horizontal **Product Categories** pills inside the phone screen (`All`, `📱 Electronics`, `🧥 Egyptian`, `☕ Home`, `✨ Beauty`, `👟 Sports`).
3. Tap **+ Add** on products from different Partner Stores and tap ** Pay / Place Mobile Order**.
4. Watch the **top push notification banner** on the phone screen update live as Partner Stores package your order and Bosta picks it up!

---

### Tab 3: `🏪 3. Partner Store Portal` (Dedicated Screen for Partner Stores)
1. Click **🏪 3. Partner Store Portal** in the top bar.
2. **Switch Active Partner Store:** Use the **Active Partner Store** dropdown in the top-right to switch between:
   * `🏪 Cairo Tech Hub (Nasr City) — Commission: 8%`
   * `🏪 Giza Cotton Atelier (Dokki) — Commission: 12%`
   * `🏪 Alex Glow & Home (Smouha) — Commission: 10%`
3. **View Store Financial KPIs:** See that store's **Store Gross Sales**, **Platform Commission Deducted**, **Net Store Payout Earned**, and **Store Sub-Orders**.
4. **Manage Store-Owned Inventory:**
   * Click **+5 Stock** or **-1** on any of the store's products—it updates the live storefront stock immediately.
   * Use the **➕ Add Product to This Store's Inventory** form on the right to publish a new product under any **Product Category**.
5. **Prepare Incoming Sub-Orders for Courier Pickup:**
   * In the bottom table (**Incoming Sub-Orders for This Store**), click **📦 Mark Packaged for Bosta** to notify the Outsourced Delivery Hub that the parcel is packed and ready at the store branch!

---

### Tab 4: `🚚 4. Outsourced Delivery Hub` (Dedicated Screen for Outsourced 3PL Delivery)
1. Click **🚚 4. Outsourced Delivery Hub** in the top bar.
2. Every order is automatically split by Partner Store into direct **Store-to-Client Delivery Manifests**:
   * **Column 1 (Pickup Origin — Partner Store):** Shows the exact Partner Store name, Governorate, branch pickup address, and store phone number.
   * **Column 2 (Drop-off Destination — Client):** Shows the Client's name, Governorate, delivery street address, and phone number.
   * **Column 3 (Parcel Items & Financials):** Shows the items to pick up from that store, the **COD Cash to Collect**, and the **Store Net Payout**.
3. **Simulate the Full Outsourced Courier & Cash Settlement Lifecycle:**
   * Click **1. Store Packed** (if not already marked by the store) $\rightarrow$ **2. Picked Up from Store** $\rightarrow$ **3. Out for Delivery** $\rightarrow$ **4. Delivered to Client** $\rightarrow$ **💸 5. Settle Cash & Commission**.
   * Each click fires a live HMAC-signed webhook from Port `4001` to Port `4000`, records the `STL-xxxxxx` payout in `wc_settlements`, and pushes a real-time notification to the Client and Partner Store!

---

### Tab 5: `⚙️ 5. Facilitator Control Tower` (360° Visibility, Commercial Policy Engine, Support Desk & Webhooks)
1. Click **⚙️ 5. Facilitator Control Tower**.
2. **8-Card 360° Executive KPIs:** View **Total Marketplace GMV**, **Your Commission (Realized vs. Pending)**, **Stores Net Payout (Settled vs. Escrow)**, **Egypt VAT Ledger (14%)**, **Outsourced 3PL Deliveries**, **All-Stores Inventory**, **Customer Support Live Desk**, and **Webhooks & HMAC Health**.
3. **🎛️ Commercial Policy Engine (Manage Delivery Fee, VAT %, Commission %, COD Fee & Settlement per ALL Stores or a Specific Store):**
   * Choose **Target Scope**: `🌐 Apply to ALL Partner Stores (Global Policy)` OR select a **Specific Partner Store** (e.g., *Cairo Tech Hub*, *Giza Cotton Atelier*, *Alex Glow & Home*).
   * Configure **Facilitator Commission (`%`)**, **Egypt VAT (`%`)**, **VAT Calculation Mode (`INCLUSIVE` vs. `ADDITIVE`)**, **Store Delivery Fee Override (`EGP` — leave blank for Governorate rate or set `0` for Free Delivery)**, **Extra Multi-Store Pickup Fee (`EGP`)**, **COD Collection Fee (`EGP`)**, and **Cash Settlement Schedule (`T+1`, `INSTANT`, `WEEKLY`)**.
   * Click **💾 Apply Commercial Policy Rules** — the Client Storefront & Checkout Calculator immediately reflect the updated fees, VAT, and commission split!
4. **🚚 Governorate 3PL Delivery Fees & 💸 Bulk Cash Settlement:**
   * Update Bosta delivery rates (`EGP`) and SLAs for a specific Governorate or across **ALL Governorates**.
   * Select **All Partner Stores** or a **Specific Store** and click **💸 Settle All Delivered Orders Now** to bulk-settle all eligible orders in one click.
5. **🎧 Customer Support & Live Client Chat Desk:**
   * View all incoming Client support tickets (`SUP-xxxx`), inspect the full message transcript, type a reply and click **📤 Send Admin Reply to Client**, or mark tickets **✅ Resolved / 🔄 Re-open**.
   * Note: Clients can message you anytime from the **💬 Chat with Support** button on the Client Storefront (`Tab 1` banner, top navigation bar, or floating bottom-left launcher).
6. **Full 360° Operational Control Tables:**
   * **📦 Master All-Stores Inventory & Commercial Matrix Table** (`+5` / `-1` stock overrides across any store).
   * **🚚 Master Outsourced 3PL Deliveries & Fulfillment Control Table** (trigger Store Pack, Bosta Pickup, Out for Delivery, Delivered, or Cash Settlement directly from Admin).
   * **💸 Cash Settlements Ledger (`wc_settlements`)**, **🧾 Master Orders Table**, and **🔌 Provider-Filterable Webhooks Inspector**.

---

## 3. Running the Automated 10-Stage End-to-End (E2E) Test Suite

Run the full E2E lifecycle test suite anytime in PowerShell:

```powershell
python "C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc\test_poc.py"
```

### Verified E2E Lifecycle Stages (`10/10 Passing`)
* **E2E Stage 1 (Store Adds Product):** Partner Store (`Cairo Tech Hub`) publishes a new product (`Samsung Galaxy Watch 7 Ultra`, `24,000 EGP`, `10` stock) into Category `Electronics & Mobile`.
* **E2E Stage 2 (Client Buy & Payment):** Client buys `2x` Watch (`Store 1`) + `1x` Giza Hoodie (`Store 2`), verifies commission split (`4,014 EGP` Facilitator / `45,436 EGP` Stores), approves Paymob 3DS, and verifies permanent store stock deduction (`10 -> 8`).
* **E2E Stage 3 (Store Fulfillment):** Both Partner Stores pack and mark their sub-orders `READY_FOR_COURIER_PICKUP`.
* **E2E Stage 4 (Outsourced 3PL Delivery):** Bosta picks up from both store branches (`PICKED_UP_FROM_STORE` $\rightarrow$ `OUT_FOR_DELIVERY` $\rightarrow$ `DELIVERED`) and marks both sub-orders `ELIGIBLE_FOR_SETTLEMENT`.
* **E2E Stage 5 (Cash Settlement & Commission Realization):** Executes `POST /wp-json/wc/v3/deliveries/{id}/settle`, generating HMAC-verified `STL-xxxxxx` settlement records, paying `+44,160 EGP` to Store 1 and `+1,276 EGP` to Store 2, realizing `+4,014 EGP` Facilitator Commission, and marking the order `completed-settled`.
* **E2E Stage 6 (Full COD E2E Cycle):** Verifies WhatsApp OTP (`4455`) $\rightarrow$ Store Packaging $\rightarrow$ Bosta COD Collection (`24,070 EGP`) $\rightarrow$ Bosta COD Remittance & InstaPay Store Payout (`22,080 EGP` to Store 1 + `1,920 EGP` Facilitator Fee, final stock `7`).
* **E2E Stage 7 (Fawry 48h Expiry Protection):** Verifies 3 reserved units are automatically returned to the Partner Store's available stock (`7`) when a Fawry reference code expires.
* **E2E Stage 8 (Webhook Security):** Verifies forged HMAC-SHA512 settlement webhooks are rejected with `HTTP 401`.
* **E2E Stage 9 (Commercial Policy Engine — Per-Store & All-Stores):** Verifies applying custom commission (`15%`), `ADDITIVE` Egypt VAT (`+14%`), Free Delivery override (`0 EGP`), and custom COD fee (`25 EGP`) to Store `#1`, then restoring global rules across `all` stores and executing bulk settlement (`POST /wp-json/wc/v3/settlements/settle-bulk`).
* **E2E Stage 10 (Two-Way Live Customer Support Chat):** Verifies Client opening a support ticket on the Storefront (`POST /wp-json/wc/v3/support/tickets`), Facilitator Admin replying from the Support Desk, Client responding, and Admin marking the ticket `RESOLVED`.

---

## 4. Troubleshooting & Interactive Responsiveness Notes
* **Make sure you are on Port `4000` (`http://localhost:4000`):** Port `8080` (`http://localhost:8080`) hosts the static Egypt E-Commerce Study report (which now includes a green **🚀 Launch Interactive PoC (Port 4000)** button in its top bar), whereas Port `4000` (`http://localhost:4000`) hosts the live interactive 5-tab platform.
* **Instant Toast Feedback:** Every interactive button (adding to cart, filtering by category, adjusting store inventory, marking an order packaged, or triggering a Bosta courier pickup) displays a confirmation Toast notification in the bottom-right corner and updates the state immediately.

---

## 5. Deploying the Full Environment to Vercel

The project at `C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc` includes [vercel.json](file:///C:/Users/skamal/.gemini/antigravity/scratch/egypt-ecommerce-poc/vercel.json), [api/index.py](file:///C:/Users/skamal/.gemini/antigravity/scratch/egypt-ecommerce-poc/api/index.py), [requirements.txt](file:///C:/Users/skamal/.gemini/antigravity/scratch/egypt-ecommerce-poc/requirements.txt), and a pre-initialized Git repository so all 3 local services (`:4000` Core Platform, `:4001` Mock Integrations Sandbox, and `:8080` Study Report) run under a single Vercel URL (`https://your-project.vercel.app`, `/mock-dashboard`, and `/study`).

### Option A: Deploy Directly from Terminal via `npx vercel`
```powershell
cd "C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc"
npx vercel login
npx vercel --prod
```

### Option B: Deploy via GitHub $\rightarrow$ Vercel Dashboard
```powershell
cd "C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc"
git remote add origin https://github.com/<your-username>/egypt-ecommerce-poc.git
git push -u origin main
```
Then import the repository at **[vercel.com/new](https://vercel.com/new)** with zero configuration required (`vercel.json` is automatically detected).
