# DevOps & Release Checklist

**Owner:** DevOps / Release Engineer  
**Config:** [../../package.json](../../package.json), [../../vercel.json](../../vercel.json), [../../.github/workflows/flutter-build.yml](../../.github/workflows/flutter-build.yml), [../../.github/workflows/update-docs.yml](../../.github/workflows/update-docs.yml)

---

## CI/CD Pipelines (GitHub Actions)
- **Flutter Web Build & Sync** ([`flutter-build.yml`](../../.github/workflows/flutter-build.yml)):
  - Triggers on `push` / `pull_request` to `main` touching `frontend/**`, `scripts/build.js`, or the workflow file itself, plus manual `workflow_dispatch`.
  - Runs `flutter pub get`, `flutter test`, `flutter build web --release`, and `node scripts/build.js` to sync build output into `public/`.
  - On `main` pushes and manual runs, commits and pushes updated `public/` artifacts automatically; PRs validate the build without committing.
- **Living Documentation Sync** ([`update-docs.yml`](../../.github/workflows/update-docs.yml)):
  - Triggers on `push` to `main`/`master` (ignoring `docs/**`) and `workflow_dispatch`, running `node scripts/update-docs.js`.

---

## Pre-Release Checklist
- [ ] Environment variables verified (`.env.local` / Vercel env — never commit secrets).
- [ ] `frontend/` built to `public/` via CI (`flutter-build.yml`) or locally (`flutter build web --release` + `npm run build` / `scripts/build.js`) if Flutter UI changed.
- [ ] `npm start` starts cleanly on `http://localhost:5000`.
- [ ] QA regression suite passes (`scripts/test_qa_remediation.js`).
- [ ] Living docs synchronized (`npm run docs:update` / GitHub Actions).

---

## Sprint 1 Release Steps (ADR-006)
1. **Verify CI Workflows:**
   - [ ] Confirm `Flutter Web Build & Sync` (`flutter-build.yml`) passes on PR and `main` without breaking `Living Documentation Sync` (`update-docs.yml`).
   - [ ] If releasing UI changes without a local Flutter SDK, trigger `flutter-build.yml` via `workflow_dispatch` (or merge PR to `main`) and pull the CI-committed `public/` artifacts.
2. **Verify Vercel Edge Caching & Routing (`vercel.json`):**
   - [ ] `/assets/*` and `/canvaskit/*` serve `Cache-Control: public, max-age=31536000, immutable`.
   - [ ] `/icons/*` serves `Cache-Control: public, max-age=86400, stale-while-revalidate=604800`.
   - [ ] `/index.html`, `/flutter_service_worker.js`, `/flutter_bootstrap.js`, `/main.dart.js`, and `/api/*` retain `Cache-Control: public, max-age=0, must-revalidate`.
   - [ ] `/api/*` rewrites to `/api/index.js` and SPA routes rewrite to `/index.html`.
3. **Post-Deploy Smoke Test:**
   - [ ] Hard-reload production URL and confirm Flutter Web loads without stale service-worker/asset errors.
   - [ ] Verify `/api/health` (or primary API endpoint) returns `200 OK` and `must-revalidate` headers.
