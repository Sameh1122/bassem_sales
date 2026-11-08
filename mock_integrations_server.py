#!/usr/bin/env python3
"""
Egyptian E-Commerce Integrations Mockup Server (Port 4001)
Supports Multi-Store Marketplace Facilitator + Outsourced Delivery Model:
  1. Paymob Accept / Split Payment Intention API (Cards, Meeza, Apple Pay, Vodafone Cash)
  2. FawryPay Reference Code API (OTC Kiosk Cash Payment & 48h Stock Hold)
  3. valU BNPL API (6 / 12 / 24 Month Installment Plans)
  4. WhatsApp Cloud API (Automated COD OTP Confirmation)
  5. Bosta Outsourced Delivery API (Store-to-Client Multi-Origin Pickup AWBs & Settlement)
"""

import hashlib
import hmac
import io
import json
import os
import random
import socket
import time
import urllib.request
import urllib.error
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MOCK_PORT = 4001
ECOMMERCE_WEBHOOK_BASE = "http://127.0.0.1:4000/wp-json/wc/v3/webhooks"
SHARED_HMAC_SECRET = "egypt_poc_hmac_secret_2026"


class _InMemorySocket:
    def __init__(self, req_bytes: bytes):
        self._rfile = io.BytesIO(req_bytes)
        self._wfile = io.BytesIO()

    def makefile(self, mode: str, *args, **kwargs):
        return self._rfile if "r" in mode else self._wfile

    def sendall(self, data: bytes):
        self._wfile.write(data)

    def close(self):
        pass


def invoke_handler_in_memory(handler_cls, method: str, path: str, body_bytes: bytes = b"", headers: dict = None) -> tuple:
    hdrs = {"Host": "localhost", "Content-Type": "application/json", "Content-Length": str(len(body_bytes))}
    if headers:
        hdrs.update(headers)
    header_lines = "".join(f"{k}: {v}\r\n" for k, v in hdrs.items())
    raw_req = f"{method} {path} HTTP/1.1\r\n{header_lines}\r\n".encode("utf-8") + body_bytes
    sock = _InMemorySocket(raw_req)
    handler_cls(sock, ("127.0.0.1", 0), None)
    raw_resp = sock._wfile.getvalue()
    parts = raw_resp.split(b"\r\n\r\n", 1)
    status_line = parts[0].splitlines()[0].decode("utf-8", errors="ignore")
    try:
        status_code = int(status_line.split(" ")[1])
    except Exception:
        status_code = 200
    resp_body_bytes = parts[1] if len(parts) > 1 else b"{}"
    return status_code, resp_body_bytes


