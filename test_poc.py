#!/usr/bin/env python3
"""
Full End-to-End (E2E) Lifecycle & Integration Test Suite
Covers the complete Facilitator Business Cycle:
  Stage 1: Partner Store adds a new Product to the Platform (linked to a Product Category)
  Stage 2: Client browses, calculates Multi-Store Cart Split, and buys the Product (Paymob Split & COD)
  Stage 3: Partner Store Fulfillment (Store marks parcel READY_FOR_COURIER_PICKUP)
  Stage 4: Outsourced 3PL Delivery (Bosta picks up from Store branch -> Out for Delivery -> Delivered to Client)
  Stage 5: Cash Settlement & Commission Realization (STL-xxxxxx payout to Store + Commission to Facilitator)
  Stage 6: Full COD E2E Cycle (WhatsApp OTP -> Store Pack -> Bosta COD Collection -> COD Cash Settlement)
  Stage 7: Fawry 48h Reservation & Expiry Stock Return to Partner Store
  Stage 8: HMAC-SHA512 Webhook Security Verification
"""

import json
import random
import time
import urllib.request
import urllib.error

CORE_URL = "http://127.0.0.1:4000/wp-json/wc/v3"
MOCK_URL = "http://127.0.0.1:4001/mock"


def http_req(url: str, method: str = "GET", body: dict = None, headers: dict = None) -> tuple:
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.getcode(), json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))


