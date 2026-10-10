# Bassem Sales Platform 🚀
## FMCG Commercial Refrigeration Asset Intelligence & Field Operations

[![Documentation Status](https://img.shields.io/badge/Docs-Living%20BRD%20%26%20SAD-blue)](docs/BRD.md)
[![Security Hardened](https://img.shields.io/badge/Security-OWASP%20Hardened-emerald)](docs/SAD.md#4-security-architecture--threat-model-stride)
[![Runtime](https://img.shields.io/badge/Runtime-Node.js%20%7C%20Flutter%20Web-purple)](docs/SAD.md#2-technology-stack--component-specifications)

The **Bassem Sales Platform** is an enterprise-grade field operations and asset intelligence platform for Fast-Moving Consumer Goods (FMCG) distribution networks. It provides real-time geospatial tracking of refrigeration equipment (chillers/coolers), point-in-time spreadsheet batch auditing, full 36+ attribute searching, and field sales territory management.

---

## 📚 Living Documentation

This repository maintains live, synchronized architectural and business documents that auto-update on every GitHub push:

| Document | File Link | Description |
| :--- | :--- | :--- |
| **Business Requirements Document (BRD)** | [📄 docs/BRD.md](docs/BRD.md) | Business problem, personas, goals, functional requirements (FR-01 to FR-12), and acceptance criteria. |
| **Solution Architecture Document (SAD)** | [🏗️ docs/SAD.md](docs/SAD.md) | C4 architecture diagrams, technology stack, security model (STRIDE), API catalog, and deployment topologies. |

---

## 🌟 Key Platform Capabilities

1. **Multi-Batch Spreadsheet Ingestion**: Ingests master `.xlsx`, `.xls`, and `.csv` files with dynamic 36+ column recognition and formula injection (DDE) neutralization.
2. **Historical Batch Delta Auditing**: Compares any two historical uploads to identify added, eliminated, or modified chiller locations and customer accounts.
3. **Interactive Geospatial Intelligence**: OpenStreetMap / Leaflet map with condition pin coloring, live GPS "My Location" tracking, and collapsible/maximizable map drawer.
4. **Universal 36+ Column Search & Filter**: Instant omni-search and header filters with distinct value-frequency chips.
5. **Strict Role-Based Territory Segregation**: Field sales representatives (e.g., Omnia) only see their assigned chillers, eliminating cross-territory data leakage.
6. **Enterprise Security Hardening**: PBKDF2 with 100,000 iterations of SHA-512, timing-safe crypto comparisons, dual rate-limiting brute-force defense, and HTTP header hardening.

---

## 🛠️ Quick Start

### Prerequisites
- Node.js `v18+` or `v20+`
- Optional: Flutter SDK (for rebuilding the web frontend)

### Installation & Run
```bash
# 1. Clone repository
git clone https://github.com/Sameh1122/bassem_sales.git
cd bassem_sales

# 2. Install dependencies
npm install

# 3. Start local platform daemon
npm start
```
The application will be running at **http://localhost:5000**.

### Documentation Management Commands
```bash
# Manually synchronize live documentation metadata
npm run docs:update

# Install automated pre-push git hook
npm run docs:setup-hook
```

---

## 📂 Project Structure

```text
bassem_sales/
├── .github/
│   └── workflows/
│       └── update-docs.yml       # GitHub Actions live doc synchronizer
├── api/
│   ├── index.js                  # Express API router & security middleware
│   ├── seedData.json             # Initial database seed store
│   └── sample_chillers.xlsx      # Sample FMCG spreadsheet
├── docs/
│   ├── BRD.md                    # Business Requirements Document (Live)
│   └── SAD.md                    # Solution Architecture Document (Live)
├── frontend/                     # Flutter Web Application (Dart)
│   └── lib/                      # Views, models, and API services
├── public/                       # Compiled Flutter Web production build
├── scripts/
│   ├── build.js                  # Build runner
│   ├── update-docs.js            # Living doc metadata updater
│   └── setup-git-hooks.js        # Git pre-push hook installer
├── server.js                     # Local Express server host
└── package.json                  # Dependencies & scripts
```