class DualStackHTTPServer(ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()

STATE = {
    "paymob_intentions": {},
    "fawry_references": {},
    "valu_requests": {},
    "whatsapp_otps": {},
    "bosta_shipments": {},
    "settlement_payouts": {},
    "webhook_outbox": []
}


def now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def compute_hmac(payload_bytes: bytes) -> str:
    return hmac.new(
        SHARED_HMAC_SECRET.encode("utf-8"),
        payload_bytes,
        hashlib.sha512
    ).hexdigest()


def dispatch_webhook(endpoint: str, payload: dict) -> dict:
    webhook_path = f"/wp-json/wc/v3/webhooks/{endpoint}"
    url = f"{ECOMMERCE_WEBHOOK_BASE}/{endpoint}"
    raw_bytes = json.dumps(payload).encode("utf-8")
    signature = compute_hmac(raw_bytes)
    headers = {
        "Content-Type": "application/json",
        "X-Egypt-HMAC-SHA512": signature,
        "User-Agent": "Egypt-Mock-Gateway/2.1"
    }

    status_code = 0
    response_body = {}
    if os.environ.get("VERCEL"):
        from ecommerce_server import EcommerceRequestHandler
        status_code, resp_bytes = invoke_handler_in_memory(EcommerceRequestHandler, "POST", webhook_path, raw_bytes, headers)
        try:
            response_body = json.loads(resp_bytes.decode("utf-8"))
        except Exception:
            response_body = {"raw": resp_bytes.decode("utf-8", errors="ignore")}
    else:
        req = urllib.request.Request(url, data=raw_bytes, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                status_code = resp.getcode()
                response_body = json.loads(resp.read().decode("utf-8"))
        except Exception:
            # Fallback to in-memory handler if local port 4000 is not bound in a separate process
            from ecommerce_server import EcommerceRequestHandler
            status_code, resp_bytes = invoke_handler_in_memory(EcommerceRequestHandler, "POST", webhook_path, raw_bytes, headers)
            try:
                response_body = json.loads(resp_bytes.decode("utf-8"))
            except Exception as exc:
                response_body = {"error": str(exc)}

    log_entry = {
        "id": f"WH-{int(time.time() * 1000)}-{random.randint(100,999)}",
        "timestamp": now_iso(),
        "target_url": url,
        "hmac_sha512": signature[:24] + "...",
        "payload": payload,
        "response_status": status_code,
        "response": response_body
    }
    STATE["webhook_outbox"].insert(0, log_entry)
    return log_entry


class MockIntegrationsHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def _send_json(self, data: dict, status: int = 200):
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Egypt-HMAC-SHA512")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_OPTIONS(self):
        self._send_json({"ok": True})

    def do_GET(self):
        path_only = self.path.split("?")[0]
        if path_only in ("/", "/index.html", "/mock-dashboard"):
            self._serve_dashboard()
            return
        if path_only == "/mock/state":
            self._send_json({
                "status": "online",
                "service": "Egypt Fintech & Outsourced Delivery Mockup Server",
                "port": MOCK_PORT,
                "paymob_intentions": list(STATE["paymob_intentions"].values()),
                "fawry_references": list(STATE["fawry_references"].values()),
                "valu_requests": list(STATE["valu_requests"].values()),
                "whatsapp_otps": list(STATE["whatsapp_otps"].values()),
                "bosta_shipments": list(STATE["bosta_shipments"].values()),
                "settlement_payouts": list(STATE["settlement_payouts"].values()),
                "webhook_outbox": STATE["webhook_outbox"][:35]
            })
            return
        self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        body = self._read_json()

        # 1. PAYMOB: Create Payment Intention (Supports Multi-Store Split Metadata)
        if self.path == "/mock/paymob/v1/intention":
            order_id = body.get("order_id")
            amount_egp = float(body.get("amount_egp", 0))
            sub_method = body.get("payment_submethod", "card_meeza")
            store_splits = body.get("store_splits", [])
            intention_id = f"pi_eg_{random.randint(100000, 999999)}"
            record = {
                "intention_id": intention_id,
                "order_id": order_id,
                "amount_cents": int(round(amount_egp * 100)),
                "amount_egp": amount_egp,
                "currency": "EGP",
                "sub_method": sub_method,
                "store_splits": store_splits,
                "status": "PENDING_3DS_OR_WALLET",
                "created_at": now_iso()
            }
            STATE["paymob_intentions"][intention_id] = record
            self._send_json({"success": True, "intention": record}, 201)
            return

        # 1B. PAYMOB: Simulate Customer Completing 3DS / Wallet Payment
        if self.path == "/mock/paymob/simulate-payment":
            intention_id = body.get("intention_id")
            outcome = body.get("outcome", "APPROVED")
            rec = STATE["paymob_intentions"].get(intention_id)
            if not rec:
                self._send_json({"error": "Intention not found"}, 404)
                return
            rec["status"] = outcome
            rec["settled_at"] = now_iso()
            wh = dispatch_webhook("paymob", {
                "event": "TRANSACTION.PROCESSED",
                "intention_id": intention_id,
                "order_id": rec["order_id"],
                "success": outcome == "APPROVED",
                "amount_egp": rec["amount_egp"],
                "currency": "EGP",
                "source_data_type": rec["sub_method"]
            })
            self._send_json({"success": True, "intention": rec, "webhook": wh})
            return

        # 2. FAWRYPAY: Generate 10-Digit OTC Kiosk Reference Number
        if self.path == "/mock/fawry/v2/charge":
            order_id = body.get("order_id")
            amount_egp = float(body.get("amount_egp", 0))
            ref_code = str(random.randint(9100000000, 9999999999))
            expires_at = (datetime.now() + timedelta(hours=48)).strftime("%Y-%m-%d %H:%M:%S")
            record = {
                "fawry_ref": ref_code,
                "order_id": order_id,
                "amount_egp": amount_egp,
                "status": "UNPAID",
                "expires_at": expires_at,
                "created_at": now_iso()
            }
            STATE["fawry_references"][ref_code] = record
            self._send_json({"success": True, "fawry": record}, 201)
            return

        # 2B. FAWRYPAY: Simulate Kiosk Cash Payment or Expiry
        if self.path == "/mock/fawry/simulate-kiosk":
            ref_code = str(body.get("fawry_ref", ""))
            action = body.get("action", "PAID")
            rec = STATE["fawry_references"].get(ref_code)
            if not rec:
                self._send_json({"error": "Fawry Reference not found"}, 404)
                return
            rec["status"] = action
            rec["updated_at"] = now_iso()
            wh = dispatch_webhook("fawry", {
                "event": f"FAWRY.{action}",
                "fawry_ref": ref_code,
                "order_id": rec["order_id"],
                "orderStatus": action,
                "amount_egp": rec["amount_egp"]
            })
            self._send_json({"success": True, "fawry": rec, "webhook": wh})
            return

        # 3. valU BNPL: Create Installment Request
        if self.path == "/mock/valu/v1/plans":
            order_id = body.get("order_id")
            amount_egp = float(body.get("amount_egp", 0))
            months = int(body.get("months", 12))
            customer_phone = body.get("phone", "01000000000")
            monthly_installment = round((amount_egp * (1 + 0.018 * months)) / months, 2)
            valu_id = f"VALU-{random.randint(10000, 99999)}"
            record = {
                "valu_id": valu_id,
                "order_id": order_id,
                "phone": customer_phone,
                "amount_egp": amount_egp,
                "tenure_months": months,
                "monthly_installment_egp": monthly_installment,
                "otp_code": "1234",
                "status": "AWAITING_VALU_OTP",
                "created_at": now_iso()
            }
            STATE["valu_requests"][valu_id] = record
            self._send_json({"success": True, "valu": record}, 201)
            return

        # 3B. valU BNPL: Approve Installment OTP
        if self.path == "/mock/valu/simulate-approval":
            valu_id = body.get("valu_id")
            rec = STATE["valu_requests"].get(valu_id)
            if not rec:
                self._send_json({"error": "valU request not found"}, 404)
                return
            rec["status"] = "APPROVED"
            wh = dispatch_webhook("valu", {
                "event": "VALU.LOAN_APPROVED",
                "valu_id": valu_id,
                "order_id": rec["order_id"],
                "tenure_months": rec["tenure_months"],
                "monthly_installment_egp": rec["monthly_installment_egp"],
                "amount_egp": rec["amount_egp"]
            })
            self._send_json({"success": True, "valu": rec, "webhook": wh})
            return

        # 4. WHATSAPP CLOUD API: Send COD OTP
        if self.path == "/mock/whatsapp/v1/send-otp":
            order_id = str(body.get("order_id"))
            phone = body.get("phone", "01012345678")
            total_egp = body.get("total_egp", 0)
            otp = str(body.get("otp", "4455"))
            record = {
                "order_id": order_id,
                "phone": phone,
                "otp_code": otp,
                "total_egp": total_egp,
                "status": "SENT_AWAITING_REPLY",
                "created_at": now_iso()
            }
            STATE["whatsapp_otps"][order_id] = record
            self._send_json({"success": True, "whatsapp": record}, 201)
            return

        # 4B. WHATSAPP CLOUD API: Verify COD OTP
        if self.path == "/mock/whatsapp/verify-otp":
            order_id = str(body.get("order_id"))
            otp_input = str(body.get("otp", "4455"))
            rec = STATE["whatsapp_otps"].get(order_id)
            if not rec:
                self._send_json({"error": "WhatsApp OTP record not found"}, 404)
                return
            if otp_input != rec["otp_code"] and otp_input != "4455":
                self._send_json({"success": False, "error": "Invalid OTP code"}, 400)
                return
            rec["status"] = "VERIFIED"
            wh = dispatch_webhook("whatsapp-otp", {
                "event": "WHATSAPP.COD_OTP_VERIFIED",
                "order_id": int(order_id) if order_id.isdigit() else order_id,
                "phone": rec["phone"],
                "verified": True
            })
            self._send_json({"success": True, "whatsapp": rec, "webhook": wh})
            return

        # 5. BOSTA OUTSOURCED DELIVERY API: Create Store-to-Client AWB
        if self.path == "/mock/bosta/v2/deliveries":
            order_id = body.get("order_id")
            delivery_id = body.get("delivery_id")
            store_name = body.get("store_name", "Partner Store")
            pickup_gov = body.get("pickup_governorate", "CAIRO")
            pickup_address = body.get("pickup_address", "Store Branch")
            dropoff_gov = body.get("governorate", "CAIRO")
            dropoff_address = body.get("dropoff_address", "Client Address")
            customer_name = body.get("customer_name", "Shopper")
            cod_amount = float(body.get("cod_amount", 0))

            awb = f"BST-{random.randint(8000000, 8999999)}"
            record = {
                "awb": awb,
                "order_id": order_id,
                "delivery_id": delivery_id,
                "store_name": store_name,
                "pickup_governorate": pickup_gov,
                "pickup_address": pickup_address,
                "customer_name": customer_name,
                "governorate": dropoff_gov,
                "dropoff_address": dropoff_address,
                "cod_amount_egp": cod_amount,
                "status": "PICKUP_SCHEDULED",
                "route": f"{pickup_gov} ({store_name}) -> {dropoff_gov} ({customer_name})",
                "history": [{"status": "PICKUP_SCHEDULED", "time": now_iso()}],
                "created_at": now_iso()
            }
            STATE["bosta_shipments"][awb] = record
            self._send_json({"success": True, "shipment": record}, 201)
            return

        # 5B. BOSTA OUTSOURCED DELIVERY API: Advance Store-to-Client Courier Status
        if self.path == "/mock/bosta/simulate-status":
            awb = body.get("awb")
            new_status = body.get("status", "PICKED_UP_FROM_STORE")
            rec = STATE["bosta_shipments"].get(awb)
            if not rec:
                self._send_json({"error": "AWB not found"}, 404)
                return
            rec["status"] = new_status
            rec["history"].append({"status": new_status, "time": now_iso()})
            wh = dispatch_webhook("bosta", {
                "event": "BOSTA.SHIPMENT_STATE_CHANGED",
                "awb": awb,
                "order_id": rec["order_id"],
                "delivery_id": rec.get("delivery_id"),
                "state": new_status,
                "cod_collected_egp": rec["cod_amount_egp"] if new_status == "DELIVERED" else 0,
                "route": rec["route"]
            })
            self._send_json({"success": True, "shipment": rec, "webhook": wh})
            return

        # 6. CASH SETTLEMENT & SPLIT PAYOUT ENGINE: Settle Delivered Order with Partner Store
        if self.path == "/mock/settlement/v1/payout":
            order_id = body.get("order_id")
            delivery_id = body.get("delivery_id")
            order_number = body.get("order_number", f"EG-{order_id}")
            store_id = body.get("store_id")
            store_name = body.get("store_name", "Partner Store")
            payment_method = body.get("payment_method", "paymob_card")
            gross_amount_egp = float(body.get("gross_amount_egp", 0.0))
            platform_commission_egp = float(body.get("platform_commission_egp", 0.0))
            net_store_payout_egp = float(body.get("net_store_payout_egp", 0.0))
            cod_collected_egp = float(body.get("cod_collected_egp", 0.0))
            bosta_awb = body.get("bosta_awb", "")

            settlement_ref = f"STL-{random.randint(700000, 799999)}"
            payout_rail = (
                "Bosta COD Remittance -> InstaPay Corporate Store Payout"
                if payment_method == "cod"
                else "Paymob Split / Escrow Release -> Partner Store Sub-Merchant"
            )
            record = {
                "settlement_ref": settlement_ref,
                "order_id": order_id,
                "order_number": order_number,
                "delivery_id": delivery_id,
                "store_id": store_id,
                "store_name": store_name,
                "payment_method": payment_method,
                "bosta_awb": bosta_awb,
                "gross_amount_egp": gross_amount_egp,
                "platform_commission_egp": platform_commission_egp,
                "net_store_payout_egp": net_store_payout_egp,
                "cod_collected_egp": cod_collected_egp,
                "payout_rail": payout_rail,
                "status": "SETTLED_TO_STORE",
                "settled_at": now_iso()
            }
            STATE["settlement_payouts"][settlement_ref] = record

            wh = dispatch_webhook("settlement", {
                "event": "SETTLEMENT.COMPLETED",
                "settlement_ref": settlement_ref,
                "order_id": order_id,
                "order_number": order_number,
                "delivery_id": delivery_id,
                "store_id": store_id,
                "store_name": store_name,
                "payment_method": payment_method,
                "bosta_awb": bosta_awb,
                "gross_amount_egp": gross_amount_egp,
                "platform_commission_egp": platform_commission_egp,
                "net_store_payout_egp": net_store_payout_egp,
                "cod_collected_egp": cod_collected_egp,
                "payout_rail": payout_rail,
                "status": "SETTLED_TO_STORE",
                "settled_at": record["settled_at"]
            })
            self._send_json({"success": True, "settlement": record, "webhook": wh}, 201)
            return

        self._send_json({"error": "Unknown mock endpoint"}, 404)

    def _serve_dashboard(self):
        html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Egyptian Fintech & Outsourced 3PL Mockup Server (Port 4001)</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f4f7fb; color: #0f172a; }
    .card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 4px 16px rgba(15, 23, 42, 0.05); }
  </style>
</head>
<body class="min-h-screen p-6">
  <div class="max-w-7xl mx-auto space-y-6">
    <div class="card p-6 flex flex-wrap items-center justify-between gap-4 border-l-4 border-l-emerald-600">
      <div>
        <span class="text-xs font-mono font-bold uppercase px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800">Port 4001 • Egyptian Integrations Sandbox</span>
        <h1 class="text-2xl font-extrabold mt-1.5">Egyptian Payment Gateways, Bosta 3PL & Cash Settlement Mock Server</h1>
        <p class="text-sm text-slate-600">Simulates Paymob Split, Fawry 48h Kiosk, valU BNPL, WhatsApp COD OTP, Bosta 3PL & Settlement Webhooks (`HMAC-SHA512`).</p>
      </div>
      <div class="flex gap-2.5">
        <a href="/" onclick="if(window.location.port==='4001'){this.href='http://localhost:4000'}" class="px-4 py-2.5 rounded-xl text-xs font-extrabold bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm">← Back to Main Platform</a>
        <button onclick="loadState()" class="px-4 py-2.5 rounded-xl text-xs font-bold bg-slate-100 hover:bg-slate-200 border border-slate-300 text-slate-800">🔄 Refresh Sandbox</button>
      </div>
    </div>

    <div id="kpi-grid" class="grid grid-cols-2 lg:grid-cols-6 gap-4"></div>

    <div class="grid lg:grid-cols-2 gap-6">
      <div class="card p-5 space-y-3">
        <h2 class="font-extrabold text-base text-slate-800">🚚 Bosta 3PL Store-to-Client Shipments</h2>
        <div id="bosta-list" class="space-y-2.5 max-h-80 overflow-y-auto text-xs"></div>
      </div>
      <div class="card p-5 space-y-3">
        <h2 class="font-extrabold text-base text-slate-800">💸 Completed Cash Settlements (`STL-xxxxxx`)</h2>
        <div id="stl-list" class="space-y-2.5 max-h-80 overflow-y-auto text-xs"></div>
      </div>
    </div>

    <div class="card p-5 space-y-3">
      <h2 class="font-extrabold text-base text-slate-800">🔌 Outbound HMAC-SHA512 Webhooks Dispatched to `:4000`</h2>
      <div id="wh-list" class="space-y-2 max-h-96 overflow-y-auto text-xs font-mono"></div>
    </div>
  </div>
  <script>
    async function loadState() {
      const res = await fetch('/mock/state');
      const d = await res.json();
      document.getElementById('kpi-grid').innerHTML = `
        <div class="card p-4 border-l-4 border-l-emerald-500"><div class="text-xs font-bold text-slate-500">PAYMOB SPLIT</div><div class="text-2xl font-extrabold font-mono mt-1">${d.paymob_intentions.length}</div></div>
        <div class="card p-4 border-l-4 border-l-amber-500"><div class="text-xs font-bold text-slate-500">FAWRY 48H</div><div class="text-2xl font-extrabold font-mono mt-1">${d.fawry_references.length}</div></div>
        <div class="card p-4 border-l-4 border-l-cyan-500"><div class="text-xs font-bold text-slate-500">VALU BNPL</div><div class="text-2xl font-extrabold font-mono mt-1">${d.valu_requests.length}</div></div>
        <div class="card p-4 border-l-4 border-l-teal-500"><div class="text-xs font-bold text-slate-500">WHATSAPP OTP</div><div class="text-2xl font-extrabold font-mono mt-1">${d.whatsapp_otps.length}</div></div>
        <div class="card p-4 border-l-4 border-l-purple-500"><div class="text-xs font-bold text-slate-500">BOSTA AWBs</div><div class="text-2xl font-extrabold font-mono mt-1">${d.bosta_shipments.length}</div></div>
        <div class="card p-4 border-l-4 border-l-indigo-500"><div class="text-xs font-bold text-slate-500">SETTLEMENTS</div><div class="text-2xl font-extrabold font-mono mt-1">${d.settlement_payouts.length}</div></div>
      `;
      document.getElementById('bosta-list').innerHTML = d.bosta_shipments.length === 0 ? '<p class="text-slate-400">No shipments yet.</p>' : d.bosta_shipments.map(b => `
        <div class="p-3 rounded-xl bg-slate-50 border border-slate-200 flex justify-between items-center">
          <div>
            <div class="font-bold font-mono text-purple-700">${b.awb} • Order #${b.order_id}</div>
            <div class="text-slate-600">${b.route}</div>
          </div>
          <span class="px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 font-mono font-bold">${b.status}</span>
        </div>
      `).join('');
      document.getElementById('stl-list').innerHTML = d.settlement_payouts.length === 0 ? '<p class="text-slate-400">No settlements yet.</p>' : d.settlement_payouts.map(s => `
        <div class="p-3 rounded-xl bg-slate-50 border border-slate-200 flex justify-between items-center">
          <div>
            <div class="font-bold font-mono text-emerald-700">${s.settlement_ref} • 🏪 ${s.store_name}</div>
            <div class="text-slate-600">${s.payout_rail}</div>
          </div>
          <div class="text-right font-mono">
            <div class="font-bold text-emerald-700">Store Net: ${s.net_store_payout_egp} EGP</div>
            <div class="text-indigo-700">Fee: +${s.platform_commission_egp} EGP</div>
          </div>
        </div>
      `).join('');
      document.getElementById('wh-list').innerHTML = d.webhook_outbox.map(w => `
        <div class="p-3 rounded-xl bg-slate-50 border border-slate-200">
          <div class="flex justify-between font-bold text-slate-700">
            <span>POST ${w.target_url}</span>
            <span class="text-emerald-700">HTTP ${w.response_status} • ${w.timestamp}</span>
          </div>
          <div class="text-slate-500 mt-1 break-all">${JSON.stringify(w.payload)}</div>
        </div>
      `).join('');
    }
    loadState();
  </script>
</body>
</html>"""
        raw = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


if __name__ == "__main__":
    print(f"Starting Egyptian Integrations Mockup Server (Dual-Stack IPv4/IPv6) on http://localhost:{MOCK_PORT} ...")
    server = DualStackHTTPServer(("::", MOCK_PORT), MockIntegrationsHandler)
    server.serve_forever()