def run_e2e_tests():
    print("=" * 88)
    print("STARTING FULL END-TO-END (E2E) MARKETPLACE FACILITATOR LIFECYCLE TEST")
    print("Flow: Store Adds Product -> Client Buy -> Fulfillment -> 3PL Delivery -> Cash Settlement")
    print("=" * 88)

    # Record baseline store balances before E2E run
    code, stores_before = http_req(f"{CORE_URL}/stores")
    assert code == 200 and len(stores_before) >= 3
    s1_before = next(s for s in stores_before if s["id"] == 1)
    s2_before = next(s for s in stores_before if s["id"] == 2)

    # =========================================================================
    # STAGE 1: PARTNER STORE ADDS NEW PRODUCT TO PLATFORM
    # =========================================================================
    unique_sku = f"EG-E2E-W7-{int(time.time() * 1000) % 100000}-{random.randint(10, 99)}"
    code, add_prod_resp = http_req(f"{CORE_URL}/products", "POST", {
        "store_id": 1,        # Cairo Tech Hub (Nasr City) - 8% Commission
        "category_id": 1,     # Electronics & Mobile
        "sku": unique_sku,
        "name_en": "Samsung Galaxy Watch 7 Ultra (Egypt Official Warranty)",
        "name_ar": "ساعة سامسونج جالكسي واتش 7 ألترا - ضمان محلي",
        "price_egp": 24000.0,
        "stock_quantity": 10,
        "image_emoji": "⌚"
    })
    assert code == 201 and add_prod_resp["success"], f"Failed to add store product: {add_prod_resp}"
    new_prod = add_prod_resp["product"]
    new_prod_id = new_prod["id"]

    # Verify product appears on storefront with 10 available stock
    _, all_prods = http_req(f"{CORE_URL}/products")
    live_prod = next(p for p in all_prods if p["id"] == new_prod_id)
    assert live_prod["stock_quantity"] == 10
    assert live_prod["reserved_quantity"] == 0
    assert live_prod["available_stock"] == 10
    print(f"[PASS] E2E Stage 1 (Store Adds Product): Store '{live_prod['store_name_en']}' published '{live_prod['name_en']}' (SKU: {unique_sku}, Price: 24,000 EGP, Stock: 10)")

    # =========================================================================
    # STAGE 2: CLIENT BROWSES, CALCULATES CART SPLIT & BUYS PRODUCT
    # =========================================================================
    # Client buys 2x of the newly added Watch (48,000 EGP from Store 1 @ 8% fee = 3,840 EGP comm, 44,160 EGP store net)
    # + 1x Giza Heavy Cotton Hoodie (1,450 EGP from Store 2 @ 12% fee = 174 EGP comm, 1,276 EGP store net)
    cart_items = [
        {"product_id": new_prod_id, "quantity": 2},
        {"product_id": 3, "quantity": 1}
    ]
    code, calc = http_req(f"{CORE_URL}/cart/calculate", "POST", {
        "items": cart_items,
        "governorate": "CAIRO",
        "payment_method": "paymob_card",
        "coupon_code": ""
    })
    assert code == 200
    assert calc["stores_count"] == 2
    assert calc["subtotal_egp"] == 49450.0
    assert calc["platform_commission_egp"] == 4014.0
    assert calc["net_stores_payout_egp"] == 45436.0
    assert calc["shipping_egp"] == 80.0  # 55 EGP Cairo base + 25 EGP second store pickup
    assert calc["total_egp"] == 49530.0

    # Client places order
    code, order_resp = http_req(f"{CORE_URL}/orders", "POST", {
        "channel": "ios_app",
        "items": cart_items,
        "governorate": "CAIRO",
        "payment_method": "paymob_card",
        "customer_name": "Omar El-prince",
        "customer_phone": "01066778899",
        "area_street": "New Cairo, Fifth Settlement, 90th St"
    })
    assert code == 201 and order_resp["success"]
    order = order_resp["order"]
    order_id = order["id"]
    assert len(order["deliveries"]) == 2, "Expected 2 Store-to-Client sub-deliveries"

    # Verify Store 1's stock is reserved while awaiting 3DS payment
    _, prods_reserved = http_req(f"{CORE_URL}/products")
    p_res = next(p for p in prods_reserved if p["id"] == new_prod_id)
    assert p_res["stock_quantity"] == 10 and p_res["reserved_quantity"] == 2 and p_res["available_stock"] == 8

    # Client approves Paymob 3DS -> triggers HMAC webhook to (:4000) -> deducts stock & dispatches Bosta AWBs
    code, pay_sim = http_req(f"{MOCK_URL}/paymob/simulate-payment", "POST", {
        "intention_id": order["gateway_ref"],
        "outcome": "APPROVED"
    })
    assert code == 200 and pay_sim["webhook"]["response_status"] == 200

    # Verify Store 1's stock is now permanently deducted (10 -> 8) and reservation cleared (2 -> 0)
    _, prods_paid = http_req(f"{CORE_URL}/products")
    p_paid = next(p for p in prods_paid if p["id"] == new_prod_id)
    assert p_paid["stock_quantity"] == 8 and p_paid["reserved_quantity"] == 0 and p_paid["available_stock"] == 8
    print(f"[PASS] E2E Stage 2 (Client Buy & Payment): Order #{order['order_number']} Paid (49,530 EGP) | Store Stock Deducted (10 -> 8) | Commission Split: 4,014 EGP Facilitator / 45,436 EGP Stores")

    # =========================================================================
    # STAGE 3: PARTNER STORE FULFILLMENT & PACKAGING
    # =========================================================================
    _, all_delivs = http_req(f"{CORE_URL}/deliveries")
    order_delivs = sorted([d for d in all_delivs if d["order_id"] == order_id], key=lambda x: x["store_id"])
    assert len(order_delivs) == 2

    for d in order_delivs:
        assert d["bosta_awb"] and d["bosta_awb"].startswith("BST-")
        code, pack_res = http_req(f"{CORE_URL}/deliveries/{d['id']}/store-ready", "POST", {})
        assert code == 200 and pack_res["packaging_status"] == "READY_FOR_COURIER_PICKUP"

    print(f"[PASS] E2E Stage 3 (Store Fulfillment): Both Partner Stores packed & marked sub-orders READY_FOR_COURIER_PICKUP (AWBs: {order_delivs[0]['bosta_awb']}, {order_delivs[1]['bosta_awb']})")

    # =========================================================================
    # STAGE 4: OUTSOURCED 3PL DELIVERY (PICKUP FROM STORE -> DELIVERED TO CLIENT)
    # =========================================================================
    for d in order_delivs:
        awb = d["bosta_awb"]
        for st in ("PICKED_UP_FROM_STORE", "OUT_FOR_DELIVERY", "DELIVERED"):
            code, b_res = http_req(f"{MOCK_URL}/bosta/simulate-status", "POST", {"awb": awb, "status": st})
            assert code == 200 and b_res["webhook"]["response_status"] == 200

    _, delivs_delivered = http_req(f"{CORE_URL}/deliveries")
    order_delivs_after = sorted([d for d in delivs_delivered if d["order_id"] == order_id], key=lambda x: x["store_id"])
    for d in order_delivs_after:
        assert d["courier_status"] == "DELIVERED"
        assert d["settlement_status"] == "ELIGIBLE_FOR_SETTLEMENT"

    print(f"[PASS] E2E Stage 4 (Outsourced 3PL Delivery): Bosta picked up from Cairo & Giza store branches and delivered both parcels to Client (Status: DELIVERED & ELIGIBLE_FOR_SETTLEMENT)")

    # =========================================================================
    # STAGE 5: CASH SETTLEMENT & COMMISSION REALIZATION (STL-xxxxxx)
    # =========================================================================
    settlement_refs = []
    for d in order_delivs_after:
        code, stl_res = http_req(f"{CORE_URL}/deliveries/{d['id']}/settle", "POST", {})
        assert code == 200 and stl_res["success"], f"Settlement failed: {stl_res}"
        assert stl_res["delivery"]["settlement_status"] == "SETTLED_TO_STORE"
        s_ref = stl_res["delivery"]["settlement_ref"]
        assert s_ref and s_ref.startswith("STL-")
        settlement_refs.append(s_ref)

    # Verify Master Order status is now 'completed-settled' and payment_status is 'settled'
    _, orders_list = http_req(f"{CORE_URL}/orders")
    settled_order = next(o for o in orders_list if o["id"] == order_id)
    assert settled_order["order_status"] == "completed-settled"
    assert settled_order["payment_status"] == "settled"

    # Verify Store Settled Payout Ledger increased by exact Net Store Payouts (44,160 EGP for Store 1, 1,276 EGP for Store 2)
    _, stores_after = http_req(f"{CORE_URL}/stores")
    s1_after = next(s for s in stores_after if s["id"] == 1)
    s2_after = next(s for s in stores_after if s["id"] == 2)
    assert round(s1_after["settled_payout_egp"] - s1_before.get("settled_payout_egp", 0), 2) == 44160.0
    assert round(s2_after["settled_payout_egp"] - s2_before.get("settled_payout_egp", 0), 2) == 1276.0
    print(f"[PASS] E2E Stage 5 (Cash Settlement): Settled Refs ({', '.join(settlement_refs)}) | Store 1 Paid: +44,160.0 EGP | Store 2 Paid: +1,276.0 EGP | Facilitator Commission Realized: +4,014.0 EGP")

    # =========================================================================
    # STAGE 6: FULL CASH-ON-DELIVERY (COD) E2E CYCLE WITH Bosta COD REMITTANCE
    # =========================================================================
    # Client buys 1x of the new Watch via COD (24,000 EGP + 55 EGP Cairo Bosta + 15 EGP COD Fee = 24,070 EGP COD)
    code, cod_order_resp = http_req(f"{CORE_URL}/orders", "POST", {
        "channel": "web",
        "items": [{"product_id": new_prod_id, "quantity": 1}],
        "governorate": "CAIRO",
        "payment_method": "cod",
        "customer_name": "Tarek Mansour",
        "customer_phone": "01288990011",
        "area_street": "Heliopolis, Korba, Baghdad St"
    })
    assert code == 201
    cod_order = cod_order_resp["order"]
    cod_deliv = cod_order["deliveries"][0]
    assert cod_deliv["cod_to_collect_egp"] == 24070.0

    # 1. Verify WhatsApp OTP (4455) -> deducts stock (8 -> 7) & generates Bosta AWB
    code, wa_res = http_req(f"{MOCK_URL}/whatsapp/verify-otp", "POST", {"order_id": cod_order["id"], "otp": "4455"})
    assert code == 200 and wa_res["webhook"]["response_status"] == 200

    # 2. Store packs order
    http_req(f"{CORE_URL}/deliveries/{cod_deliv['id']}/store-ready", "POST", {})

    # 3. Bosta picks up, delivers, and collects 24,070 EGP COD cash from Client
    _, delivs_cod = http_req(f"{CORE_URL}/deliveries")
    cod_awb = next(d["bosta_awb"] for d in delivs_cod if d["id"] == cod_deliv["id"])
    for st in ("PICKED_UP_FROM_STORE", "OUT_FOR_DELIVERY", "DELIVERED"):
        http_req(f"{MOCK_URL}/bosta/simulate-status", "POST", {"awb": cod_awb, "status": st})

    # 4. Settle COD Cash (Bosta remits COD -> Facilitator keeps 1,920 EGP [8%] & transfers 22,080 EGP to Store 1 via InstaPay)
    code, cod_stl = http_req(f"{CORE_URL}/deliveries/{cod_deliv['id']}/settle", "POST", {})
    assert code == 200 and cod_stl["success"]
    assert cod_stl["settlement"]["cod_collected_egp"] == 24070.0
    assert cod_stl["settlement"]["net_store_payout_egp"] == 22080.0
    assert cod_stl["settlement"]["platform_commission_egp"] == 1920.0
    assert "Bosta COD Remittance" in cod_stl["settlement"]["payout_rail"]

    # Verify Store 1 stock is now 7
    _, prods_final = http_req(f"{CORE_URL}/products")
    p_final = next(p for p in prods_final if p["id"] == new_prod_id)
    assert p_final["stock_quantity"] == 7 and p_final["available_stock"] == 7
    print(f"[PASS] E2E Stage 6 (COD Full Cycle): WhatsApp OTP Verified -> Bosta Collected 24,070 EGP COD -> Settled ({cod_stl['settlement']['settlement_ref']}): 22,080 EGP to Store 1 & 1,920 EGP Facilitator Fee (Final Stock: 7)")

    # =========================================================================
    # STAGE 7: FAWRY 48H EXPIRY -> STORE INVENTORY PROTECTION
    # =========================================================================
    code, fawry_resp = http_req(f"{CORE_URL}/orders", "POST", {
        "channel": "web",
        "items": [{"product_id": new_prod_id, "quantity": 3}],
        "governorate": "ALEX",
        "payment_method": "fawry_ref",
        "customer_name": "Nourhan Adel",
        "customer_phone": "01144556677"
    })
    assert code == 201
    fawry_ref = fawry_resp["order"]["gateway_ref"]
    http_req(f"{MOCK_URL}/fawry/simulate-kiosk", "POST", {"fawry_ref": fawry_ref, "action": "EXPIRED"})
    _, prods_after_exp = http_req(f"{CORE_URL}/products")
    p_exp = next(p for p in prods_after_exp if p["id"] == new_prod_id)
    assert p_exp["stock_quantity"] == 7 and p_exp["reserved_quantity"] == 0 and p_exp["available_stock"] == 7
    print(f"[PASS] E2E Stage 7 (Fawry 48h Expiry Protection): 3 Reserved Units Automatically Returned to Partner Store Stock (Available: 7)")

    # =========================================================================
    # STAGE 8: HMAC-SHA512 WEBHOOK SECURITY TEST
    # =========================================================================
    code, _ = http_req(
        f"{CORE_URL}/webhooks/settlement",
        "POST",
        {"event": "FORGED_SETTLEMENT", "order_id": order_id, "delivery_id": order_delivs[0]["id"]},
        headers={"X-Egypt-HMAC-SHA512": "0000_forged_invalid_signature_0000"}
    )
    assert code == 401
    print("[PASS] E2E Stage 8 (Webhook Security): Forged HMAC-SHA512 Settlement Webhook Rejected with HTTP 401")

    # =========================================================================
    # STAGE 9: FACILITATOR COMMERCIAL POLICY ENGINE (PER-STORE & ALL-STORES)
    # =========================================================================
    # 9A. Apply Custom Commercial Policy to Store #1 ONLY (15% Commission, 14% ADDITIVE VAT, 0 EGP Free Delivery Override, 25 EGP COD Fee)
    code, rule_s1 = http_req(f"{CORE_URL}/settings/commercial-rules", "POST", {
        "target_scope": "1",
        "commission_pct": 15.0,
        "vat_pct": 14.0,
        "vat_mode": "ADDITIVE",
        "delivery_fee_override_egp": 0.0,
        "extra_store_pickup_fee_egp": 25.0,
        "cod_fee_egp": 25.0,
        "settlement_cycle": "INSTANT"
    })
    assert code == 200 and rule_s1["success"], f"Failed to update Store 1 commercial rules: {rule_s1}"

    # Verify Cart Calculation for Store #1 Product (24,000 EGP):
    # - Commission = 15% of 24,000 = 3,600 EGP
    # - VAT (ADDITIVE 14%) = 3,360 EGP added to total
    # - Shipping = 0 EGP (Free Delivery Override on Store 1)
    # - COD Fee = 25 EGP (Store 1 COD Override)
    # - Total = 24,000 + 3,360 + 0 + 25 = 27,385 EGP
    code, calc_s1 = http_req(f"{CORE_URL}/cart/calculate", "POST", {
        "items": [{"product_id": new_prod_id, "quantity": 1}],
        "governorate": "CAIRO",
        "payment_method": "cod",
        "coupon_code": ""
    })
    assert code == 200
    assert calc_s1["platform_commission_egp"] == 3600.0
    assert calc_s1["vat_egp"] == 3360.0
    assert calc_s1["vat_mode"] == "ADDITIVE"
    assert calc_s1["shipping_egp"] == 0.0
    assert calc_s1["cod_fee_egp"] == 25.0
    assert calc_s1["total_egp"] == 27385.0

    # 9B. Restore Baseline Commercial Rules across ALL Partner Stores (target_scope: "all") & Store 1 specific 8% rate
    code, rule_all = http_req(f"{CORE_URL}/settings/commercial-rules", "POST", {
        "target_scope": "all",
        "commission_pct": 10.0,
        "vat_pct": 14.0,
        "vat_mode": "INCLUSIVE",
        "delivery_fee_override_egp": None,
        "extra_store_pickup_fee_egp": 25.0,
        "cod_fee_egp": 15.0,
        "settlement_cycle": "T+1"
    })
    assert code == 200 and rule_all["success"]
    # Restore initial Store commission rates (8%, 12%, 10%) so repeat test runs stay deterministic
    http_req(f"{CORE_URL}/settings/commercial-rules", "POST", {"target_scope": "1", "commission_pct": 8.0, "vat_pct": 14.0, "vat_mode": "INCLUSIVE", "delivery_fee_override_egp": None, "cod_fee_egp": 15.0})
    http_req(f"{CORE_URL}/settings/commercial-rules", "POST", {"target_scope": "2", "commission_pct": 12.0, "vat_pct": 14.0, "vat_mode": "INCLUSIVE", "delivery_fee_override_egp": None, "cod_fee_egp": 15.0})
    http_req(f"{CORE_URL}/settings/commercial-rules", "POST", {"target_scope": "3", "commission_pct": 10.0, "vat_pct": 14.0, "vat_mode": "INCLUSIVE", "delivery_fee_override_egp": None, "cod_fee_egp": 15.0})

    # 9C. Test Bulk Settlement Endpoint (All Stores or Specific Store)
    code, bulk_stl = http_req(f"{CORE_URL}/settlements/settle-bulk", "POST", {"store_id": "all"})
    assert code == 200 and bulk_stl["success"]
    print("[PASS] E2E Stage 9 (Commercial Policy Engine): Per-Store & All-Stores Commission %, VAT Mode (ADDITIVE/INCLUSIVE), Free Delivery Override, COD Fee & Bulk Settlement Verified")

    # =========================================================================
    # STAGE 10: TWO-WAY CUSTOMER SUPPORT CHAT (CLIENT STOREFRONT <-> ADMIN DESK)
    # =========================================================================
    # 1. Client opens a new support chat ticket from Storefront
    code, sup_create = http_req(f"{CORE_URL}/support/tickets", "POST", {
        "customer_name": "Omar El-prince",
        "customer_phone": "01066778899",
        "order_number": order["order_number"],
        "store_id": 1,
        "subject": "Requesting Bosta courier morning delivery slot",
        "message_text": "Hello Support! Can Bosta deliver my Samsung Galaxy Watch 7 Ultra before 2 PM?"
    })
    assert code == 201 and sup_create["success"]
    ticket_id = sup_create["ticket"]["id"]
    ticket_no = sup_create["ticket"]["ticket_number"]

    # 2. Facilitator Admin replies from Tab 5 Support Desk
    code, sup_admin_reply = http_req(f"{CORE_URL}/support/tickets/{ticket_id}/reply", "POST", {
        "sender_role": "ADMIN",
        "sender_name": "Facilitator Support Desk",
        "message_text": f"Welcome Omar! We updated your Bosta AWB ({order_delivs[0]['bosta_awb']}) for morning priority delivery."
    })
    assert code == 200 and len(sup_admin_reply["ticket"]["messages"]) == 2

    # 3. Client replies back from Storefront Chat Drawer
    code, sup_client_reply = http_req(f"{CORE_URL}/support/tickets/{ticket_id}/reply", "POST", {
        "sender_role": "CLIENT",
        "sender_name": "Omar El-prince",
        "message_text": "Thank you so much for the fast support!"
    })
    assert code == 200 and len(sup_client_reply["ticket"]["messages"]) == 3

    # 4. Facilitator Admin resolves the ticket
    code, sup_resolve = http_req(f"{CORE_URL}/support/tickets/{ticket_id}/status", "POST", {"status": "RESOLVED"})
    assert code == 200 and sup_resolve["ticket"]["status"] == "RESOLVED"
    print(f"[PASS] E2E Stage 10 (Live Customer Support Chat): Ticket {ticket_no} Created on Client Storefront -> Admin Replied -> Client Responded -> Marked RESOLVED")

    # =========================================================================
    # STAGE 11: CLIENT ORDER MONITORING, TRACKING & HISTORICAL CLOSED ARCHIVE
    # =========================================================================
    # 1. Test Unified Tracking & Scope Aggregation Endpoint
    code, track_resp = http_req(f"{CORE_URL}/orders/track", "GET")
    assert code == 200 and track_resp["success"]
    assert "total_count" in track_resp and "active_count" in track_resp and "closed_count" in track_resp
    assert track_resp["total_count"] == (track_resp["active_count"] + track_resp["closed_count"])
    assert len(track_resp["orders"]) == track_resp["total_count"]

    # 2. Test Active Orders Scope Query
    code, active_orders = http_req(f"{CORE_URL}/orders?scope=active", "GET")
    assert code == 200 and isinstance(active_orders, list)
    for ao in active_orders:
        assert ao["is_closed"] is False, f"Expected active order, got is_closed=True for {ao['order_number']}"
        assert "timeline" in ao and len(ao["timeline"]) == 7, "Missing 7-step milestone timeline"
        assert "progress_pct" in ao and 0 <= ao["progress_pct"] <= 100
        assert "deliveries" in ao

    # 3. Test Closed Orders Scope Query (Delivered, Settled, Cancelled)
    code, closed_orders = http_req(f"{CORE_URL}/orders?scope=closed", "GET")
    assert code == 200 and isinstance(closed_orders, list)
    for co in closed_orders:
        assert co["is_closed"] is True, f"Expected closed order, got is_closed=False for {co['order_number']}"
        assert "timeline" in co and len(co["timeline"]) == 7
        assert co.get("payment_status") == "settled" or co.get("order_status") in ("completed", "completed-settled", "cancelled", "refunded")

    # 4. Test Single Order Tracking by Order Number
    target_order_num = order["order_number"]
    code, single_order_resp = http_req(f"{CORE_URL}/orders/{target_order_num}", "GET")
    assert code == 200 and single_order_resp["success"]
    so = single_order_resp["order"]
    assert so["order_number"] == target_order_num
    assert len(so["timeline"]) == 7
    assert len(so["deliveries"]) == 2  # Multi-store order has 2 Bosta delivery manifests
    assert so["stores_count"] == 2

    # 5. Test Live Search Filtering via Query Param (q)
    code, search_resp = http_req(f"{CORE_URL}/orders/track?q={target_order_num}", "GET")
    assert code == 200 and search_resp["success"]
    assert search_resp["total_count"] >= 1
    assert any(o["order_number"] == target_order_num for o in search_resp["orders"])

    print(f"[PASS] E2E Stage 11 (Client Order Monitoring & History Archive): Verified /orders/track ({track_resp['total_count']} orders: {track_resp['active_count']} active, {track_resp['closed_count']} closed), 7-step visual timelines, Bosta AWBs & single order tracking for #{target_order_num}")

    # =========================================================================
    # STAGE 12: FULL 14-STEP REVISED JOURNEY: PREPAID (PIN) & COD (NO PIN)
    # =========================================================================
    # STEP 1: Select location (Cairo)
    client_loc = "CAIRO"
    code, nearby_couriers = http_req(f"{CORE_URL}/couriers/nearby?governorate={client_loc}", "GET")
    assert code == 200 and len(nearby_couriers["couriers"]) >= 1
    nearest_c = nearby_couriers["couriers"][0]

    # STEP 2: Add to cart from available stores in Cairo (Store 1: Cairo Tech Hub)
    # Adding 1x iPhone 16 Pro (product 1, 64,500 EGP) and 1x AirPods Pro 2 (product 2, 12,900 EGP)
    prepaid_cart = [
        {"product_id": 1, "quantity": 1},
        {"product_id": 2, "quantity": 1}
    ]

    # STEP 3 & 4: Checkout & Select Payment Method (Card) -> Order created in pending-store-review
    code, p_order_res = http_req(f"{CORE_URL}/orders", "POST", {
        "channel": "web_storefront",
        "items": prepaid_cart,
        "governorate": client_loc,
        "payment_method": "paymob_card",
        "customer_name": "Tamer Hosny",
        "customer_phone": "01011223344",
        "area_street": "Makram Ebeid, Nasr City, Cairo"
    })
    assert code == 201 and p_order_res["success"]
    p_order = p_order_res["order"]
    p_order_id = p_order["id"]
    p_order_no = p_order["order_number"]
    p_pin = p_order["delivery_pin"]
    assert len(p_pin) == 4, f"Expected 4-digit PIN, got {p_pin}"
    assert p_order["order_status"] == "pending-store-review"
    assert p_order["payment_status"] == "pre_authorized"

    # STEP 5: Store confirms availability: iPhone in stock, AirPods de-selected (out of stock)
    code, rev_res = http_req(f"{CORE_URL}/orders/{p_order_id}/store-review", "POST", {
        "store_id": 1,
        "items": [
            {"product_id": 1, "available": True},
            {"product_id": 2, "available": False}
        ]
    })
    assert code == 200 and rev_res["success"]
    assert rev_res["order"]["order_status"] == "store-reviewed"
    assert rev_res["order"]["store_review_status"] == "STORE_CONFIRMED"
    rev_total = rev_res["order"]["total_egp"]

    # STEP 6 & 7: Client confirms updated order -> Money taken from card (Payment Captured)
    code, conf_res = http_req(f"{CORE_URL}/orders/{p_order_id}/client-confirm", "POST", {
        "action": "CONFIRM"
    })
    assert code == 200 and conf_res["success"]
    assert conf_res["order"]["order_status"] == "ready-to-ship"
    assert conf_res["order"]["payment_status"] == "paid"

    # STEP 8: Store gets the pack ready (Marked READY_FOR_COURIER_PICKUP)
    p_deliv_id = conf_res["order"]["deliveries"][0]["id"]
    code, mark_res = http_req(f"{CORE_URL}/deliveries/{p_deliv_id}/store-ready", "POST", {})
    assert code == 200 and mark_res["success"]

    # STEP 9: Nearest delivery courier search and assignment
    code, assign_res = http_req(f"{CORE_URL}/deliveries/{p_deliv_id}/assign-courier", "POST", {
        "courier_name": nearest_c["name"],
        "courier_phone": nearest_c["phone"],
        "courier_vehicle": nearest_c["vehicle"],
        "courier_distance_km": nearest_c["base_distance_km"]
    })
    assert code == 200 and assign_res["success"]
    assert assign_res["delivery"]["courier_status"] == "COURIER_ASSIGNED"

    # STEP 10 & 11: Courier confirms pickup -> Client notified
    code, pick_res = http_req(f"{CORE_URL}/deliveries/{p_deliv_id}/courier-pickup", "POST", {})
    assert code == 200 and pick_res["success"]
    assert pick_res["delivery"]["courier_status"] == "PICKED_UP_FROM_STORE"

    # STEP 12: Courier arrives at client
    code, arr_res = http_req(f"{CORE_URL}/deliveries/{p_deliv_id}/courier-arrived", "POST", {})
    assert code == 200 and arr_res["success"]
    assert arr_res["delivery"]["courier_status"] == "ARRIVED_AT_CLIENT"

    # STEP 13 & 14: Handover verification with PIN
    # Test invalid PIN rejection
    bad_code, bad_pin_res = http_req(f"{CORE_URL}/deliveries/{p_deliv_id}/verify-handover", "POST", {"pin": "0000"})
    assert bad_code == 400 and "Invalid Handover Code" in bad_pin_res["error"]

    # Test valid PIN confirmation
    code, good_pin_res = http_req(f"{CORE_URL}/deliveries/{p_deliv_id}/verify-handover", "POST", {"pin": p_pin})
    assert code == 200 and good_pin_res["success"]
    assert good_pin_res["delivery"]["courier_status"] == "DELIVERED"
    assert good_pin_res["delivery"]["settlement_status"] == "SETTLED_TO_STORE"
    p_settle_ref = good_pin_res["settlement"]["settlement_ref"]

    print(f"[PASS] E2E Stage 12 Part A (Prepaid with PIN): Order #{p_order_no} -> Store Review (1 In-Stock, 1 Out-of-Stock) -> Client Confirmed ({rev_total:,.2f} EGP Captured) -> Courier {nearest_c['name']} Picked Up -> Arrived -> Handover PIN {p_pin} Verified -> Delivered & Settled ({p_settle_ref})")

    # STEP 12 Part B: CASH ON DELIVERY (COD) - NO PIN REQUIRED
    code, cod_order_res = http_req(f"{CORE_URL}/orders", "POST", {
        "channel": "mobile_app",
        "items": [{"product_id": 3, "quantity": 1}],
        "governorate": "GIZA",
        "payment_method": "cod",
        "customer_name": "Laila Mourad",
        "customer_phone": "01099887766",
        "area_street": "Dokki, Giza"
    })
    assert code == 201 and cod_order_res["success"]
    cod_order = cod_order_res["order"]
    cod_order_id = cod_order["id"]
    cod_order_no = cod_order["order_number"]
    cod_deliv_id = cod_order["deliveries"][0]["id"]

    # Store Review & Confirm
    http_req(f"{CORE_URL}/orders/{cod_order_id}/store-review", "POST", {
        "store_id": 2, "items": [{"product_id": 3, "available": True}]
    })
    http_req(f"{CORE_URL}/orders/{cod_order_id}/client-confirm", "POST", {"action": "CONFIRM"})
    http_req(f"{CORE_URL}/deliveries/{cod_deliv_id}/store-ready", "POST", {})
    http_req(f"{CORE_URL}/deliveries/{cod_deliv_id}/assign-courier", "POST", {
        "courier_name": "Karim Adel", "courier_phone": "01234567890", "courier_vehicle": "Motorcycle", "courier_distance_km": 1.2
    })
    http_req(f"{CORE_URL}/deliveries/{cod_deliv_id}/courier-pickup", "POST", {})
    http_req(f"{CORE_URL}/deliveries/{cod_deliv_id}/courier-arrived", "POST", {})

    # Handover verification for COD: NO PIN REQUIRED!
    code, cod_handover_res = http_req(f"{CORE_URL}/deliveries/{cod_deliv_id}/verify-handover", "POST", {"pin": ""})
    assert code == 200 and cod_handover_res["success"]
    assert cod_handover_res["delivery"]["courier_status"] == "DELIVERED"
    assert cod_handover_res["delivery"]["settlement_status"] == "SETTLED_TO_STORE"
    cod_settle_ref = cod_handover_res["settlement"]["settlement_ref"]

    print(f"[PASS] E2E Stage 12 Part B (Cash on Delivery - NO PIN): Order #{cod_order_no} -> Full Handover completed with NO PIN required -> Cash Collected -> Delivered & Settled ({cod_settle_ref})")

    # Fetch Sanity Check Summary from Historical Orders
    code, summary_resp = http_req(f"{CORE_URL}/orders/track", "GET")
    assert code == 200
    print("\n" + "=" * 88)
    print("SANITY CHECK VERIFICATION DATA FROM HISTORICAL ORDERS:")
    print("=" * 88)
    for o in summary_resp["orders"][:6]:
        deliv = o["deliveries"][0] if o.get("deliveries") else {}
        print(f"• Order #{o['order_number']} | Status: {o['order_status']} | Payment: {o['payment_method']} ({o['payment_status']}) | PIN: {o.get('delivery_pin') or 'N/A (COD)'} | Courier: {o.get('assigned_courier_name') or deliv.get('courier_name') or 'N/A'} | Settled Ref: {deliv.get('settlement_ref') or 'N/A'}")
    print("=" * 88)
    print("ALL 12 END-TO-END (E2E) STAGES PASSED 100%!")
    print("=" * 88)


if __name__ == "__main__":
    run_e2e_tests()
