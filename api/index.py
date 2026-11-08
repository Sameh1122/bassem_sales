import os
import sys
import urllib.parse

# Ensure project root is on sys.path for Vercel Python serverless runtime
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

os.environ.setdefault("VERCEL", "1")

from ecommerce_server import EcommerceRequestHandler, init_db

# Initialize SQLite HPOS schema and seed data in /tmp on cold start
init_db()


class handler(EcommerceRequestHandler):
    """
    Unified Vercel Serverless Entry Point preserving the exact local architecture:
      - / and /wp-json/wc/v3/* -> Core Marketplace Facilitator Engine (ecommerce_server.py)
      - /mock-dashboard and /mock/* -> Egyptian Integrations & Bosta 3PL Sandbox (mock_integrations_server.py)
      - /study -> Egypt E-Commerce Platform Study & 1st-Year Liability Calculator (study.html)
    """

    def _restore_original_path(self):
        parsed = urllib.parse.urlsplit(self.path)
        qs = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        if "__path" in qs and qs["__path"]:
            orig_path = qs.pop("__path")[0]
            if not orig_path.startswith("/"):
                orig_path = "/" + orig_path
            remaining_query = urllib.parse.urlencode(qs, doseq=True)
            self.path = f"{orig_path}?{remaining_query}" if remaining_query else orig_path

    def do_GET(self):
        self._restore_original_path()
        return super().do_GET()

    def do_POST(self):
        self._restore_original_path()
        return super().do_POST()

    def do_OPTIONS(self):
        self._restore_original_path()
        return super().do_OPTIONS()
