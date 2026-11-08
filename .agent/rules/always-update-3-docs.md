---
description: Always keep the 3 core project documents (BRD, Architecture & Integrations, User Guide) synchronized whenever any PoC feature or business requirement changes.
---

# Egypt Multi-Store Marketplace Facilitator PoC — Core Memory & Documentation Rule

1. **Core Business Model:**
   - The platform operates as a **Zero-Inventory Multi-Store Marketplace Facilitator (Aggregator)** in Egypt.
   - **Partner Stores (Vendors)** hold and manage their own inventory across Product Categories (`wc_categories`, `wc_stores`, `wc_products`).
   - The **Platform** connects Partner Stores to **Clients** (via Web & iOS/Android Flutter Apps), processes payments (Paymob Split/Cards/Meeza/Wallets, Fawry 48h Hold, valU BNPL, InstaPay, COD + WhatsApp OTP), deducts a platform commission %, and **outsources delivery to 3rd-party couriers (Bosta / Mylerz)** who pick up directly from each Partner Store's pickup address and deliver to the Client.

2. **Mandatory Documentation Update Rule:**
   - Whenever **ANY** change is made to the PoC code, screens, APIs, or business model, you **MUST** immediately update all 3 core documents:
     1. `BRD_Egypt_Ecommerce.md` (Business Requirements Document & Main Flows)
     2. `Architecture_and_Integrations.md` (Technical Architecture & Expected Integrations)
     3. `User_Guide.md` (User Guide & Component Testing Manual)
   - Keep both the Brain Artifact copies and `C:\Users\skamal\.gemini\antigravity\scratch\egypt-ecommerce-poc\docs\` copies synchronized.
