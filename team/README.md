# Project Team & Delivery Governance — Bassem Sales Platform

Welcome to the **Bassem Sales Platform** team workspace. This folder is managed by the **Project Manager** to coordinate all roles, handoffs, and deliverables across the project.

---

## 1. Team Roster & Responsibilities

| Role | Primary Responsibility | Key Artifacts |
| :--- | :--- | :--- |
| **Project Manager (PM)** | Sprint planning, dependency & blocker tracking, release coordination, maintaining `team/BOARD.md`. | [BOARD.md](BOARD.md) |
| **1. Product Owner (PO)** | Product vision, business priorities, feature enhancements, backlog ordering. | [01-product-owner/VISION_AND_ROADMAP.md](01-product-owner/VISION_AND_ROADMAP.md) |
| **2. Business Analyst (BA)** | Translates PO vision into user stories & acceptance criteria alongside UI/UX; aligns with `docs/BRD.md`. | [02-ba/USER_STORIES.md](02-ba/USER_STORIES.md) |
| **3. UI/UX Designer** | Enhances user flows, wireframes, visual polish, and turns PO vision into visible design specs. | [03-ui-ux/DESIGN_NOTES.md](03-ui-ux/DESIGN_NOTES.md) |
| **4. Tech Lead / Architect** | System architecture, API/DB contracts, technical feasibility, code standards, security review; aligns with `docs/SAD.md`. | [04-tech-lead/ARCHITECTURE_DECISIONS.md](04-tech-lead/ARCHITECTURE_DECISIONS.md) |
| **5. Developers** | Executes stories (Node.js/Express API in `api/` & Flutter Web in `frontend/`), writes unit/integration tests. | [05-developers/DEV_LOG.md](05-developers/DEV_LOG.md) |
| **6. QA Tester** | Tests platform against PO, BA, and UI/UX requirements; maintains regression & security reports. | [06-qa/TEST_PLAN.md](06-qa/TEST_PLAN.md), [../QA_REPORT.md](../QA_REPORT.md) |
| **7. DevOps / Release** | CI/CD, environments (`localhost`, Vercel), secrets/env hygiene, build & release verification. | [07-devops/RELEASE_CHECKLIST.md](07-devops/RELEASE_CHECKLIST.md) |

---

## 2. Delivery Workflow & Cross-Chat Task Dispatch (`team/TASKS/`)

Each role has a task dispatch file in `team/TASKS/`:
- `team/TASKS/product-owner.md`
- `team/TASKS/ba.md`
- `team/TASKS/ui-ux.md`
- `team/TASKS/developers.md`
- `team/TASKS/qa-tester.md`

**How it works:**
1. The **PM** writes the assignment into `team/TASKS/<role>.md` (`Status: PENDING`) and updates [BOARD.md](BOARD.md).
2. The role chat reads `team/TASKS/<role>.md`, executes the work, writes its output to its `team/0x-*/` folder, and sets `Status: DONE`.
3. The **PM** reviews the output, updates [BOARD.md](BOARD.md), and dispatches the next role.

```text
PO (Vision / Enhancement)
  └──▶ BA + UI/UX (User Stories + Acceptance Criteria + Design Spec)
         └──▶ Tech Lead (Feasibility & API/Architecture Check)
                └──▶ Developers (Implementation + Build)
                       └──▶ QA Tester (Verification vs PO/BA/UI-UX + Regression)
                              └──▶ DevOps + PM (Release & Sign-off)
```

---

## 3. Definition of Ready (DoR) — Before Dev Starts
- [ ] Story has a clear business goal from the **PO**.
- [ ] **BA** has written acceptance criteria (happy path + edge cases).
- [ ] **UI/UX** has provided layout/interaction specs (if user-facing).
- [ ] **Tech Lead** has confirmed API/schema impact and no architectural blockers.

## 4. Definition of Done (DoD) — Before Release
- [ ] Code implemented in `api/` and/or `frontend/` (and `public/` rebuilt if Flutter changed).
- [ ] Automated tests / verification scripts pass (`npm start` & relevant test scripts).
- [ ] **QA** has verified against PO, BA, and UI/UX requirements with no open High/Critical bugs.
- [ ] **Docs** (`docs/BRD.md`, `docs/SAD.md`, `team/BOARD.md`) updated if scope or architecture changed.
