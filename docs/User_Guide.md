# User Guide & Component Testing Manual: Multi-Store Facilitator & Outsourced Delivery PoC

## 1. Quick Access URLs (Live on Vercel Cloud & Local Services)

| Service Name | Live Vercel Production URL | Local URL | Purpose |
| :--- | :--- | :--- | :--- |
| **1. Multi-Store Marketplace Facilitator PoC** | **[https://egypt-ecommerce-poc.vercel.app](https://egypt-ecommerce-poc.vercel.app)** | **[http://localhost:4000](http://localhost:4000)** | Main application with **6 dedicated workspaces**: Client Storefront, My Orders & Tracking, Mobile App, Partner Store Portal, Outsourced Delivery Hub, and Facilitator Control Tower. |
| **2. Egyptian Fintech & Outsourced 3PL Mockup Server** | **[https://egypt-ecommerce-poc.vercel.app/mock-dashboard](https://egypt-ecommerce-poc.vercel.app/mock-dashboard)** | **[http://localhost:4001](http://localhost:4001)** | Sandbox simulating **Paymob Split**, **FawryPay**, **valU**, **WhatsApp COD OTP**, **Bosta Store-to-Client Delivery**, and **Cash Settlement**. |
| **3. Architecture & 1st-Year Liability Study** | **[https://egypt-ecommerce-poc.vercel.app/study](https://egypt-ecommerce-poc.vercel.app/study)** | **[http://localhost:8080](http://localhost:8080)** | Comparative study of the Top 5 platforms and 1st-Year Liability Calculator. |

---

## 2. Interactive Guide to the 14-Step Fulfillment Lifecycle

Follow this step-by-step walkthrough across the platform's tabs to verify the full fulfillment cycle:

### Steps 1–4: Client Shopping & Checkout
1. **Step 1 (Select Location):** On **Tab 1 (`🛒 Client Storefront`)**, locate the **📍 Choose Your Shopping Location** bar.
   * Click **Cairo (Nasr City)**: Notice the partner store dropdown immediately filters to stores operating in Cairo (*Cairo Tech Hub*), and the product catalog updates to show Cairo inventory only.
2. **Step 2 (Add to Cart):** Add items to cart (e.g. 1x iPhone 16 Pro + 1x AirPods Pro 2).
3. **Step 3 (Checkout):** Proceed to the 3-step checkout drawer; delivery address automatically defaults to the selected governorate.
4. **Step 4 (Select Payment Method):** Select **Credit / Debit Card** or **Cash on Delivery (COD)**.
   * On submit, the order is created in `order_status = 'pending-store-review'`.
   * For card payments, money is held in pre-authorization and a **4-digit Handover PIN** is created.

### Step 5: Partner Store Availability Review
5. Switch to **Tab 4 (`🏪 Partner Store Portal`)**.
   * Under the **Store Availability Review** card, locate the pending order.
   * Inspect the items checklist: Check the in-stock item (iPhone 16 Pro) and **uncheck / de-select** the out-of-stock item (AirPods Pro 2).
   * Click **✅ Confirm In-Stock Items & Send to Client**.
   * The platform releases the reserved stock of the de-selected item, recalculates the order total, and moves status to `store-reviewed`.

### Steps 6–7: Client Confirmation & Card Money Capture
6. Switch to **Tab 2 (`📦 My Orders & Tracking`)**.
   * In the top order card, a cyan review banner will appear: **"Step 6 & 7: Store Verified Items • Your Confirmation Required"**.
   * Review the revised items and updated total.
   * Click **💳 Confirm & Proceed (Money Taken from Card)**.
   * The system captures the funds from the client's card (`payment_status = 'paid'`) and moves the order to `ready-to-ship`.
   * *(Alternatively, clicking "Reject Order" voids the pre-auth hold and cancels the order with 0 charge).*

### Steps 8–12: Packaging & Proximity Courier Delivery
7. **Step 8 (Store Packaged):** In **Tab 4** (or Tab 5), click **📦 Step 8: Mark Store Packed**. The sub-order packaging status changes to `READY_FOR_COURIER_PICKUP`.
8. **Step 9 (Proximity Courier Search & Assign):** Switch to **Tab 5 (`🚚 Outsourced Delivery Hub`)**.
   * The platform queries the nearby fleet for the store branch governorate.
   * Click **🎯 Step 9: Assign Nearest Courier (Tarek Mostafa • 0.8 km)**.
9. **Step 10 & 11 (Courier Pickup):** Click **🚚 Step 10: Tarek Mostafa Confirm Pickup**. The courier confirms pickup at the branch, and a real-time push notification is sent to the client.
10. **Step 12 (Reach Client):** Click **📍 Step 12: Mark Courier Arrived at Client**. Status moves to `ARRIVED_AT_CLIENT`.

### Steps 13–14: Handover Code Verification vs. COD Cash Collection
11. **Step 13 (Handover Code / Cash):**
    * **For Prepaid Card Orders:** Client opens **Tab 2 (`My Orders`)** and views their secret **4-digit Handover PIN** (e.g. `7985`). The client tells this code to the courier.
    * **For Cash on Delivery (COD) Orders:** **Crucial Rule:** *In case of cash on delivery, no need for the code.* The client simply pays the cash total.
12. **Step 14 (Handover Confirmation & Settlement):**
    * In **Tab 5 (`Delivery Hub`)**:
      * If **Prepaid**: Enter the 4-digit PIN into the input box and click **Verify & Deliver**. (Entering an invalid PIN such as `0000` is rejected with an alert).
      * If **COD**: Click **💵 Step 14: Confirm Cash Received & Deliver** (no PIN required).
    * Parcel is handed over, marked `DELIVERED`, and automated cash settlement (`STL-xxxxxx`) is executed.

---

## 3. Sanity Check Test Data from Historical Orders

The following test data was recorded during the comprehensive automated test cycle on the platform:

| Order Number | Status | Payment Method (Status) | Handover PIN | Courier Assigned | Settlement Ref | Total (EGP) | Customer & Location |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **EG-5877-28** | `completed-settled` | `cod` (settled) | `N/A (COD: 7699)` | Karim Adel (🛵 Motorcycle) | `STL-763997` | 1,520.00 EGP | Laila Mourad (GIZA) |
| **EG-5456-89** | `completed-settled` | `paymob_card` (settled) | `7985` | Tarek Mostafa (🛵 Motorcycle) | `STL-781080` | 64,555.00 EGP | Tamer Hosny (CAIRO) |
| **EG-4962-36** | `cancelled` | `fawry_ref` (expired) | `4341` | Bosta Rider | `N/A` | 72,070.00 EGP | Nourhan Adel (ALEX) |
| **EG-4554-83** | `completed-settled` | `cod` (settled) | `N/A (COD: 4448)` | Bosta Rider | `STL-728569` | 24,070.00 EGP | Tarek Mansour (CAIRO) |
| **EG-3782-37** | `completed-settled` | `paymob_card` (settled) | `8457` | Bosta Rider | `STL-714111` | 49,530.00 EGP | Omar El-prince (CAIRO) |
| **EG-87269-40** | `in-transit` | `paymob_card` (paid) | `5638` | Tarek Mostafa (🛵 Motorcycle) | `N/A` | 64,555.00 EGP | Tamer Hosny (CAIRO) |
| **EG-86801-34** | `cancelled` | `fawry_ref` (expired) | `8783` | Bosta Rider | `N/A` | 72,070.00 EGP | Nourhan Adel (ALEX) |
| **EG-86401-98** | `completed-settled` | `cod` (settled) | `N/A (COD: 7862)` | Bosta Rider | `STL-720650` | 24,070.00 EGP | Tarek Mansour (CAIRO) |
| **EG-85624-16** | `completed-settled` | `paymob_card` (settled) | `2590` | Bosta Rider | `STL-709248` | 49,530.00 EGP | Omar El-prince (CAIRO) |
| **EG-64480-37** | `ready-to-ship` | `paymob_card` (paid) | `4919` | Bosta Rider | `N/A` | 64,555.00 EGP | Tamer Hosny (CAIRO) |

---

## 4. Key Verification Takeaways
* **Prepaid Security:** Prepaid card orders strictly mandate the 4-digit Handover PIN. Attempting to deliver with an invalid PIN triggers an immediate rejection.
* **COD Convenience:** Cash on Delivery requires no PIN code. Physical cash handover provides proof of fulfillment and immediately unlocks cash settlement.
* **Store De-Selection Protection:** Partner stores can safely de-select out-of-stock items; the platform adjusts order pricing and reserves before client confirmation.
* **Proximity Courier Matching:** Dispatch selects couriers located within 0.8–1.4 km of the partner store branch, cutting pickup latency significantly.
