#!/usr/bin/env python3
"""
Core E-Commerce Marketplace Facilitator PoC Server (Port 4000)
Business Model:
  - Zero-Inventory Marketplace connecting Partner Stores' Inventory to Clients
  - First-class Product Categories (wc_categories)
  - Partner Store Portal (wc_stores + store-owned inventory + commission split)
  - Outsourced Delivery Hub (wc_deliveries: Bosta picks up from Partner Store -> delivers to Client)
"""

import hashlib
import hmac
import json
import os
import random
import socket
import sqlite3
import tempfile
import urllib.request
import urllib.error
import urllib.parse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 4000
MOCK_SERVER_URL = "http://127.0.0.1:4001"
SHARED_HMAC_SECRET = "egypt_poc_hmac_secret_2026"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(tempfile.gettempdir(), "ecommerce_hpos.db") if os.environ.get("VERCEL") else os.path.join(BASE_DIR, "ecommerce_hpos.db")
INDEX_HTML_PATH = os.path.join(BASE_DIR, "poc_ui.html")
STUDY_HTML_PATH = os.path.join(BASE_DIR, "study.html")
_DB_INITIALIZED = False


class DualStackHTTPServer(ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


def now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def get_db(skip_auto_init: bool = False) -> sqlite3.Connection:
    global _DB_INITIALIZED
    if not _DB_INITIALIZED and not skip_auto_init:
        _DB_INITIALIZED = True
        init_db()
    conn = sqlite3.connect(DB_PATH, timeout=30.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn


def init_db():
    global _DB_INITIALIZED
    _DB_INITIALIZED = True
    conn = get_db(skip_auto_init=True)
    cur = conn.cursor()

    # Check if we need to migrate/re-initialize for the new multi-store + categories schema
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='wc_stores'")
    if not cur.fetchone():
        cur.executescript("""
        DROP TABLE IF EXISTS wc_products;
        DROP TABLE IF EXISTS wc_orders;
        DROP TABLE IF EXISTS wc_order_items;
        DROP TABLE IF EXISTS wc_deliveries;
        DROP TABLE IF EXISTS wc_categories;
        DROP TABLE IF EXISTS wc_stores;
        """)

    cur.executescript("""
    CREATE TABLE IF NOT EXISTS wc_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT UNIQUE NOT NULL,
        name_en TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        icon_emoji TEXT DEFAULT '🏷️',
        description_en TEXT
    );

    CREATE TABLE IF NOT EXISTS wc_stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name_en TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        governorate TEXT NOT NULL,
        pickup_address TEXT NOT NULL,
        contact_phone TEXT NOT NULL,
        commission_pct REAL NOT NULL DEFAULT 10.0,
        rating REAL NOT NULL DEFAULT 4.8,
        active INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS wc_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT UNIQUE NOT NULL,
        store_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        name_en TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        category TEXT NOT NULL,
        price_egp REAL NOT NULL,
        stock_quantity INTEGER NOT NULL DEFAULT 20,
        reserved_quantity INTEGER NOT NULL DEFAULT 0,
        image_emoji TEXT DEFAULT '📦',
        valu_eligible INTEGER DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS wc_governorates (
        code TEXT PRIMARY KEY,
        name_en TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        shipping_egp REAL NOT NULL,
        sla_days TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        channel TEXT NOT NULL DEFAULT 'web',
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        customer_email TEXT,
        governorate TEXT NOT NULL,
        area_street TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        payment_title TEXT NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'pending',
        order_status TEXT NOT NULL DEFAULT 'pending',
        subtotal_egp REAL NOT NULL,
        discount_egp REAL NOT NULL DEFAULT 0,
        shipping_egp REAL NOT NULL,
        cod_fee_egp REAL NOT NULL DEFAULT 0,
        total_egp REAL NOT NULL,
        platform_commission_egp REAL NOT NULL DEFAULT 0,
        net_stores_payout_egp REAL NOT NULL DEFAULT 0,
        coupon_code TEXT,
        gateway_ref TEXT,
        gateway_meta TEXT,
        bosta_awb TEXT,
        bosta_status TEXT DEFAULT 'NOT_DISPATCHED',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        store_id INTEGER NOT NULL,
        store_name TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        sku TEXT NOT NULL,
        name_en TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price_egp REAL NOT NULL,
        line_total_egp REAL NOT NULL,
        commission_pct REAL NOT NULL,
        platform_commission_egp REAL NOT NULL,
        net_store_payout_egp REAL NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        order_number TEXT NOT NULL,
        store_id INTEGER NOT NULL,
        store_name TEXT NOT NULL,
        store_phone TEXT NOT NULL,
        pickup_governorate TEXT NOT NULL,
        pickup_address TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        dropoff_governorate TEXT NOT NULL,
        dropoff_address TEXT NOT NULL,
        items_summary TEXT NOT NULL,
        store_subtotal_egp REAL NOT NULL,
        platform_commission_egp REAL NOT NULL,
        net_store_payout_egp REAL NOT NULL,
        cod_to_collect_egp REAL NOT NULL DEFAULT 0,
        packaging_status TEXT NOT NULL DEFAULT 'AWAITING_STORE_PACKAGING',
        courier_provider TEXT NOT NULL DEFAULT 'Bosta 3PL',
        bosta_awb TEXT,
        courier_status TEXT NOT NULL DEFAULT 'AWAITING_PAYMENT',
        settlement_status TEXT NOT NULL DEFAULT 'UNSETTLED',
        settlement_ref TEXT,
        settled_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        settlement_ref TEXT UNIQUE NOT NULL,
        delivery_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        order_number TEXT NOT NULL,
        store_id INTEGER NOT NULL,
        store_name TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        bosta_awb TEXT,
        gross_amount_egp REAL NOT NULL,
        platform_commission_egp REAL NOT NULL,
        net_store_payout_egp REAL NOT NULL,
        cod_collected_egp REAL NOT NULL DEFAULT 0,
        payout_rail TEXT NOT NULL,
        created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_webhooks_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        direction TEXT NOT NULL,
        provider TEXT NOT NULL,
        event_name TEXT NOT NULL,
        hmac_verified INTEGER NOT NULL DEFAULT 1,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_push_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        target_platform TEXT NOT NULL,
        title_en TEXT NOT NULL,
        body_en TEXT NOT NULL,
        body_ar TEXT NOT NULL,
        created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_platform_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        default_commission_pct REAL NOT NULL DEFAULT 10.0,
        default_vat_pct REAL NOT NULL DEFAULT 14.0,
        vat_mode TEXT NOT NULL DEFAULT 'INCLUSIVE',
        extra_store_pickup_fee_egp REAL NOT NULL DEFAULT 25.0,
        cod_fee_egp REAL NOT NULL DEFAULT 15.0,
        default_settlement_cycle TEXT NOT NULL DEFAULT 'T+1 InstaPay / Paymob Split',
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_support_tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_number TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        order_number TEXT,
        store_id INTEGER,
        subject TEXT NOT NULL,
        channel TEXT NOT NULL DEFAULT 'web_chat',
        status TEXT NOT NULL DEFAULT 'OPEN',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wc_support_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id INTEGER NOT NULL,
        sender_role TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        message_text TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    """)

    # Ensure existing DB has settlement columns on wc_deliveries
    deliv_cols = [r["name"] for r in cur.execute("PRAGMA table_info(wc_deliveries)").fetchall()]
    if "settlement_status" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN settlement_status TEXT NOT NULL DEFAULT 'UNSETTLED'")
    if "settlement_ref" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN settlement_ref TEXT")
    if "settled_at" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN settled_at TEXT")

    # Ensure existing DB has per-store commercial policy columns on wc_stores
    store_cols = [r["name"] for r in cur.execute("PRAGMA table_info(wc_stores)").fetchall()]
    if "vat_pct" not in store_cols:
        cur.execute("ALTER TABLE wc_stores ADD COLUMN vat_pct REAL NOT NULL DEFAULT 14.0")
    if "delivery_fee_override_egp" not in store_cols:
        cur.execute("ALTER TABLE wc_stores ADD COLUMN delivery_fee_override_egp REAL DEFAULT NULL")
    if "cod_fee_override_egp" not in store_cols:
        cur.execute("ALTER TABLE wc_stores ADD COLUMN cod_fee_override_egp REAL DEFAULT NULL")
    if "settlement_cycle" not in store_cols:
        cur.execute("ALTER TABLE wc_stores ADD COLUMN settlement_cycle TEXT NOT NULL DEFAULT 'T+1 InstaPay / Paymob Split'")

    # Ensure existing DB has vat_egp column on wc_orders
    ord_cols = [r["name"] for r in cur.execute("PRAGMA table_info(wc_orders)").fetchall()]
    if "vat_egp" not in ord_cols:
        cur.execute("ALTER TABLE wc_orders ADD COLUMN vat_egp REAL NOT NULL DEFAULT 0.0")
    if "delivery_pin" not in ord_cols:
        cur.execute("ALTER TABLE wc_orders ADD COLUMN delivery_pin TEXT")
    if "assigned_courier_name" not in ord_cols:
        cur.execute("ALTER TABLE wc_orders ADD COLUMN assigned_courier_name TEXT")
    if "assigned_courier_phone" not in ord_cols:
        cur.execute("ALTER TABLE wc_orders ADD COLUMN assigned_courier_phone TEXT")
    if "assigned_courier_vehicle" not in ord_cols:
        cur.execute("ALTER TABLE wc_orders ADD COLUMN assigned_courier_vehicle TEXT")
    if "store_review_status" not in ord_cols:
        cur.execute("ALTER TABLE wc_orders ADD COLUMN store_review_status TEXT DEFAULT 'PENDING_STORE_REVIEW'")

    deliv_cols = [r["name"] for r in cur.execute("PRAGMA table_info(wc_deliveries)").fetchall()]
    if "delivery_pin" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN delivery_pin TEXT")
    if "courier_name" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN courier_name TEXT")
    if "courier_phone" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN courier_phone TEXT")
    if "courier_vehicle" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN courier_vehicle TEXT")
    if "courier_distance_km" not in deliv_cols:
        cur.execute("ALTER TABLE wc_deliveries ADD COLUMN courier_distance_km REAL DEFAULT 1.2")

    item_cols = [r["name"] for r in cur.execute("PRAGMA table_info(wc_order_items)").fetchall()]
    if "item_status" not in item_cols:
        cur.execute("ALTER TABLE wc_order_items ADD COLUMN item_status TEXT NOT NULL DEFAULT 'AVAILABLE'")

    # 0. Seed Global Platform Commercial Settings
    cur.execute("SELECT COUNT(*) AS cnt FROM wc_platform_settings")
    if cur.fetchone()["cnt"] == 0:
        cur.execute("""
            INSERT INTO wc_platform_settings (
                id, default_commission_pct, default_vat_pct, vat_mode,
                extra_store_pickup_fee_egp, cod_fee_egp, default_settlement_cycle, updated_at
            ) VALUES (1, 10.0, 14.0, 'INCLUSIVE', 25.0, 15.0, 'T+1 InstaPay / Paymob Split', ?)
        """, (now_iso(),))

    # 1. Seed Product Categories
    cur.execute("SELECT COUNT(*) AS cnt FROM wc_categories")
    if cur.fetchone()["cnt"] == 0:
        categories = [
            ("electronics", "Electronics & Mobile", "إلكترونيات وموبايلات", "📱", "Smartphones, audio, and consumer tech"),
            ("fashion", "Egyptian Fashion & Cotton", "أزياء وملابس قطنية", "🧥", "Local Egyptian streetwear and Giza cotton apparel"),
            ("appliances", "Home & Coffee Appliances", "أجهزة منزلية وماكينات قهوة", "☕", "Kitchen and espresso appliances"),
            ("cosmetics", "Beauty & Skincare", "عناية بالبشرة وتجميل", "✨", "Dermatological serums and cosmetics"),
            ("footwear", "Sports & Footwear", "أحذية وملابس رياضية", "👟", "Running shoes and athletic gear"),
        ]
        cur.executemany("""
            INSERT INTO wc_categories (slug, name_en, name_ar, icon_emoji, description_en)
            VALUES (?, ?, ?, ?, ?)
        """, categories)

    # 2. Seed Partner Stores (Holding their own inventory across Egypt)
    cur.execute("SELECT COUNT(*) AS cnt FROM wc_stores")
    if cur.fetchone()["cnt"] == 0:
        stores = [
            ("STORE-CAIRO-TECH", "Cairo Tech Hub (Nasr City)", "كايرو تيك هب - مدينة نصر", "CAIRO", "Makram Ebeid St, Bldg 22, Nasr City, Cairo", "01001112233", 8.0, 4.9, 1),
            ("STORE-GIZA-COTTON", "Giza Cotton Atelier (Dokki)", "أتيليه قطن الجيزة - الدقي", "GIZA", "Mossadak St, Bldg 10, Dokki, Giza", "01112223344", 12.0, 4.8, 1),
            ("STORE-ALEX-GLOW", "Alex Glow & Home (Smouha)", "الإسكندرية للتجميل والمنزل - سموحة", "ALEX", "Victor Emmanuel Sq, Smouha, Alexandria", "01223334455", 10.0, 4.7, 1),
        ]
        cur.executemany("""
            INSERT INTO wc_stores (code, name_en, name_ar, governorate, pickup_address, contact_phone, commission_pct, rating, active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, stores)

    # 3. Seed Store-Owned Products linked to Categories & Partner Stores
    cur.execute("SELECT COUNT(*) AS cnt FROM wc_products")
    if cur.fetchone()["cnt"] == 0:
        products = [
            ("EG-IPH-16P", 1, 1, "iPhone 16 Pro 256GB (Middle East Version)", "آيفون 16 برو 256 جيجا - نسخة الشرق الأوسط", "Electronics & Mobile", 64500.0, 15, 0, "📱", 1),
            ("EG-AIR-PRO2", 1, 1, "Apple AirPods Pro 2 (USB-C)", "سماعات أبل إيربودز برو 2", "Electronics & Mobile", 11800.0, 25, 0, "🎧", 1),
            ("EG-COT-HOOD", 2, 2, "Egyptian Giza 88 Premium Heavy Cotton Hoodie", "هودي قطن مصري جيزة 88 فاخر", "Egyptian Fashion & Cotton", 1450.0, 50, 0, "🧥", 1),
            ("EG-SNK-RUN", 2, 5, "Nile Stride Ultra-Light Running Sneakers", "حذاء رياضي خفيف للجري", "Sports & Footwear", 2350.0, 30, 0, "👟", 1),
            ("EG-ESP-MAC", 3, 3, "DeLonghi Dedica Espresso Coffee Maker", "ماكينة قهوة ديلونجي ديديكا إسبريسو", "Home & Coffee Appliances", 9200.0, 12, 0, "☕", 1),
            ("EG-SKN-SER", 3, 4, "Cairo Glow Hyaluronic & Vitamin C Serum 50ml", "سيروم فيتامين سي وهيالورونيك للعناية بالبشرة", "Beauty & Skincare", 680.0, 80, 0, "✨", 0),
        ]
        cur.executemany("""
            INSERT INTO wc_products (sku, store_id, category_id, name_en, name_ar, category, price_egp, stock_quantity, reserved_quantity, image_emoji, valu_eligible)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, products)

    # 4. Seed Egyptian Governorates
    cur.execute("SELECT COUNT(*) AS cnt FROM wc_governorates")
    if cur.fetchone()["cnt"] == 0:
        govs = [
            ("CAIRO", "Cairo (القاهرة)", "القاهرة", 55.0, "Next-Day (24h)"),
            ("GIZA", "Giza (الجيزة)", "الجيزة", 55.0, "Next-Day (24h)"),
            ("ALEX", "Alexandria (الإسكندرية)", "الإسكندرية", 70.0, "1-2 Days"),
            ("DAKAHLIA", "Dakahlia - Mansoura (الدقهلية)", "الدقهلية - المنصورة", 75.0, "2 Days"),
            ("GHARBIA", "Gharbia - Tanta (الغربية)", "الغربية - طنطا", 75.0, "2 Days"),
            ("RED_SEA", "Red Sea - Hurghada (البحر الأحمر)", "البحر الأحمر - الغردقة", 95.0, "2-3 Days"),
            ("ASSIUT", "Assiut - Upper Egypt (أسيوط)", "أسيوط - الصعيد", 90.0, "2-3 Days"),
        ]
        cur.executemany("""
            INSERT INTO wc_governorates (code, name_en, name_ar, shipping_egp, sla_days)
            VALUES (?, ?, ?, ?, ?)
        """, govs)

    # 5. Seed Initial Customer Support Live Chat Threads
    cur.execute("SELECT COUNT(*) AS cnt FROM wc_support_tickets")
    if cur.fetchone()["cnt"] == 0:
        ts = now_iso()
        cur.execute("""
            INSERT INTO wc_support_tickets (ticket_number, customer_name, customer_phone, order_number, store_id, subject, channel, status, created_at, updated_at)
            VALUES ('SUP-1001', 'Mariam El-Shazly', '01022334455', 'EG-84373-94', 1, 'Bosta Courier Delivery Window & Apple Pay Receipt', 'web_chat', 'OPEN', ?, ?)
        """, (ts, ts))
        t1_id = cur.lastrowid
        cur.executemany("""
            INSERT INTO wc_support_messages (ticket_id, sender_role, sender_name, message_text, created_at)
            VALUES (?, ?, ?, ?, ?)
        """, [
            (t1_id, "CLIENT", "Mariam El-Shazly", "Hello! Can Bosta deliver my Cairo Tech Hub order after 5 PM today in Nasr City?", ts),
            (t1_id, "ADMIN", "Facilitator Support Desk", "Welcome Mariam! Yes, we updated your Bosta AWB delivery note for evening drop-off (5 PM - 9 PM).", ts)
        ])

        cur.execute("""
            INSERT INTO wc_support_tickets (ticket_number, customer_name, customer_phone, order_number, store_id, subject, channel, status, created_at, updated_at)
            VALUES ('SUP-1002', 'Khaled Ibrahim', '01199887766', '', 2, 'Giza Cotton Hoodie Sizing & valU 12m Plan', 'mobile_app', 'OPEN', ?, ?)
        """, (ts, ts))
        t2_id = cur.lastrowid
        cur.execute("""
            INSERT INTO wc_support_messages (ticket_id, sender_role, sender_name, message_text, created_at)
            VALUES (?, 'CLIENT', 'Khaled Ibrahim', 'Is the Giza 88 Cotton Hoodie oversized fit, and can I combine it with items from Alex Glow in one valU plan?', ?)
        """, (t2_id, ts))

    conn.commit()
    conn.close()


def log_webhook(direction: str, provider: str, event_name: str, hmac_verified: int, payload: dict):
    conn = get_db()
    conn.execute("""
        INSERT INTO wc_webhooks_log (direction, provider, event_name, hmac_verified, payload_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (direction, provider, event_name, hmac_verified, json.dumps(payload, ensure_ascii=False), now_iso()))
    conn.commit()
    conn.close()


def send_push_notification(order_id: int, platform: str, title_en: str, body_en: str, body_ar: str):
    conn = get_db()
    conn.execute("""
        INSERT INTO wc_push_notifications (order_id, target_platform, title_en, body_en, body_ar, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (order_id, platform, title_en, body_en, body_ar, now_iso()))
    conn.commit()
    conn.close()


def call_mock_server(path: str, payload: dict) -> dict:
    url = f"{MOCK_SERVER_URL}{path}"
    raw = json.dumps(payload).encode("utf-8")
    provider_label = path.split("/")[2].upper() if len(path.split("/")) > 2 else "MOCK"
    log_webhook("OUTBOUND_API", provider_label, f"POST {path}", 1, payload)

    if os.environ.get("VERCEL"):
        from mock_integrations_server import MockIntegrationsHandler, invoke_handler_in_memory
        _, resp_bytes = invoke_handler_in_memory(MockIntegrationsHandler, "POST", path, raw)
        try:
            return json.loads(resp_bytes.decode("utf-8"))
        except Exception as exc:
            return {"success": False, "error": str(exc)}

    req = urllib.request.Request(
        url,
        data=raw,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        # Fallback to in-memory MockIntegrationsHandler if running in single-process / serverless mode
        try:
            from mock_integrations_server import MockIntegrationsHandler, invoke_handler_in_memory
            _, resp_bytes = invoke_handler_in_memory(MockIntegrationsHandler, "POST", path, raw)
            return json.loads(resp_bytes.decode("utf-8"))
        except Exception as exc:
            return {"success": False, "error": str(exc)}


def auto_dispatch_bosta_awb(order_id: int):
    """
    Dispatches Store-to-Client Bosta AWBs for each Partner Store sub-delivery in the order!
    Each store gets a pickup request from its branch address -> to the Client's dropoff address.
    """
    conn = get_db()
    order_row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()
    if not order_row:
        conn.close()
        return
    order = dict(order_row)
    deliveries = [dict(d) for d in conn.execute("SELECT * FROM wc_deliveries WHERE order_id = ?", (order_id,)).fetchall()]
    conn.close()

    awb_list = []
    updates = []

    for d in deliveries:
        if d["bosta_awb"]:
            awb_list.append(d["bosta_awb"])
            continue
        resp = call_mock_server("/mock/bosta/v2/deliveries", {
            "order_id": order["id"],
            "delivery_id": d["id"],
            "store_name": d["store_name"],
            "pickup_governorate": d["pickup_governorate"],
            "pickup_address": d["pickup_address"],
            "customer_name": d["customer_name"],
            "governorate": d["dropoff_governorate"],
            "dropoff_address": d["dropoff_address"],
            "cod_amount": float(d["cod_to_collect_egp"])
        })
        shipment = resp.get("shipment", {})
        awb = shipment.get("awb", f"BST-LOCAL-{d['id']}")
        awb_list.append(awb)
        updates.append((awb, now_iso(), d["id"]))

    conn = get_db()
    for awb, ts, did in updates:
        conn.execute("""
            UPDATE wc_deliveries
            SET bosta_awb = ?, courier_status = 'PICKUP_SCHEDULED', updated_at = ?
            WHERE id = ?
        """, (awb, ts, did))

    primary_awb = awb_list[0] if awb_list else f"BST-ORD-{order_id}"
    conn.execute("""
        UPDATE wc_orders
        SET bosta_awb = ?, bosta_status = 'PICKUP_SCHEDULED', order_status = 'ready-to-ship', updated_at = ?
        WHERE id = ?
    """, (primary_awb, now_iso(), order_id))
    conn.commit()
    conn.close()

    send_push_notification(
        order_id,
        "iOS + Android + Partner Store",
        f"Outsourced Bosta Pickup Scheduled ({', '.join(awb_list)}) 🚚",
        f"Bosta is picking up Order #{order['order_number']} directly from Partner Store(s) to deliver to {order['governorate']}.",
        f"تم جدولة استلام الشحنة من المتجر عبر بوسطة ({', '.join(awb_list)}) لتوصيلها إلى العميل."
    )


def finalize_stock_deduction(order_id: int):
    conn = get_db()
    items = conn.execute("SELECT * FROM wc_order_items WHERE order_id = ?", (order_id,)).fetchall()
    for item in items:
        conn.execute("""
            UPDATE wc_products
            SET stock_quantity = MAX(0, stock_quantity - ?),
                reserved_quantity = MAX(0, reserved_quantity - ?)
            WHERE id = ?
        """, (item["quantity"], item["quantity"], item["product_id"]))
    conn.commit()
    conn.close()


def release_reserved_stock(order_id: int):
    conn = get_db()
    items = conn.execute("SELECT * FROM wc_order_items WHERE order_id = ?", (order_id,)).fetchall()
    for item in items:
        conn.execute("""
            UPDATE wc_products
            SET reserved_quantity = MAX(0, reserved_quantity - ?)
            WHERE id = ?
        """, (item["quantity"], item["product_id"]))
    conn.execute("""
        UPDATE wc_deliveries
        SET courier_status = 'CANCELLED_STOCK_RELEASED', updated_at = ?
        WHERE order_id = ?
    """, (now_iso(), order_id))
    conn.commit()
    conn.close()


def calculate_cart_totals(items_req: list, governorate_code: str, payment_method: str, coupon_code: str = "") -> dict:
    conn = get_db()
    settings_row = conn.execute("SELECT * FROM wc_platform_settings WHERE id = 1").fetchone()
    settings = dict(settings_row) if settings_row else {
        "default_commission_pct": 10.0,
        "default_vat_pct": 14.0,
        "vat_mode": "INCLUSIVE",
        "extra_store_pickup_fee_egp": 25.0,
        "cod_fee_egp": 15.0,
        "default_settlement_cycle": "T+1 InstaPay / Paymob Split"
    }
    vat_mode = settings.get("vat_mode", "INCLUSIVE")

    subtotal = 0.0
    total_commission = 0.0
    total_store_payout = 0.0
    total_vat = 0.0
    detailed_items = []
    stores_involved = {}

    for entry in items_req:
        pid = int(entry.get("product_id"))
        qty = max(1, int(entry.get("quantity", 1)))
        prod = conn.execute("""
            SELECT p.*, s.name_en AS store_name_en, s.name_ar AS store_name_ar,
                   s.governorate AS store_gov, s.pickup_address AS store_address,
                   s.contact_phone AS store_phone, s.commission_pct,
                   s.vat_pct, s.delivery_fee_override_egp, s.cod_fee_override_egp, s.settlement_cycle,
                   c.name_en AS category_name_en, c.name_ar AS category_name_ar, c.slug AS category_slug
            FROM wc_products p
            JOIN wc_stores s ON p.store_id = s.id
            JOIN wc_categories c ON p.category_id = c.id
            WHERE p.id = ?
        """, (pid,)).fetchone()
        if not prod:
            continue
        line_total = round(prod["price_egp"] * qty, 2)
        comm_egp = round(line_total * (prod["commission_pct"] / 100.0), 2)
        store_net = round(line_total - comm_egp, 2)

        store_vat_pct = float(prod["vat_pct"] if prod["vat_pct"] is not None else settings["default_vat_pct"])
        if vat_mode == "ADDITIVE":
            item_vat_egp = round(line_total * (store_vat_pct / 100.0), 2)
        else:
            item_vat_egp = round(line_total - (line_total / (1.0 + (store_vat_pct / 100.0))), 2) if store_vat_pct > 0 else 0.0

        subtotal += line_total
        total_commission += comm_egp
        total_store_payout += store_net
        total_vat += item_vat_egp

        if prod["store_id"] not in stores_involved:
            stores_involved[prod["store_id"]] = {
                "store_id": prod["store_id"],
                "store_name": prod["store_name_en"],
                "delivery_fee_override_egp": prod["delivery_fee_override_egp"],
                "cod_fee_override_egp": prod["cod_fee_override_egp"],
                "vat_pct": store_vat_pct,
                "commission_pct": prod["commission_pct"],
                "settlement_cycle": prod["settlement_cycle"]
            }

        detailed_items.append({
            "product_id": prod["id"],
            "store_id": prod["store_id"],
            "store_name": prod["store_name_en"],
            "store_name_ar": prod["store_name_ar"],
            "store_gov": prod["store_gov"],
            "store_address": prod["store_address"],
            "store_phone": prod["store_phone"],
            "commission_pct": prod["commission_pct"],
            "vat_pct": store_vat_pct,
            "vat_egp": item_vat_egp,
            "platform_commission_egp": comm_egp,
            "net_store_payout_egp": store_net,
            "category_id": prod["category_id"],
            "category_slug": prod["category_slug"],
            "category_name_en": prod["category_name_en"],
            "sku": prod["sku"],
            "name_en": prod["name_en"],
            "name_ar": prod["name_ar"],
            "quantity": qty,
            "unit_price_egp": prod["price_egp"],
            "line_total_egp": line_total,
            "available_stock": prod["stock_quantity"] - prod["reserved_quantity"]
        })

    gov = conn.execute("SELECT * FROM wc_governorates WHERE code = ?", (governorate_code,)).fetchone()
    if not gov:
        gov = conn.execute("SELECT * FROM wc_governorates WHERE code = 'CAIRO'").fetchone()
    conn.close()

    # Outsourced delivery fee respecting global & per-store delivery fee overrides
    shipping_egp = 0.0
    cod_fee_egp = 0.0
    if subtotal > 0:
        store_list = list(stores_involved.values())
        for idx, st_info in enumerate(store_list):
            override = st_info.get("delivery_fee_override_egp")
            if override is not None and float(override) >= 0:
                shipping_egp += float(override)
            else:
                if idx == 0:
                    shipping_egp += float(gov["shipping_egp"])
                else:
                    shipping_egp += float(settings.get("extra_store_pickup_fee_egp", 25.0))

        if payment_method == "cod":
            first_cod_override = store_list[0].get("cod_fee_override_egp") if store_list else None
            if first_cod_override is not None and float(first_cod_override) >= 0:
                cod_fee_egp = float(first_cod_override)
            else:
                cod_fee_egp = float(settings.get("cod_fee_egp", 15.0))

    discount_egp = 0.0
    code_clean = (coupon_code or "").strip().upper()
    if code_clean == "EGYPT10":
        discount_egp = round(subtotal * 0.10, 2)
    elif code_clean == "RAMADAN200" and subtotal >= 1000:
        discount_egp = 200.0

    additive_vat = round(total_vat, 2) if vat_mode == "ADDITIVE" else 0.0
    total_egp = max(0.0, round(subtotal - discount_egp + additive_vat + shipping_egp + cod_fee_egp, 2))

    return {
        "items": detailed_items,
        "stores_count": len(stores_involved),
        "governorate": dict(gov),
        "subtotal_egp": round(subtotal, 2),
        "discount_egp": discount_egp,
        "coupon_applied": code_clean if discount_egp > 0 else None,
        "vat_egp": round(total_vat, 2),
        "vat_mode": vat_mode,
        "shipping_egp": round(shipping_egp, 2),
        "cod_fee_egp": round(cod_fee_egp, 2),
        "total_egp": total_egp,
        "platform_commission_egp": round(total_commission, 2),
        "net_stores_payout_egp": round(total_store_payout, 2),
        "valu_plans": {
            "6_months": round((total_egp * 1.108) / 6, 2),
            "12_months": round((total_egp * 1.216) / 12, 2),
            "24_months": round((total_egp * 1.432) / 24, 2)
        }
    }


def fetch_support_tickets(conn: sqlite3.Connection) -> list:
    tickets = [dict(r) for r in conn.execute("""
        SELECT t.*, s.name_en AS store_name_en
        FROM wc_support_tickets t
        LEFT JOIN wc_stores s ON t.store_id = s.id
        ORDER BY t.id DESC
    """).fetchall()]
    for t in tickets:
        t["messages"] = [dict(m) for m in conn.execute("""
            SELECT * FROM wc_support_messages WHERE ticket_id = ? ORDER BY id ASC
        """, (t["id"],)).fetchall()]
    return tickets


def fetch_enriched_products(conn: sqlite3.Connection, category_id=None, store_id=None) -> list:
    query = """
        SELECT p.*,
               s.code AS store_code, s.name_en AS store_name_en, s.name_ar AS store_name_ar,
               s.governorate AS store_gov, s.pickup_address AS store_address, s.commission_pct,
               s.vat_pct, s.delivery_fee_override_egp, s.cod_fee_override_egp, s.settlement_cycle,
               c.slug AS category_slug, c.name_en AS category_name_en, c.name_ar AS category_name_ar, c.icon_emoji AS category_icon
        FROM wc_products p
        JOIN wc_stores s ON p.store_id = s.id
        JOIN wc_categories c ON p.category_id = c.id
        WHERE 1=1
    """
    params = []
    if category_id:
        query += " AND p.category_id = ?"
        params.append(int(category_id))
    if store_id:
        query += " AND p.store_id = ?"
        params.append(int(store_id))
    query += " ORDER BY p.id ASC"
    rows = [dict(r) for r in conn.execute(query, params).fetchall()]
    for r in rows:
        r["available_stock"] = max(0, r["stock_quantity"] - r["reserved_quantity"])
    return rows



COURIER_FLEET = [
    {"id": 1, "name": "Tarek Mostafa", "phone": "01098765432", "vehicle": "🛵 Motorcycle (Honda CB)", "governorate": "CAIRO", "area": "Nasr City / Makram Ebeid", "base_distance_km": 0.8, "rating": 4.9},
    {"id": 2, "name": "Mahmoud Hassan", "phone": "01187654321", "vehicle": "🛵 Motorcycle (Bajaj Boxer)", "governorate": "CAIRO", "area": "Heliopolis / Korba", "base_distance_km": 1.4, "rating": 4.8},
    {"id": 3, "name": "Karim Adel", "phone": "01276543210", "vehicle": "🚗 Light Van (Suzuki Carry)", "governorate": "CAIRO", "area": "New Cairo / Tagamoa", "base_distance_km": 2.2, "rating": 4.7},
    {"id": 4, "name": "Mostafa Ramadan", "phone": "01011223344", "vehicle": "🛵 Motorcycle (Dayun 150)", "governorate": "GIZA", "area": "Dokki / Mossadak St", "base_distance_km": 0.9, "rating": 4.9},
    {"id": 5, "name": "Ahmed Farouk", "phone": "01122334455", "vehicle": "🛵 Motorcycle (Haojiang)", "governorate": "GIZA", "area": "Mohandessin / Gameat Dowal", "base_distance_km": 1.6, "rating": 4.8},
    {"id": 6, "name": "Karim Salem", "phone": "01055667788", "vehicle": "🛵 Motorcycle (Yamaha)", "governorate": "ALEX", "area": "Smouha / Victor Emmanuel", "base_distance_km": 1.1, "rating": 4.9},
    {"id": 7, "name": "Youssef Helmy", "phone": "01233445566", "vehicle": "🚗 Hatchback (Chevrolet)", "governorate": "ALEX", "area": "Sidi Gaber / Stanly", "base_distance_km": 2.0, "rating": 4.8},
]

def get_nearby_couriers(governorate: str = "CAIRO") -> list:
    gov = (governorate or "CAIRO").upper()
    matched = [c for c in COURIER_FLEET if c["governorate"] == gov]
    if not matched:
        matched = COURIER_FLEET[:3]
    return sorted(matched, key=lambda x: x["base_distance_km"])

def enrich_order_dict(o: dict, conn: sqlite3.Connection) -> dict:
    order_id = o["id"]
    items = [dict(i) for i in conn.execute("SELECT * FROM wc_order_items WHERE order_id = ?", (order_id,)).fetchall()]
    deliveries = [dict(d) for d in conn.execute("SELECT * FROM wc_deliveries WHERE order_id = ? ORDER BY id ASC", (order_id,)).fetchall()]
    try:
        o["gateway_meta"] = json.loads(o["gateway_meta"]) if o.get("gateway_meta") else {}
    except Exception:
        o["gateway_meta"] = {}
    o["items"] = items
    o["deliveries"] = deliveries

    is_closed = o["order_status"] in ("completed", "completed-settled", "cancelled", "refunded") or o.get("payment_status") == "settled"
    o["is_closed"] = bool(is_closed)

    store_names = list(dict.fromkeys([d["store_name"] for d in deliveries if d.get("store_name")]))
    o["stores_count"] = len(store_names) if store_names else 1
    o["stores_summary"] = " + ".join(store_names) if store_names else "Partner Store"

    all_delivered = len(deliveries) > 0 and all(d.get("courier_status") == "DELIVERED" for d in deliveries)
    any_arrived = any(d.get("courier_status") in ("ARRIVED_AT_CLIENT", "DELIVERED") for d in deliveries)
    any_out = any(d.get("courier_status") in ("OUT_FOR_DELIVERY", "ARRIVED_AT_CLIENT", "DELIVERED") for d in deliveries)
    any_pickup = any(d.get("courier_status") in ("PICKED_UP_FROM_STORE", "OUT_FOR_DELIVERY", "ARRIVED_AT_CLIENT", "DELIVERED") for d in deliveries)
    any_assigned = any(d.get("courier_name") or d.get("courier_status") in ("COURIER_ASSIGNED", "PICKED_UP_FROM_STORE", "OUT_FOR_DELIVERY", "ARRIVED_AT_CLIENT", "DELIVERED") for d in deliveries)
    all_packed = len(deliveries) > 0 and all(d.get("packaging_status") == "READY_FOR_COURIER_PICKUP" for d in deliveries)
    any_packed = any(d.get("packaging_status") == "READY_FOR_COURIER_PICKUP" for d in deliveries)

    store_reviewed = o.get("store_review_status") == "STORE_CONFIRMED" or o.get("order_status") in ("store-reviewed", "processing", "ready-to-ship", "completed", "completed-settled")
    client_confirmed = o.get("payment_status") in ("paid", "settled", "pending_cod_collection") or o.get("order_status") in ("processing", "ready-to-ship", "completed", "completed-settled")

    # Determine assigned courier info from deliveries if not directly on order
    if not o.get("assigned_courier_name"):
        for d in deliveries:
            if d.get("courier_name"):
                o["assigned_courier_name"] = d["courier_name"]
                o["assigned_courier_phone"] = d.get("courier_phone")
                o["assigned_courier_vehicle"] = d.get("courier_vehicle")
                break

    if o["order_status"] == "cancelled":
        progress_pct = 0
        progress_stage = "Order Cancelled / Rejected by Client"
        progress_stage_ar = "تم إلغاء الطلب وإعادة المخزون للمتجر"
        status_color = "rose"
    elif all_delivered:
        progress_pct = 100
        progress_stage = "Delivered & Handover Confirmed" if o.get("payment_status") == "settled" else "Delivered to Client"
        progress_stage_ar = "تم التسليم وتأكيد الاستلام والتسوية" if o.get("payment_status") == "settled" else "تم الاستلام بنجاح"
        status_color = "emerald"
    elif any_arrived:
        progress_pct = 90
        progress_stage = "Courier Reached Client Address (Handover PIN / Cash)"
        progress_stage_ar = "المندوب وصل لموقع العميل (كود الاستلام / تحصيل)"
        status_color = "emerald"
    elif any_out or any_pickup:
        c_name = o.get("assigned_courier_name") or "Bosta Courier"
        progress_pct = 75
        progress_stage = f"In Transit with {c_name} (Pickup Confirmed)"
        progress_stage_ar = f"الشحنة مع المندوب ({c_name}) جاري التوصيل"
        status_color = "purple"
    elif any_assigned or all_packed:
        c_name = o.get("assigned_courier_name") or "Nearest Courier"
        progress_pct = 60
        progress_stage = f"Pack Ready • Assigned {c_name} (En Route to Store)"
        progress_stage_ar = f"الطرد جاهز • تم تعيين المندوب ({c_name}) للفرع"
        status_color = "indigo"
    elif o.get("order_status") == "processing" or client_confirmed:
        progress_pct = 45
        progress_stage = "Client Confirmed & Money Captured (Store Packing)"
        progress_stage_ar = "تمت موافقة العميل وخصم المبلغ (جاري تجهيز الطرد)"
        status_color = "blue"
    elif o.get("order_status") == "store-reviewed":
        progress_pct = 35
        progress_stage = "Store Confirmed Availability (Awaiting Client Confirmation)"
        progress_stage_ar = "المتجر أكد توفر المنتجات (بانتظار موافقة العميل)"
        status_color = "cyan"
    else:
        progress_pct = 15
        progress_stage = "Order Placed (Awaiting Store Availability Review)"
        progress_stage_ar = "تم إنشاء الطلب (بانتظار فحص وتأكيد المتجر للمخزون)"
        status_color = "amber"

    o["progress_pct"] = progress_pct
    o["progress_stage"] = progress_stage
    o["progress_stage_ar"] = progress_stage_ar
    o["status_color"] = status_color

    o["timeline"] = [
        {
            "step": 1,
            "title_en": "1. Location Matched & Order Placed",
            "title_ar": "اختيار الموقع وإنشاء الطلب",
            "state": "completed",
            "time": o.get("created_at")
        },
        {
            "step": 2,
            "title_en": "2. Store Item Availability Review",
            "title_ar": "فحص وتأكيد توفر المنتجات بالمتجر",
            "state": "completed" if store_reviewed else ("cancelled" if o["order_status"] == "cancelled" else "in-progress"),
            "time": None
        },
        {
            "step": 3,
            "title_en": "3. Client Confirmation & Payment Capture",
            "title_ar": "موافقة العميل وخصم المبلغ من البطاقة",
            "state": "completed" if client_confirmed else ("cancelled" if o["order_status"] == "cancelled" else ("in-progress" if o.get("order_status") == "store-reviewed" else "pending")),
            "time": o.get("updated_at") if client_confirmed else None
        },
        {
            "step": 4,
            "title_en": f"4. Store Packaging ({len(deliveries)} Origin Branches)",
            "title_ar": f"تجهيز وتغليف الطرد بالمتجر ({len(deliveries)} فروع)",
            "state": "completed" if all_packed else ("in-progress" if any_packed else "pending"),
            "time": None
        },
        {
            "step": 5,
            "title_en": "5. Proximity Courier Assigned & Pickup",
            "title_ar": "تعيين أقرب مندوب واستلام الشحنة",
            "state": "completed" if any_pickup else ("in-progress" if (all_packed or any_assigned) else "pending"),
            "time": None
        },
        {
            "step": 6,
            "title_en": "6. Courier at Client & Handover PIN/Cash",
            "title_ar": "وصول المندوب ومطابقة الكود / التحصيل",
            "state": "completed" if all_delivered else ("in-progress" if (any_pickup or any_arrived) else "pending"),
            "time": None
        },
        {
            "step": 7,
            "title_en": "7. Package Delivered & Cash Settled",
            "title_ar": "تم تسليم الشحنة والتسوية المالية للمتجر",
            "state": "completed" if all_delivered else "pending",
            "time": None
        }
    ]
    return o


def fetch_enriched_orders(conn: sqlite3.Connection, scope=None, phone=None, order_number=None, q=None) -> list:
    query = "SELECT * FROM wc_orders WHERE 1=1"
    params = []

    if order_number:
        query += " AND order_number LIKE ?"
        params.append(f"%{order_number.strip()}%")

    if phone:
        clean_phone = phone.strip()
        query += " AND (customer_phone LIKE ? OR customer_phone LIKE ?)"
        params.append(f"%{clean_phone}%")
        params.append(f"%{clean_phone[-9:]}%" if len(clean_phone) >= 9 else f"%{clean_phone}%")

    if q:
        query_val = f"%{q.strip()}%"
        query += " AND (order_number LIKE ? OR customer_name LIKE ? OR customer_phone LIKE ? OR governorate LIKE ?)"
        params.extend([query_val, query_val, query_val, query_val])

    query += " ORDER BY id DESC"
    raw_orders = [dict(r) for r in conn.execute(query, params).fetchall()]
    enriched = [enrich_order_dict(o, conn) for o in raw_orders]

    if scope == "active":
        enriched = [o for o in enriched if not o["is_closed"]]
    elif scope == "closed":
        enriched = [o for o in enriched if o["is_closed"]]

    return enriched


class EcommerceRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def _send_json(self, data, status: int = 200):
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Egypt-HMAC-SHA512")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _read_body_bytes(self) -> bytes:
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length) if length > 0 else b"{}"

    def _verify_hmac(self, raw_bytes: bytes) -> bool:
        header_sig = self.headers.get("X-Egypt-HMAC-SHA512", "")
        expected = hmac.new(
            SHARED_HMAC_SECRET.encode("utf-8"),
            raw_bytes,
            hashlib.sha512
        ).hexdigest()
        return hmac.compare_digest(header_sig, expected)

    def do_OPTIONS(self):
        self._send_json({"ok": True})

    def do_GET(self):
        parsed_url = urllib.parse.urlsplit(self.path)
        path_only = parsed_url.path
        qs_params = urllib.parse.parse_qs(parsed_url.query)
        if path_only == "/" or path_only.startswith("/index.html"):
            if os.path.exists(INDEX_HTML_PATH):
                with open(INDEX_HTML_PATH, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return
            self._send_json({"error": "UI file missing"}, 404)
            return

        if path_only in ("/study", "/study.html"):
            if os.path.exists(STUDY_HTML_PATH):
                with open(STUDY_HTML_PATH, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return
            self._send_json({"error": "Study file missing"}, 404)
            return

        if path_only == "/mock-dashboard" or path_only.startswith("/mock/"):
            from mock_integrations_server import MockIntegrationsHandler, invoke_handler_in_memory
            status_code, resp_bytes = invoke_handler_in_memory(MockIntegrationsHandler, "GET", path_only)
            ctype = "text/html; charset=utf-8" if path_only == "/mock-dashboard" else "application/json; charset=utf-8"
            self.send_response(status_code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(resp_bytes)))
            self.end_headers()
            self.wfile.write(resp_bytes)
            return

        conn = get_db()

        if path_only == "/wp-json/wc/v3/products/categories":
            cats = [dict(r) for r in conn.execute("""
                SELECT c.*, COUNT(p.id) AS product_count
                FROM wc_categories c
                LEFT JOIN wc_products p ON p.category_id = c.id
                GROUP BY c.id
                ORDER BY c.id ASC
            """).fetchall()]
            conn.close()
            self._send_json(cats)
            return

        if path_only == "/wp-json/wc/v3/stores":
            stores = [dict(r) for r in conn.execute("SELECT * FROM wc_stores ORDER BY id ASC").fetchall()]
            for s in stores:
                stats = conn.execute("""
                    SELECT COALESCE(SUM(store_subtotal_egp), 0) AS gross_sales_egp,
                           COALESCE(SUM(platform_commission_egp), 0) AS commission_egp,
                           COALESCE(SUM(net_store_payout_egp), 0) AS net_payout_egp,
                           COALESCE(SUM(CASE WHEN settlement_status = 'SETTLED_TO_STORE' THEN net_store_payout_egp ELSE 0 END), 0) AS settled_payout_egp,
                           COALESCE(SUM(CASE WHEN settlement_status != 'SETTLED_TO_STORE' THEN net_store_payout_egp ELSE 0 END), 0) AS pending_payout_egp,
                           COUNT(*) AS deliveries_count
                    FROM wc_deliveries
                    WHERE store_id = ? AND courier_status != 'CANCELLED_STOCK_RELEASED'
                """, (s["id"],)).fetchone()
                s.update(dict(stats))
            conn.close()
            self._send_json(stores)
            return

        if path_only == "/wp-json/wc/v3/settlements":
            rows = [dict(r) for r in conn.execute("SELECT * FROM wc_settlements ORDER BY id DESC").fetchall()]
            conn.close()
            self._send_json(rows)
            return

        if path_only == "/wp-json/wc/v3/support/tickets":
            tickets = fetch_support_tickets(conn)
            conn.close()
            self._send_json(tickets)
            return

        if path_only == "/wp-json/wc/v3/settings/commercial-rules":
            settings_row = conn.execute("SELECT * FROM wc_platform_settings WHERE id = 1").fetchone()
            stores = [dict(r) for r in conn.execute("SELECT * FROM wc_stores ORDER BY id ASC").fetchall()]
            govs = [dict(r) for r in conn.execute("SELECT * FROM wc_governorates").fetchall()]
            conn.close()
            self._send_json({
                "platform_settings": dict(settings_row) if settings_row else {},
                "stores": stores,
                "governorates": govs
            })
            return

        if path_only == "/wp-json/wc/v3/products":
            rows = fetch_enriched_products(conn)
            conn.close()
            self._send_json(rows)
            return

        if path_only == "/wp-json/wc/v3/couriers/nearby":
            gov = qs_params.get("governorate", ["CAIRO"])[0]
            couriers = get_nearby_couriers(gov)
            conn.close()
            self._send_json({"success": True, "governorate": gov, "couriers": couriers})
            return

        if path_only == "/wp-json/wc/v3/governorates":
            rows = [dict(r) for r in conn.execute("SELECT * FROM wc_governorates").fetchall()]
            conn.close()
            self._send_json(rows)
            return

        if path_only == "/wp-json/wc/v3/deliveries":
            rows = [dict(r) for r in conn.execute("SELECT * FROM wc_deliveries ORDER BY id DESC").fetchall()]
            conn.close()
            self._send_json(rows)
            return

        if path_only == "/wp-json/wc/v3/orders/track":
            q = qs_params.get("q", [""])[0] or qs_params.get("order_number", [""])[0] or qs_params.get("phone", [""])[0]
            scope = qs_params.get("scope", ["all"])[0]
            orders = fetch_enriched_orders(conn, scope=scope, q=q if q else None)
            active_count = len([o for o in orders if not o["is_closed"]])
            closed_count = len([o for o in orders if o["is_closed"]])
            conn.close()
            self._send_json({
                "success": True,
                "query": q,
                "total_count": len(orders),
                "active_count": active_count,
                "closed_count": closed_count,
                "orders": orders
            })
            return

        if path_only.startswith("/wp-json/wc/v3/orders/"):
            sub = path_only[len("/wp-json/wc/v3/orders/"):]
            if sub and not sub.startswith("track") and not sub.endswith("/instapay-approve"):
                if sub.isdigit():
                    row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (int(sub),)).fetchone()
                else:
                    row = conn.execute("SELECT * FROM wc_orders WHERE order_number = ?", (sub,)).fetchone()
                if row:
                    order = enrich_order_dict(dict(row), conn)
                    conn.close()
                    self._send_json({"success": True, "order": order})
                    return
                conn.close()
                self._send_json({"error": "Order not found"}, 404)
                return

        if path_only == "/wp-json/wc/v3/orders":
            scope = qs_params.get("scope", ["all"])[0]
            phone = qs_params.get("customer_phone", [""])[0] or qs_params.get("phone", [""])[0]
            order_num = qs_params.get("order_number", [""])[0]
            q = qs_params.get("q", [""])[0]
            orders = fetch_enriched_orders(conn, scope=scope, phone=phone if phone else None, order_number=order_num if order_num else None, q=q if q else None)
            conn.close()
            self._send_json(orders)
            return

        if path_only == "/wp-json/wc/v3/system/state":
            categories = [dict(r) for r in conn.execute("""
                SELECT c.*, COUNT(p.id) AS product_count
                FROM wc_categories c
                LEFT JOIN wc_products p ON p.category_id = c.id
                GROUP BY c.id
                ORDER BY c.id ASC
            """).fetchall()]
            stores = [dict(r) for r in conn.execute("SELECT * FROM wc_stores ORDER BY id ASC").fetchall()]
            for s in stores:
                stats = conn.execute("""
                    SELECT COALESCE(SUM(store_subtotal_egp), 0) AS gross_sales_egp,
                           COALESCE(SUM(platform_commission_egp), 0) AS commission_egp,
                           COALESCE(SUM(net_store_payout_egp), 0) AS net_payout_egp,
                           COALESCE(SUM(CASE WHEN settlement_status = 'SETTLED_TO_STORE' THEN net_store_payout_egp ELSE 0 END), 0) AS settled_payout_egp,
                           COALESCE(SUM(CASE WHEN settlement_status != 'SETTLED_TO_STORE' THEN net_store_payout_egp ELSE 0 END), 0) AS pending_payout_egp,
                           COALESCE(SUM(CASE WHEN settlement_status = 'SETTLED_TO_STORE' THEN platform_commission_egp ELSE 0 END), 0) AS settled_commission_egp,
                           COUNT(*) AS deliveries_count
                    FROM wc_deliveries
                    WHERE store_id = ? AND courier_status != 'CANCELLED_STOCK_RELEASED'
                """, (s["id"],)).fetchone()
                s.update(dict(stats))

            products = fetch_enriched_products(conn)
            govs = [dict(r) for r in conn.execute("SELECT * FROM wc_governorates").fetchall()]
            deliveries = [dict(r) for r in conn.execute("SELECT * FROM wc_deliveries ORDER BY id DESC").fetchall()]
            settlements = [dict(r) for r in conn.execute("SELECT * FROM wc_settlements ORDER BY id DESC").fetchall()]
            raw_orders = [dict(r) for r in conn.execute("SELECT * FROM wc_orders ORDER BY id DESC").fetchall()]
            orders = [enrich_order_dict(o, conn) for o in raw_orders]
            webhooks = [dict(r) for r in conn.execute("SELECT * FROM wc_webhooks_log ORDER BY id DESC LIMIT 40").fetchall()]
            pushes = [dict(r) for r in conn.execute("SELECT * FROM wc_push_notifications ORDER BY id DESC LIMIT 25").fetchall()]
            settings_row = conn.execute("SELECT * FROM wc_platform_settings WHERE id = 1").fetchone()
            platform_settings = dict(settings_row) if settings_row else {}
            support_tickets = fetch_support_tickets(conn)
            conn.close()
            self._send_json({
                "status": "online",
                "business_model": "Zero-Inventory Multi-Store Facilitator + Outsourced 3PL Delivery + Cash Settlement",
                "platform_settings": platform_settings,
                "categories": categories,
                "stores": stores,
                "products": products,
                "governorates": govs,
                "deliveries": deliveries,
                "settlements": settlements,
                "orders": orders,
                "courier_fleet": COURIER_FLEET,
                "support_tickets": support_tickets,
                "webhooks_log": webhooks,
                "push_notifications": pushes
            })
            return

        conn.close()
        self._send_json({"error": "Endpoint not found"}, 404)

    def do_POST(self):
        raw_bytes = self._read_body_bytes()
        body = json.loads(raw_bytes.decode("utf-8"))

        # 0. Same-Origin Proxy to Mock Integration Server (:4001 or Serverless In-Memory)
        if self.path == "/wp-json/wc/v3/mock-proxy":
            mock_path = body.get("mock_path", "")
            mock_payload = body.get("payload", {})
            resp = call_mock_server(f"/mock{mock_path}", mock_payload)
            self._send_json(resp)
            return

        if self.path.startswith("/mock/"):
            from mock_integrations_server import MockIntegrationsHandler, invoke_handler_in_memory
            status_code, resp_bytes = invoke_handler_in_memory(MockIntegrationsHandler, "POST", self.path, raw_bytes)
            try:
                self._send_json(json.loads(resp_bytes.decode("utf-8")), status_code)
            except Exception:
                self._send_json({"error": "Invalid mock response"}, 500)
            return

        # 1. Cart Calculation Endpoint
        if self.path == "/wp-json/wc/v3/cart/calculate":
            calc = calculate_cart_totals(
                body.get("items", []),
                body.get("governorate", "CAIRO"),
                body.get("payment_method", "paymob_card"),
                body.get("coupon_code", "")
            )
            self._send_json(calc)
            return

        # 2. Add New Product Category
        if self.path == "/wp-json/wc/v3/products/categories":
            conn = get_db()
            name_en = body.get("name_en", "New Category")
            name_ar = body.get("name_ar", "قسم جديد")
            slug = body.get("slug") or name_en.lower().replace(" ", "-")
            icon = body.get("icon_emoji", "🏷️")
            cur = conn.execute("""
                INSERT INTO wc_categories (slug, name_en, name_ar, icon_emoji, description_en)
                VALUES (?, ?, ?, ?, ?)
            """, (slug, name_en, name_ar, icon, body.get("description_en", "")))
            cid = cur.lastrowid
            conn.commit()
            cat = dict(conn.execute("SELECT * FROM wc_categories WHERE id = ?", (cid,)).fetchone())
            conn.close()
            self._send_json({"success": True, "category": cat}, 201)
            return

        # 3. Add New Partner Store
        if self.path == "/wp-json/wc/v3/stores":
            conn = get_db()
            name_en = body.get("name_en", "New Partner Store")
            name_ar = body.get("name_ar", "متجر شريك جديد")
            code = body.get("code") or f"STORE-{int(datetime.now().timestamp()) % 10000}"
            gov = body.get("governorate", "CAIRO")
            address = body.get("pickup_address", "Cairo Main St")
            phone = body.get("contact_phone", "01000000000")
            comm = float(body.get("commission_pct", 10.0))
            cur = conn.execute("""
                INSERT INTO wc_stores (code, name_en, name_ar, governorate, pickup_address, contact_phone, commission_pct, rating, active)
                VALUES (?, ?, ?, ?, ?, ?, ?, 5.0, 1)
            """, (code, name_en, name_ar, gov, address, phone, comm))
            sid = cur.lastrowid
            conn.commit()
            store = dict(conn.execute("SELECT * FROM wc_stores WHERE id = ?", (sid,)).fetchone())
            conn.close()
            self._send_json({"success": True, "store": store}, 201)
            return

        # 4. Add New Product to a Partner Store & Category
        if self.path == "/wp-json/wc/v3/products":
            conn = get_db()
            sku = body.get("sku", f"EG-NEW-{int(datetime.now().timestamp()) % 100000}")
            store_id = int(body.get("store_id", 1))
            category_id = int(body.get("category_id", 1))
            cat_row = conn.execute("SELECT name_en FROM wc_categories WHERE id = ?", (category_id,)).fetchone()
            cat_name = cat_row["name_en"] if cat_row else "General"
            name_en = body.get("name_en", "New Partner Store Product")
            name_ar = body.get("name_ar", "منتج جديد من المتجر")
            price_egp = float(body.get("price_egp", 500.0))
            stock = int(body.get("stock_quantity", 25))
            emoji = body.get("image_emoji", "🛍️")
            cur = conn.execute("""
                INSERT INTO wc_products (sku, store_id, category_id, name_en, name_ar, category, price_egp, stock_quantity, reserved_quantity, image_emoji, valu_eligible)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 1)
            """, (sku, store_id, category_id, name_en, name_ar, cat_name, price_egp, stock, emoji))
            prod_id = cur.lastrowid
            conn.commit()
            prod = dict(conn.execute("SELECT * FROM wc_products WHERE id = ?", (prod_id,)).fetchone())
            conn.close()
            self._send_json({"success": True, "product": prod}, 201)
            return

        # 5. Partner Store Updates Its Own Inventory Stock
        if self.path.startswith("/wp-json/wc/v3/products/") and self.path.endswith("/stock"):
            parts = self.path.split("/")
            prod_id = int(parts[5])
            delta = int(body.get("delta", 5))
            conn = get_db()
            conn.execute("""
                UPDATE wc_products
                SET stock_quantity = MAX(reserved_quantity, stock_quantity + ?)
                WHERE id = ?
            """, (delta, prod_id))
            conn.commit()
            prod = dict(conn.execute("SELECT * FROM wc_products WHERE id = ?", (prod_id,)).fetchone())
            conn.close()
            self._send_json({"success": True, "product": prod})
            return

        # 6. Partner Store Marks Sub-Order Packaged & Ready for Outsourced Courier Pickup
        if self.path.startswith("/wp-json/wc/v3/deliveries/") and self.path.endswith("/store-ready"):
            parts = self.path.split("/")
            delivery_id = int(parts[5])
            conn = get_db()
            deliv = conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone()
            if not deliv:
                conn.close()
                self._send_json({"error": "Delivery record not found"}, 404)
                return
            conn.execute("""
                UPDATE wc_deliveries
                SET packaging_status = 'READY_FOR_COURIER_PICKUP', updated_at = ?
                WHERE id = ?
            """, (now_iso(), delivery_id))
            conn.commit()
            conn.close()
            send_push_notification(
                deliv["order_id"], "Outsourced Delivery Hub + Client App",
                f"Store Packaged Order #{deliv['order_number']} 📦",
                f"{deliv['store_name']} marked parcel ready at {deliv['pickup_address']} for Bosta pickup!",
                f"قام متجر ({deliv['store_name']}) بتجهيز الطلب للاستلام بواسطة مندوب بوسطة."
            )
            self._send_json({"success": True, "delivery_id": delivery_id, "packaging_status": "READY_FOR_COURIER_PICKUP"})
            return

        # 6B. Settle Cash Payout for a Delivered Store Sub-Order
        if self.path.startswith("/wp-json/wc/v3/deliveries/") and self.path.endswith("/settle"):
            parts = self.path.split("/")
            delivery_id = int(parts[5])
            conn = get_db()
            deliv_row = conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone()
            if not deliv_row:
                conn.close()
                self._send_json({"error": "Delivery record not found"}, 404)
                return
            deliv = dict(deliv_row)
            if deliv["courier_status"] != "DELIVERED":
                conn.close()
                self._send_json({"error": "Delivery must be DELIVERED to Client before Cash Settlement"}, 400)
                return
            if deliv.get("settlement_status") == "SETTLED_TO_STORE":
                existing = conn.execute("SELECT * FROM wc_settlements WHERE delivery_id = ?", (delivery_id,)).fetchone()
                conn.close()
                self._send_json({"success": True, "already_settled": True, "settlement": dict(existing) if existing else {}})
                return

            order_row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (deliv["order_id"],)).fetchone()
            order = dict(order_row) if order_row else {}
            conn.close()

            resp = call_mock_server("/mock/settlement/v1/payout", {
                "order_id": deliv["order_id"],
                "order_number": deliv["order_number"],
                "delivery_id": deliv["id"],
                "store_id": deliv["store_id"],
                "store_name": deliv["store_name"],
                "payment_method": order.get("payment_method", "paymob_card"),
                "bosta_awb": deliv.get("bosta_awb", ""),
                "gross_amount_egp": deliv["store_subtotal_egp"],
                "platform_commission_egp": deliv["platform_commission_egp"],
                "net_store_payout_egp": deliv["net_store_payout_egp"],
                "cod_collected_egp": deliv["cod_to_collect_egp"]
            })
            conn = get_db()
            updated_deliv = dict(conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone())
            settlement_row = conn.execute("SELECT * FROM wc_settlements WHERE delivery_id = ?", (delivery_id,)).fetchone()
            conn.close()
            self._send_json({
                "success": True,
                "delivery": updated_deliv,
                "settlement": dict(settlement_row) if settlement_row else resp.get("settlement", {})
            })
            return

        # 6C. Bulk Cash Settlement (All Stores or Specific Store)
        if self.path == "/wp-json/wc/v3/settlements/settle-bulk":
            target_store = body.get("store_id", "all")
            conn = get_db()
            if str(target_store).lower() == "all":
                eligible = [dict(r) for r in conn.execute("""
                    SELECT * FROM wc_deliveries
                    WHERE courier_status = 'DELIVERED' AND settlement_status != 'SETTLED_TO_STORE'
                """).fetchall()]
            else:
                eligible = [dict(r) for r in conn.execute("""
                    SELECT * FROM wc_deliveries
                    WHERE store_id = ? AND courier_status = 'DELIVERED' AND settlement_status != 'SETTLED_TO_STORE'
                """, (int(target_store),)).fetchall()]
            conn.close()

            settled_refs = []
            for deliv in eligible:
                conn = get_db()
                order_row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (deliv["order_id"],)).fetchone()
                order = dict(order_row) if order_row else {}
                conn.close()
                resp = call_mock_server("/mock/settlement/v1/payout", {
                    "order_id": deliv["order_id"],
                    "order_number": deliv["order_number"],
                    "delivery_id": deliv["id"],
                    "store_id": deliv["store_id"],
                    "store_name": deliv["store_name"],
                    "payment_method": order.get("payment_method", "paymob_card"),
                    "bosta_awb": deliv.get("bosta_awb", ""),
                    "gross_amount_egp": deliv["store_subtotal_egp"],
                    "platform_commission_egp": deliv["platform_commission_egp"],
                    "net_store_payout_egp": deliv["net_store_payout_egp"],
                    "cod_collected_egp": deliv["cod_to_collect_egp"]
                })
                st_obj = resp.get("settlement", {})
                if st_obj.get("settlement_ref"):
                    settled_refs.append(st_obj["settlement_ref"])

            self._send_json({
                "success": True,
                "store_scope": target_store,
                "settled_count": len(settled_refs),
                "settlement_refs": settled_refs
            })
            return

        # 6D. Manage Commercial Rules (Delivery Fee, VAT %, Commission %, COD Fee, Settlement Cycle) per Store or All Stores
        if self.path == "/wp-json/wc/v3/settings/commercial-rules":
            target_scope = str(body.get("target_scope", "all")).lower()
            commission_pct = float(body.get("commission_pct", 10.0))
            vat_pct = float(body.get("vat_pct", 14.0))
            vat_mode = body.get("vat_mode", "INCLUSIVE")
            raw_deliv_override = body.get("delivery_fee_override_egp", None)
            deliv_override = float(raw_deliv_override) if (raw_deliv_override not in (None, "", "null", -1, "-1")) else None
            raw_cod_override = body.get("cod_fee_egp", None)
            cod_fee = float(raw_cod_override) if (raw_cod_override not in (None, "", "null", -1, "-1")) else 15.0
            extra_pickup_fee = float(body.get("extra_store_pickup_fee_egp", 25.0))
            settlement_cycle = body.get("settlement_cycle", "T+1 InstaPay / Paymob Split")

            conn = get_db()
            ts = now_iso()
            if target_scope == "all":
                conn.execute("""
                    UPDATE wc_platform_settings
                    SET default_commission_pct = ?,
                        default_vat_pct = ?,
                        vat_mode = ?,
                        extra_store_pickup_fee_egp = ?,
                        cod_fee_egp = ?,
                        default_settlement_cycle = ?,
                        updated_at = ?
                    WHERE id = 1
                """, (commission_pct, vat_pct, vat_mode, extra_pickup_fee, cod_fee, settlement_cycle, ts))

                conn.execute("""
                    UPDATE wc_stores
                    SET commission_pct = ?,
                        vat_pct = ?,
                        delivery_fee_override_egp = ?,
                        cod_fee_override_egp = ?,
                        settlement_cycle = ?
                """, (commission_pct, vat_pct, deliv_override, cod_fee, settlement_cycle))
            else:
                store_id = int(target_scope)
                conn.execute("""
                    UPDATE wc_platform_settings
                    SET vat_mode = ?,
                        extra_store_pickup_fee_egp = ?,
                        updated_at = ?
                    WHERE id = 1
                """, (vat_mode, extra_pickup_fee, ts))

                conn.execute("""
                    UPDATE wc_stores
                    SET commission_pct = ?,
                        vat_pct = ?,
                        delivery_fee_override_egp = ?,
                        cod_fee_override_egp = ?,
                        settlement_cycle = ?
                    WHERE id = ?
                """, (commission_pct, vat_pct, deliv_override, cod_fee, settlement_cycle, store_id))

            conn.commit()
            settings_row = dict(conn.execute("SELECT * FROM wc_platform_settings WHERE id = 1").fetchone())
            stores = [dict(r) for r in conn.execute("SELECT * FROM wc_stores ORDER BY id ASC").fetchall()]
            conn.close()
            log_webhook("ADMIN_POLICY", "COMMERCIAL_ENGINE", f"RULES_UPDATED ({target_scope.upper()})", 1, body)
            self._send_json({"success": True, "target_scope": target_scope, "platform_settings": settings_row, "stores": stores})
            return

        # 6E. Update Governorate Delivery Fees (Single Governorate or ALL Governorates)
        if self.path == "/wp-json/wc/v3/governorates/update":
            gov_code = str(body.get("code", "CAIRO")).upper()
            shipping_egp = float(body.get("shipping_egp", 55.0))
            sla_days = body.get("sla_days", "Next-Day (24h)")
            conn = get_db()
            if gov_code == "ALL":
                conn.execute("UPDATE wc_governorates SET shipping_egp = ?, sla_days = ?", (shipping_egp, sla_days))
            else:
                conn.execute("UPDATE wc_governorates SET shipping_egp = ?, sla_days = ? WHERE code = ?", (shipping_egp, sla_days, gov_code))
            conn.commit()
            govs = [dict(r) for r in conn.execute("SELECT * FROM wc_governorates").fetchall()]
            conn.close()
            self._send_json({"success": True, "governorates": govs})
            return

        # 6F. Customer Support & Live Chat Endpoints (Create Ticket / Reply / Change Status)
        if self.path == "/wp-json/wc/v3/support/tickets":
            customer_name = body.get("customer_name", "Shopper")
            customer_phone = body.get("customer_phone", "01000000000")
            order_number = body.get("order_number", "")
            raw_store_id = body.get("store_id")
            store_id = int(raw_store_id) if (raw_store_id not in (None, "", "all", "0", 0)) else None
            subject = body.get("subject", "General Support Inquiry")
            channel = body.get("channel", "web_chat")
            message_text = body.get("message_text", "Hello, I need help with my order.")
            ts = now_iso()

            conn = get_db()
            ticket_number = f"SUP-{1000 + int(datetime.now().timestamp() * 100) % 89999}"
            cur = conn.execute("""
                INSERT INTO wc_support_tickets (
                    ticket_number, customer_name, customer_phone, order_number,
                    store_id, subject, channel, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'OPEN', ?, ?)
            """, (ticket_number, customer_name, customer_phone, order_number, store_id, subject, channel, ts, ts))
            tid = cur.lastrowid
            conn.execute("""
                INSERT INTO wc_support_messages (ticket_id, sender_role, sender_name, message_text, created_at)
                VALUES (?, 'CLIENT', ?, ?, ?)
            """, (tid, customer_name, message_text, ts))
            conn.commit()
            tickets = fetch_support_tickets(conn)
            created_ticket = next((t for t in tickets if t["id"] == tid), {})
            conn.close()

            send_push_notification(
                None, "Facilitator Support Desk",
                f"New Live Chat #{ticket_number} from {customer_name} 💬",
                f"[{subject}] {message_text}",
                f"رسالة دعم جديدة ({ticket_number}) من {customer_name}: {message_text}"
            )
            self._send_json({"success": True, "ticket": created_ticket}, 201)
            return

        if self.path.startswith("/wp-json/wc/v3/support/tickets/") and self.path.endswith("/reply"):
            parts = self.path.split("/")
            tid = int(parts[6])
            sender_role = body.get("sender_role", "ADMIN").upper()
            sender_name = body.get("sender_name", "Facilitator Support Desk" if sender_role == "ADMIN" else "Client")
            message_text = body.get("message_text", "")
            ts = now_iso()

            conn = get_db()
            t_row = conn.execute("SELECT * FROM wc_support_tickets WHERE id = ?", (tid,)).fetchone()
            if not t_row:
                conn.close()
                self._send_json({"error": "Support ticket not found"}, 404)
                return
            conn.execute("""
                INSERT INTO wc_support_messages (ticket_id, sender_role, sender_name, message_text, created_at)
                VALUES (?, ?, ?, ?, ?)
            """, (tid, sender_role, sender_name, message_text, ts))
            new_status = body.get("status") or t_row["status"]
            conn.execute("UPDATE wc_support_tickets SET status = ?, updated_at = ? WHERE id = ?", (new_status, ts, tid))
            conn.commit()
            tickets = fetch_support_tickets(conn)
            updated_ticket = next((t for t in tickets if t["id"] == tid), {})
            conn.close()

            if sender_role == "ADMIN":
                send_push_notification(
                    None, "Client Web Chat + Mobile App",
                    f"Support Reply on #{t_row['ticket_number']} 🎧",
                    f"{sender_name}: {message_text}",
                    f"رد خدمة العملاء على التذكرة ({t_row['ticket_number']}): {message_text}"
                )
            self._send_json({"success": True, "ticket": updated_ticket})
            return

        if self.path.startswith("/wp-json/wc/v3/support/tickets/") and self.path.endswith("/status"):
            parts = self.path.split("/")
            tid = int(parts[6])
            new_status = body.get("status", "RESOLVED").upper()
            conn = get_db()
            conn.execute("UPDATE wc_support_tickets SET status = ?, updated_at = ? WHERE id = ?", (new_status, now_iso(), tid))
            conn.commit()
            tickets = fetch_support_tickets(conn)
            updated_ticket = next((t for t in tickets if t["id"] == tid), {})
            conn.close()
            self._send_json({"success": True, "ticket": updated_ticket})
            return

        # 7. Create Order (Splits by Partner Store into Outsourced Store-to-Client Deliveries)
        if self.path == "/wp-json/wc/v3/orders":
            items_req = body.get("items", [])
            if not items_req:
                self._send_json({"error": "Cart is empty"}, 400)
                return

            gov_code = body.get("governorate", "CAIRO")
            payment_method = body.get("payment_method", "paymob_card")
            coupon_code = body.get("coupon_code", "")
            channel = body.get("channel", "web")
            customer_name = body.get("customer_name", "Ahmed Kamal")
            customer_phone = body.get("customer_phone", "01012345678")
            customer_email = body.get("customer_email", "ahmed@example.eg")
            area_street = body.get("area_street", "Nasr City, Makram Ebeid St, Building 14")
            valu_months = int(body.get("valu_months", 12))
            instapay_ipa = body.get("instapay_ipa", "ahmed.kamal@instapay")

            calc = calculate_cart_totals(items_req, gov_code, payment_method, coupon_code)

            for it in calc["items"]:
                if it["available_stock"] < it["quantity"]:
                    self._send_json({
                        "error": f"Insufficient store stock at {it['store_name']} for {it['name_en']} (Available: {it['available_stock']})"
                    }, 400)
                    return

            method_titles = {
                "paymob_card": "Paymob Split (Visa / Mastercard / Meeza / Apple Pay)",
                "paymob_wallet": "Paymob Mobile Wallet (Vodafone / Orange / e& Cash)",
                "valu_bnpl": f"valU Buy Now, Pay Later ({valu_months} Months)",
                "fawry_ref": "FawryPay Kiosk Reference Code (48h Store Stock Hold)",
                "instapay_qr": "InstaPay Egypt (IPA Instant Transfer Verification)",
                "cod": "Cash on Delivery (COD + WhatsApp OTP)"
            }
            payment_title = method_titles.get(payment_method, payment_method)

            conn = get_db()
            cur = conn.cursor()
            order_number = f"EG-{int(datetime.now().timestamp() * 1000) % 100000}-{random.randint(10, 99)}"
            ts = now_iso()

            delivery_pin = f"{random.randint(1000, 9999)}"
            initial_order_status = "pending-store-review"
            initial_pay_status = "pre_authorized" if payment_method in ("paymob_card", "paymob_wallet") else "pending"

            cur.execute("""
                INSERT INTO wc_orders (
                    order_number, channel, customer_name, customer_phone, customer_email,
                    governorate, area_street, payment_method, payment_title,
                    payment_status, order_status, subtotal_egp, discount_egp,
                    vat_egp, shipping_egp, cod_fee_egp, total_egp,
                    platform_commission_egp, net_stores_payout_egp,
                    coupon_code, delivery_pin, store_review_status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING_STORE_REVIEW', ?, ?)
            """, (
                order_number, channel, customer_name, customer_phone, customer_email,
                gov_code, area_street, payment_method, payment_title,
                initial_pay_status, initial_order_status,
                calc["subtotal_egp"], calc["discount_egp"], calc.get("vat_egp", 0.0), calc["shipping_egp"],
                calc["cod_fee_egp"], calc["total_egp"],
                calc["platform_commission_egp"], calc["net_stores_payout_egp"],
                calc["coupon_applied"], delivery_pin, ts, ts
            ))
            order_id = cur.lastrowid

            # Group items by Partner Store to create Per-Store Outsourced Delivery Manifests!
            store_groups = {}
            for it in calc["items"]:
                cur.execute("""
                    INSERT INTO wc_order_items (
                        order_id, store_id, store_name, product_id, category_id,
                        sku, name_en, quantity, unit_price_egp, line_total_egp,
                        commission_pct, platform_commission_egp, net_store_payout_egp
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    order_id, it["store_id"], it["store_name"], it["product_id"], it["category_id"],
                    it["sku"], it["name_en"], it["quantity"], it["unit_price_egp"], it["line_total_egp"],
                    it["commission_pct"], it["platform_commission_egp"], it["net_store_payout_egp"]
                ))
                cur.execute("""
                    UPDATE wc_products
                    SET reserved_quantity = reserved_quantity + ?
                    WHERE id = ?
                """, (it["quantity"], it["product_id"]))

                sid = it["store_id"]
                if sid not in store_groups:
                    store_groups[sid] = {
                        "store_id": sid,
                        "store_name": it["store_name"],
                        "store_phone": it["store_phone"],
                        "pickup_gov": it["store_gov"],
                        "pickup_address": it["store_address"],
                        "items_list": [],
                        "store_subtotal": 0.0,
                        "commission_egp": 0.0,
                        "net_payout_egp": 0.0
                    }
                store_groups[sid]["items_list"].append(f"{it['quantity']}x {it['name_en']}")
                store_groups[sid]["store_subtotal"] = round(store_groups[sid]["store_subtotal"] + it["line_total_egp"], 2)
                store_groups[sid]["commission_egp"] = round(store_groups[sid]["commission_egp"] + it["platform_commission_egp"], 2)
                store_groups[sid]["net_payout_egp"] = round(store_groups[sid]["net_payout_egp"] + it["net_store_payout_egp"], 2)

            # Create Outsourced Delivery rows per Partner Store
            store_splits_meta = []
            for idx, (sid, grp) in enumerate(store_groups.items()):
                # Assign COD collection to the first delivery or proportional if COD
                cod_for_this_shipment = calc["total_egp"] if (payment_method == "cod" and idx == 0) else 0.0
                cur.execute("""
                    INSERT INTO wc_deliveries (
                        order_id, order_number, store_id, store_name, store_phone,
                        pickup_governorate, pickup_address,
                        customer_name, customer_phone, dropoff_governorate, dropoff_address,
                        items_summary, store_subtotal_egp, platform_commission_egp, net_store_payout_egp,
                        cod_to_collect_egp, packaging_status, courier_provider, courier_status,
                        delivery_pin, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'AWAITING_STORE_AVAILABILITY', 'Bosta 3PL', 'AWAITING_STORE_REVIEW', ?, ?, ?)
                """, (
                    order_id, order_number, sid, grp["store_name"], grp["store_phone"],
                    grp["pickup_gov"], grp["pickup_address"],
                    customer_name, customer_phone, gov_code, area_street,
                    ", ".join(grp["items_list"]),
                    grp["store_subtotal"], grp["commission_egp"], grp["net_payout_egp"],
                    cod_for_this_shipment, delivery_pin, ts, ts
                ))
                store_splits_meta.append({
                    "store_id": sid,
                    "store_name": grp["store_name"],
                    "net_store_payout_egp": grp["net_payout_egp"],
                    "platform_commission_egp": grp["commission_egp"]
                })

            conn.commit()
            conn.close()

            # Orchestrate with Mockup Integration Server (Port 4001)
            gateway_ref = ""
            gateway_meta = {}
            payment_status = "pending"
            order_status = "pending"

            if payment_method in ("paymob_card", "paymob_wallet"):
                sub = "vodafone_cash" if payment_method == "paymob_wallet" else ("apple_pay" if channel == "ios_app" else "card_meeza")
                resp = call_mock_server("/mock/paymob/v1/intention", {
                    "order_id": order_id,
                    "amount_egp": calc["total_egp"],
                    "payment_submethod": sub,
                    "store_splits": store_splits_meta
                })
                intention = resp.get("intention", {})
                gateway_ref = intention.get("intention_id", f"pi_local_{order_id}")
                gateway_meta = intention
                payment_status = "pre_authorized"
                order_status = "pending-store-review"

            elif payment_method == "fawry_ref":
                resp = call_mock_server("/mock/fawry/v2/charge", {
                    "order_id": order_id,
                    "amount_egp": calc["total_egp"]
                })
                fawry = resp.get("fawry", {})
                gateway_ref = fawry.get("fawry_ref", "9123456789")
                gateway_meta = fawry
                payment_status = "on-hold-fawry"
                order_status = "pending-store-review"
                send_push_notification(
                    order_id, channel,
                    f"Fawry Code: {gateway_ref} 🧾",
                    f"Pay {calc['total_egp']} EGP at any Fawry kiosk within 48h. Partner Store inventory is reserved for you!",
                    f"كود فوري الخاص بك هو {gateway_ref} بقيمة {calc['total_egp']} ج.م (تم حجز المنتج من المتجر لمدة 48 ساعة)."
                )

            elif payment_method == "valu_bnpl":
                resp = call_mock_server("/mock/valu/v1/plans", {
                    "order_id": order_id,
                    "amount_egp": calc["total_egp"],
                    "months": valu_months,
                    "phone": customer_phone
                })
                valu = resp.get("valu", {})
                gateway_ref = valu.get("valu_id", f"VALU-{order_id}")
                gateway_meta = valu
                payment_status = "pre_authorized"
                order_status = "pending-store-review"

            elif payment_method == "instapay_qr":
                gateway_ref = f"IPA-{int(datetime.now().timestamp()) % 100000}"
                gateway_meta = {
                    "merchant_ipa": "egyptstore@instapay",
                    "customer_ipa": instapay_ipa,
                    "transfer_ref": gateway_ref,
                    "amount_egp": calc["total_egp"],
                    "store_splits": store_splits_meta,
                    "status": "AWAITING_ADMIN_VERIFICATION"
                }
                payment_status = "awaiting-instapay"
                order_status = "pending-store-review"

            elif payment_method == "cod":
                resp = call_mock_server("/mock/whatsapp/v1/send-otp", {
                    "order_id": order_id,
                    "phone": customer_phone,
                    "total_egp": calc["total_egp"],
                    "otp": "4455"
                })
                wa = resp.get("whatsapp", {})
                gateway_ref = f"WA-OTP-{wa.get('otp_code', '4455')}"
                gateway_meta = wa
                payment_status = "pending"
                order_status = "pending-store-review"

            conn = get_db()
            conn.execute("""
                UPDATE wc_orders
                SET gateway_ref = ?, gateway_meta = ?, payment_status = ?, order_status = ?, updated_at = ?
                WHERE id = ?
            """, (gateway_ref, json.dumps(gateway_meta, ensure_ascii=False), payment_status, order_status, now_iso(), order_id))
            conn.commit()

            created_order = dict(conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone())
            created_order["items"] = calc["items"]
            created_order["deliveries"] = [dict(d) for d in conn.execute("SELECT * FROM wc_deliveries WHERE order_id = ?", (order_id,)).fetchall()]
            created_order["gateway_meta"] = gateway_meta
            conn.close()

            self._send_json({"success": True, "order": created_order}, 201)
            return

        
        # =====================================================================
        # 14-STEP E-COMMERCE JOURNEY SPECIALIZED ENDPOINTS
        # =====================================================================

        # STEP 5: Partner Store Reviews Availability & De-selects Unavailable Items
        if self.path.startswith("/wp-json/wc/v3/orders/") and self.path.endswith("/store-review"):
            parts = self.path.split("/")
            order_id = int(parts[5])
            items_review = body.get("items", []) # list of {"product_id": id, "available": True/False}
            store_id = body.get("store_id")

            conn = get_db()
            order_row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()
            if not order_row:
                conn.close()
                self._send_json({"error": "Order not found"}, 404)
                return

            order = dict(order_row)
            order_items = [dict(i) for i in conn.execute("SELECT * FROM wc_order_items WHERE order_id = ?", (order_id,)).fetchall()]

            # Update availability per item
            for rev in items_review:
                pid = int(rev.get("product_id", 0))
                is_avail = bool(rev.get("available", True))
                matching_item = next((it for it in order_items if it["product_id"] == pid), None)
                if matching_item:
                    new_item_status = "AVAILABLE" if is_avail else "OUT_OF_STOCK"
                    conn.execute("UPDATE wc_order_items SET item_status = ? WHERE order_id = ? AND product_id = ?",
                                 (new_item_status, order_id, pid))
                    if not is_avail:
                        # Return reserved stock to store
                        conn.execute("UPDATE wc_products SET reserved_quantity = MAX(0, reserved_quantity - ?) WHERE id = ?",
                                     (matching_item["quantity"], pid))

            conn.commit()

            # Recalculate totals based on available items only
            updated_items = [dict(i) for i in conn.execute("SELECT * FROM wc_order_items WHERE order_id = ?", (order_id,)).fetchall()]
            active_items = [it for it in updated_items if it.get("item_status") != "OUT_OF_STOCK"]

            new_subtotal = round(sum(it["line_total_egp"] for it in active_items), 2)
            new_commission = round(sum(it["platform_commission_egp"] for it in active_items), 2)
            new_stores_payout = round(sum(it["net_store_payout_egp"] for it in active_items), 2)
            vat_egp = round(new_subtotal * (14.0 / 114.0), 2) if new_subtotal > 0 else 0.0
            new_total = round(new_subtotal + order["shipping_egp"] + (order["cod_fee_egp"] if order["payment_method"] == "cod" else 0.0), 2) if new_subtotal > 0 else 0.0

            conn.execute("""
                UPDATE wc_orders
                SET order_status = 'store-reviewed',
                    store_review_status = 'STORE_CONFIRMED',
                    subtotal_egp = ?,
                    vat_egp = ?,
                    total_egp = ?,
                    platform_commission_egp = ?,
                    net_stores_payout_egp = ?,
                    updated_at = ?
                WHERE id = ?
            """, (new_subtotal, vat_egp, new_total, new_commission, new_stores_payout, now_iso(), order_id))

            # Update deliveries store_subtotal and cod_to_collect if COD
            if order["payment_method"] == "cod":
                conn.execute("UPDATE wc_deliveries SET cod_to_collect_egp = ? WHERE order_id = ?", (new_total, order_id))

            conn.commit()
            enriched = enrich_order_dict(dict(conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()), conn)
            conn.close()

            removed_count = len(updated_items) - len(active_items)
            removed_msg = f" ({removed_count} item(s) out of stock removed)" if removed_count > 0 else ""
            send_push_notification(
                order_id, order["channel"],
                f"Store Verified Availability for Order #{order['order_number']} 📋",
                f"Items confirmed available{removed_msg}. Updated Total: {new_total} EGP. Please review and confirm in My Orders.",
                f"قام المتجر بتأكيد توفر المنتجات{removed_msg}. الإجمالي الجديد {new_total} ج.م. يرجى تأكيد الطلب للمتابعة."
            )
            self._send_json({"success": True, "action": "store_review_completed", "order": enriched})
            return

        # STEP 6 & 7: Client Confirms (Money Taken from Card) or Rejects (Order Rejected)
        if self.path.startswith("/wp-json/wc/v3/orders/") and self.path.endswith("/client-confirm"):
            parts = self.path.split("/")
            order_id = int(parts[5])
            action = str(body.get("action", "CONFIRM")).upper() # CONFIRM or REJECT

            conn = get_db()
            order_row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()
            if not order_row:
                conn.close()
                self._send_json({"error": "Order not found"}, 404)
                return

            order = dict(order_row)
            ts = now_iso()

            if action == "REJECT":
                # Step 6: Order rejected -> cancel order, release remaining reserved stock
                conn.execute("""
                    UPDATE wc_orders
                    SET order_status = 'cancelled',
                        store_review_status = 'REJECTED_BY_CLIENT',
                        payment_status = 'voided',
                        updated_at = ?
                    WHERE id = ?
                """, (ts, order_id))

                # Release remaining reserved stock
                active_items = conn.execute("SELECT product_id, quantity FROM wc_order_items WHERE order_id = ? AND item_status = 'AVAILABLE'", (order_id,)).fetchall()
                for it in active_items:
                    conn.execute("UPDATE wc_products SET reserved_quantity = MAX(0, reserved_quantity - ?) WHERE id = ?", (it["quantity"], it["product_id"]))

                conn.execute("UPDATE wc_deliveries SET courier_status = 'CANCELLED_BY_CLIENT', updated_at = ? WHERE order_id = ?", (ts, order_id))
                conn.commit()
                enriched = enrich_order_dict(dict(conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()), conn)
                conn.close()

                send_push_notification(
                    order_id, order["channel"],
                    f"Order #{order['order_number']} Rejected & Cancelled ❌",
                    "You rejected the updated order. No money was taken from your card, and store stock has been released.",
                    f"تم رفض الطلب #{order['order_number']} وإلغاؤه. لم يتم خصم أي مبالغ من بطاقتك."
                )
                self._send_json({"success": True, "action": "order_rejected", "order": enriched})
                return

            # STEP 7: Client Confirms -> Money is taken from client card (Captured)!
            new_pay_status = "paid" if order["payment_method"] in ("paymob_card", "paymob_wallet", "apple_pay", "card_meeza", "valu_bnpl", "instapay_qr") else "pending_cod_collection"
            conn.execute("""
                UPDATE wc_orders
                SET order_status = 'processing',
                    store_review_status = 'CLIENT_CONFIRMED',
                    payment_status = ?,
                    updated_at = ?
                WHERE id = ?
            """, (new_pay_status, ts, order_id))

            conn.execute("""
                UPDATE wc_deliveries
                SET packaging_status = 'AWAITING_STORE_PACKAGING',
                    courier_status = 'STORE_PACKING_IN_PROGRESS',
                    updated_at = ?
                WHERE order_id = ?
            """, (ts, order_id))
            conn.commit()

            # Finalize stock deduction for confirmed items
            finalize_stock_deduction(order_id)
            auto_dispatch_bosta_awb(order_id)

            enriched = enrich_order_dict(dict(conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()), conn)
            conn.close()

            pay_note = f"Money taken from your card ({order['total_egp']} EGP captured)" if new_pay_status == "paid" else f"COD Order Confirmed ({order['total_egp']} EGP to pay on delivery)"
            send_push_notification(
                order_id, order["channel"],
                f"Order #{order['order_number']} Confirmed & Paid! 💳",
                f"{pay_note}. Partner store is now packing your order.",
                f"تم تأكيد الطلب بنجاح! {pay_note}. جاري تجهيز الشحنة بالمتجر."
            )
            self._send_json({"success": True, "action": "order_confirmed_and_paid", "order": enriched})
            return

        # STEP 9: Search for Nearest Delivery Courier & Assign
        if self.path.startswith("/wp-json/wc/v3/deliveries/") and self.path.endswith("/assign-courier"):
            parts = self.path.split("/")
            delivery_id = int(parts[5])
            courier_name = body.get("courier_name", "Tarek Mostafa")
            courier_phone = body.get("courier_phone", "01098765432")
            courier_vehicle = body.get("courier_vehicle", "🛵 Motorcycle (Honda CB)")
            courier_distance = float(body.get("courier_distance_km", 0.8))
            ts = now_iso()

            conn = get_db()
            deliv_row = conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone()
            if not deliv_row:
                conn.close()
                self._send_json({"error": "Delivery record not found"}, 404)
                return

            deliv = dict(deliv_row)
            conn.execute("""
                UPDATE wc_deliveries
                SET courier_name = ?, courier_phone = ?, courier_vehicle = ?, courier_distance_km = ?,
                    courier_status = 'COURIER_ASSIGNED', updated_at = ?
                WHERE id = ?
            """, (courier_name, courier_phone, courier_vehicle, courier_distance, ts, delivery_id))

            conn.execute("""
                UPDATE wc_orders
                SET assigned_courier_name = ?, assigned_courier_phone = ?, assigned_courier_vehicle = ?, updated_at = ?
                WHERE id = ?
            """, (courier_name, courier_phone, courier_vehicle, ts, deliv["order_id"]))
            conn.commit()

            updated_deliv = dict(conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone())
            conn.close()

            send_push_notification(
                deliv["order_id"], "Client & Partner Store",
                f"Nearest Courier Assigned! 🛵",
                f"Courier {courier_name} ({courier_vehicle}, {courier_distance} km away) is heading to {deliv['store_name']} to pick up your parcel.",
                f"تم تعيين أقرب مندوب ({courier_name}) يبعد {courier_distance} كم ومتجه للمتجر لاستلام الطرد."
            )
            self._send_json({"success": True, "delivery": updated_deliv})
            return

        # STEP 10 & 11: Delivery Guy Confirms Pickup & Client Gets Pickup Notification
        if self.path.startswith("/wp-json/wc/v3/deliveries/") and self.path.endswith("/courier-pickup"):
            parts = self.path.split("/")
            delivery_id = int(parts[5])
            ts = now_iso()

            conn = get_db()
            deliv_row = conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone()
            if not deliv_row:
                conn.close()
                self._send_json({"error": "Delivery record not found"}, 404)
                return

            deliv = dict(deliv_row)
            c_name = deliv.get("courier_name") or "Bosta Courier"
            c_phone = deliv.get("courier_phone") or "01098765432"

            conn.execute("""
                UPDATE wc_deliveries
                SET courier_status = 'PICKED_UP_FROM_STORE', updated_at = ?
                WHERE id = ?
            """, (ts, delivery_id))

            conn.execute("""
                UPDATE wc_orders
                SET order_status = 'in-transit', updated_at = ?
                WHERE id = ?
            """, (ts, deliv["order_id"]))
            conn.commit()

            updated_deliv = dict(conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone())
            conn.close()

            # STEP 11: Client gets notification of pickup
            send_push_notification(
                deliv["order_id"], "Client Storefront & Mobile App",
                f"Package Picked Up from {deliv['store_name']} 🚚",
                f"Courier {c_name} (📞 {c_phone}) picked up your package and is on the way to your delivery address!",
                f"قام المندوب ({c_name}) باستلام طردك من فرع ({deliv['store_name']}) وهو الآن في الطريق إليك."
            )
            self._send_json({"success": True, "action": "courier_picked_up", "delivery": updated_deliv})
            return

        # STEP 12: Delivery Guy Reaches Client Address
        if self.path.startswith("/wp-json/wc/v3/deliveries/") and self.path.endswith("/courier-arrived"):
            parts = self.path.split("/")
            delivery_id = int(parts[5])
            ts = now_iso()

            conn = get_db()
            deliv_row = conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone()
            if not deliv_row:
                conn.close()
                self._send_json({"error": "Delivery record not found"}, 404)
                return

            deliv = dict(deliv_row)
            c_name = deliv.get("courier_name") or "Bosta Courier"

            conn.execute("""
                UPDATE wc_deliveries
                SET courier_status = 'ARRIVED_AT_CLIENT', updated_at = ?
                WHERE id = ?
            """, (ts, delivery_id))
            conn.commit()

            updated_deliv = dict(conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone())
            conn.close()

            send_push_notification(
                deliv["order_id"], "Client Storefront & Mobile App",
                f"Courier Has Arrived! 📍",
                f"Courier {c_name} is outside your address. Please meet the courier with your Handover Code or COD payment.",
                f"وصل المندوب ({c_name}) إلى موقعك. يرجى مقابلة المندوب وإعطاؤه كود الاستلام أو دفع قيمة الشحنة."
            )
            self._send_json({"success": True, "action": "courier_arrived", "delivery": updated_deliv})
            return

        # STEP 13 & 14: Handover Code Verification & Package Handover (or COD without code)
        if self.path.startswith("/wp-json/wc/v3/deliveries/") and self.path.endswith("/verify-handover"):
            parts = self.path.split("/")
            delivery_id = int(parts[5])
            entered_pin = str(body.get("pin", "")).strip()
            ts = now_iso()

            conn = get_db()
            deliv_row = conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone()
            if not deliv_row:
                conn.close()
                self._send_json({"error": "Delivery record not found"}, 404)
                return

            deliv = dict(deliv_row)
            order_row = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (deliv["order_id"],)).fetchone()
            order = dict(order_row) if order_row else {}

            is_cod = order.get("payment_method") == "cod"

            # "In case of cash on delivery, no need for the code."
            if not is_cod:
                expected_pin = str(deliv.get("delivery_pin") or order.get("delivery_pin") or "").strip()
                if entered_pin != expected_pin:
                    conn.close()
                    self._send_json({
                        "error": f"Invalid Handover Code '{entered_pin}'. Please ask the client for the 4-digit PIN in their app.",
                        "expected_pin_hint": expected_pin[:2] + "**"
                    }, 400)
                    return

            # Code verified or COD cash collected! Mark DELIVERED
            cod_collected = deliv["cod_to_collect_egp"] if is_cod else 0.0
            conn.execute("""
                UPDATE wc_deliveries
                SET courier_status = 'DELIVERED',
                    settlement_status = 'ELIGIBLE_FOR_SETTLEMENT',
                    cod_to_collect_egp = ?,
                    updated_at = ?
                WHERE id = ?
            """, (cod_collected, ts, delivery_id))
            conn.commit()

            # Check if all deliveries for this order are DELIVERED
            other_delivs = conn.execute("SELECT courier_status FROM wc_deliveries WHERE order_id = ?", (deliv["order_id"],)).fetchall()
            all_done = all(r["courier_status"] == "DELIVERED" for r in other_delivs)

            if all_done:
                new_ord_status = "completed"
                new_pay_status = "paid" if not is_cod else "cod_collected_by_courier"
                conn.execute("""
                    UPDATE wc_orders
                    SET order_status = ?, payment_status = ?, updated_at = ?
                    WHERE id = ?
                """, (new_ord_status, new_pay_status, ts, deliv["order_id"]))
                conn.commit()

            conn.close()

            # Trigger automated Cash Settlement Payout via mock server
            settle_resp = call_mock_server("/mock/settlement/v1/payout", {
                "order_id": deliv["order_id"],
                "order_number": deliv["order_number"],
                "delivery_id": deliv["id"],
                "store_id": deliv["store_id"],
                "store_name": deliv["store_name"],
                "payment_method": order.get("payment_method", "paymob_card"),
                "bosta_awb": deliv.get("bosta_awb", ""),
                "gross_amount_egp": deliv["store_subtotal_egp"],
                "platform_commission_egp": deliv["platform_commission_egp"],
                "net_store_payout_egp": deliv["net_store_payout_egp"],
                "cod_collected_egp": cod_collected
            })

            conn = get_db()
            final_deliv = dict(conn.execute("SELECT * FROM wc_deliveries WHERE id = ?", (delivery_id,)).fetchone())
            final_order = enrich_order_dict(dict(conn.execute("SELECT * FROM wc_orders WHERE id = ?", (deliv["order_id"],)).fetchone()), conn)
            settlement_row = conn.execute("SELECT * FROM wc_settlements WHERE delivery_id = ?", (delivery_id,)).fetchone()
            conn.close()

            success_msg = f"Handover Code {entered_pin} Verified! Package handed over to client." if not is_cod else f"COD Cash ({cod_collected} EGP) Collected! Package handed over to client."
            send_push_notification(
                deliv["order_id"], "Client & Store & Delivery",
                f"Delivery Successfully Completed! ✅",
                f"{success_msg} Payout settled to {deliv['store_name']}.",
                f"تم تسليم الطرد بنجاح! {success_msg} وتمت التسوية المالية للمتجر."
            )
            self._send_json({
                "success": True,
                "action": "delivery_handover_completed",
                "verified_pin": entered_pin if not is_cod else "COD_NO_PIN_REQUIRED",
                "delivery": final_deliv,
                "order": final_order,
                "settlement": dict(settlement_row) if settlement_row else settle_resp.get("settlement", {})
            })
            return

        # 8. Admin Approves InstaPay Transfer Receipt
        if self.path.startswith("/wp-json/wc/v3/orders/") and self.path.endswith("/instapay-approve"):
            parts = self.path.split("/")
            order_id = int(parts[5])
            conn = get_db()
            order = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()
            if not order:
                conn.close()
                self._send_json({"error": "Order not found"}, 404)
                return
            conn.execute("""
                UPDATE wc_orders
                SET payment_status = 'paid', order_status = 'processing', updated_at = ?
                WHERE id = ?
            """, (now_iso(), order_id))
            conn.commit()
            conn.close()

            log_webhook("ADMIN_ACTION", "INSTAPAY", "INSTAPAY.RECEIPT_APPROVED", 1, {"order_id": order_id})
            finalize_stock_deduction(order_id)
            auto_dispatch_bosta_awb(order_id)
            self._send_json({"success": True, "order_id": order_id, "status": "paid_and_dispatched"})
            return

        # =====================================================================
        # INBOUND HMAC-VERIFIED WEBHOOK RECEIVERS FROM PORT 4001 MOCK SERVER
        # =====================================================================
        if self.path.startswith("/wp-json/wc/v3/webhooks/"):
            hmac_ok = 1 if self._verify_hmac(raw_bytes) else 0
            hook_type = self.path.split("/")[-1]
            log_webhook("INBOUND_WEBHOOK", hook_type.upper(), body.get("event", hook_type), hmac_ok, body)

            if not hmac_ok:
                self._send_json({"error": "Invalid HMAC-SHA512 signature"}, 401)
                return

            order_id = int(body.get("order_id", 0))
            conn = get_db()
            order = conn.execute("SELECT * FROM wc_orders WHERE id = ?", (order_id,)).fetchone()
            if not order:
                conn.close()
                self._send_json({"error": "Order not found"}, 404)
                return

            if hook_type == "paymob":
                if body.get("success"):
                    conn.execute("""
                        UPDATE wc_orders
                        SET payment_status = 'paid', order_status = 'processing', updated_at = ?
                        WHERE id = ?
                    """, (now_iso(), order_id))
                    conn.commit()
                    conn.close()
                    finalize_stock_deduction(order_id)
                    auto_dispatch_bosta_awb(order_id)
                else:
                    conn.execute("""
                        UPDATE wc_orders
                        SET payment_status = 'failed', order_status = 'cancelled', updated_at = ?
                        WHERE id = ?
                    """, (now_iso(), order_id))
                    conn.commit()
                    conn.close()
                    release_reserved_stock(order_id)
                self._send_json({"received": True, "hmac_verified": True})
                return

            if hook_type == "fawry":
                fawry_status = body.get("orderStatus", "PAID")
                if fawry_status == "PAID":
                    conn.execute("""
                        UPDATE wc_orders
                        SET payment_status = 'paid', order_status = 'processing', updated_at = ?
                        WHERE id = ?
                    """, (now_iso(), order_id))
                    conn.commit()
                    conn.close()
                    finalize_stock_deduction(order_id)
                    auto_dispatch_bosta_awb(order_id)
                else:
                    conn.execute("""
                        UPDATE wc_orders
                        SET payment_status = 'expired', order_status = 'cancelled', updated_at = ?
                        WHERE id = ?
                    """, (now_iso(), order_id))
                    conn.commit()
                    conn.close()
                    release_reserved_stock(order_id)
                self._send_json({"received": True, "hmac_verified": True})
                return

            if hook_type == "valu":
                conn.execute("""
                    UPDATE wc_orders
                    SET payment_status = 'paid', order_status = 'processing', updated_at = ?
                    WHERE id = ?
                """, (now_iso(), order_id))
                conn.commit()
                conn.close()
                finalize_stock_deduction(order_id)
                auto_dispatch_bosta_awb(order_id)
                self._send_json({"received": True, "hmac_verified": True})
                return

            if hook_type == "whatsapp-otp":
                conn.execute("""
                    UPDATE wc_orders
                    SET payment_status = 'cod-confirmed', order_status = 'processing', updated_at = ?
                    WHERE id = ?
                """, (now_iso(), order_id))
                conn.commit()
                conn.close()
                finalize_stock_deduction(order_id)
                auto_dispatch_bosta_awb(order_id)
                self._send_json({"received": True, "hmac_verified": True})
                return

            if hook_type == "bosta":
                bosta_state = body.get("state", "PICKED_UP_FROM_STORE")
                awb = body.get("awb")
                new_order_status = order["order_status"]
                new_pay_status = order["payment_status"]
                if bosta_state in ("PICKED_UP_FROM_STORE", "IN_TRANSIT", "OUT_FOR_DELIVERY"):
                    new_order_status = "shipped"
                elif bosta_state == "DELIVERED":
                    new_order_status = "delivered"
                    if order["payment_method"] == "cod":
                        new_pay_status = "paid"
                elif bosta_state == "NDR_UNREACHABLE":
                    new_order_status = "ndr-action-required"

                if awb:
                    if bosta_state == "DELIVERED":
                        conn.execute("""
                            UPDATE wc_deliveries
                            SET courier_status = ?,
                                settlement_status = CASE WHEN settlement_status = 'SETTLED_TO_STORE' THEN 'SETTLED_TO_STORE' ELSE 'ELIGIBLE_FOR_SETTLEMENT' END,
                                updated_at = ?
                            WHERE bosta_awb = ?
                        """, (bosta_state, now_iso(), awb))
                    else:
                        conn.execute("""
                            UPDATE wc_deliveries
                            SET courier_status = ?, updated_at = ?
                            WHERE bosta_awb = ?
                        """, (bosta_state, now_iso(), awb))

                conn.execute("""
                    UPDATE wc_orders
                    SET bosta_status = ?, order_status = ?, payment_status = ?, updated_at = ?
                    WHERE id = ?
                """, (bosta_state, new_order_status, new_pay_status, now_iso(), order_id))
                conn.commit()
                conn.close()

                send_push_notification(
                    order_id, order["channel"],
                    f"Outsourced Delivery Update: {bosta_state} 🚚",
                    f"Bosta AWB {awb} ({body.get('route', '')}) is now {bosta_state}.",
                    f"تحديث توصيل بوسطة ({awb}): {bosta_state}."
                )
                self._send_json({"received": True, "hmac_verified": True})
                return

            if hook_type == "settlement":
                delivery_id = int(body.get("delivery_id", 0))
                settlement_ref = body.get("settlement_ref", f"STL-{delivery_id}")
                settled_at = body.get("settled_at", now_iso())
                payout_rail = body.get("payout_rail", "Paymob Split / InstaPay Payout")

                conn.execute("""
                    INSERT OR IGNORE INTO wc_settlements (
                        settlement_ref, delivery_id, order_id, order_number,
                        store_id, store_name, payment_method, bosta_awb,
                        gross_amount_egp, platform_commission_egp, net_store_payout_egp,
                        cod_collected_egp, payout_rail, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    settlement_ref, delivery_id, order_id, body.get("order_number", order["order_number"]),
                    int(body.get("store_id", 1)), body.get("store_name", "Partner Store"),
                    body.get("payment_method", order["payment_method"]), body.get("bosta_awb", ""),
                    float(body.get("gross_amount_egp", 0.0)), float(body.get("platform_commission_egp", 0.0)),
                    float(body.get("net_store_payout_egp", 0.0)), float(body.get("cod_collected_egp", 0.0)),
                    payout_rail, settled_at
                ))

                conn.execute("""
                    UPDATE wc_deliveries
                    SET settlement_status = 'SETTLED_TO_STORE',
                        settlement_ref = ?,
                        settled_at = ?,
                        updated_at = ?
                    WHERE id = ?
                """, (settlement_ref, settled_at, settled_at, delivery_id))

                # Check if all deliveries for this order are now settled
                unsettled_cnt = conn.execute("""
                    SELECT COUNT(*) AS cnt FROM wc_deliveries
                    WHERE order_id = ? AND settlement_status != 'SETTLED_TO_STORE'
                """, (order_id,)).fetchone()["cnt"]
                if unsettled_cnt == 0:
                    conn.execute("""
                        UPDATE wc_orders
                        SET order_status = 'completed-settled', payment_status = 'settled', updated_at = ?
                        WHERE id = ?
                    """, (settled_at, order_id))

                conn.commit()
                conn.close()

                send_push_notification(
                    order_id, "Partner Store + Facilitator Finance",
                    f"Cash Settlement Completed ({settlement_ref}) 💸",
                    f"Settled {body.get('net_store_payout_egp')} EGP to {body.get('store_name')} & realized {body.get('platform_commission_egp')} EGP Facilitator Commission ({payout_rail}).",
                    f"تمت التسوية المالية ({settlement_ref}): تحويل {body.get('net_store_payout_egp')} ج.م للمتجر وتحصيل عمولة المنصة ({body.get('platform_commission_egp')} ج.م)."
                )
                self._send_json({"received": True, "hmac_verified": True, "settlement_ref": settlement_ref})
                return

            conn.close()
            self._send_json({"received": True})
            return

        self._send_json({"error": "Unknown POST endpoint"}, 404)


if __name__ == "__main__":
    init_db()
    print(f"Starting Core Egypt Marketplace Facilitator PoC Server (Dual-Stack IPv4/IPv6) on http://localhost:{PORT} ...")
    server = DualStackHTTPServer(("::", PORT), EcommerceRequestHandler)
    server.serve_forever()
