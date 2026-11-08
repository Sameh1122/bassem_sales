import os
import sys

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
    pass
