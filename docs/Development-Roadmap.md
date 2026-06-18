# Development Roadmap

Sequences the actual build against the codebase laid out in Folder-Structure.md and the contracts already fixed in API-Design.md / Database-Design.md. Since every page in `prototype-html/` already exists visually, each milestone below is a *backend build* step or a *wiring* step (swap prototype/placeholder data for a real endpoint) — not a UI design step.

Ordering follows **data dependency, not epic number** — Transactions is the resource everything else reads from, so Epic 3 lands before Epic 2 (Dashboard) even though Dashboard is numbered first.

---

## 1. Milestone Overview

| # | Milestone | Epic(s) | Layer | Depends on |
|---|---|---|---|---|
| M0 | Project scaffolding | — | Backend | Folder-Structure.md, Database-Design.md |
| M1 | Auth & Account | Epic 1 | Backend | M0 |
| M2 | Wire login / register | Epic 1 | Frontend | M1 |
| M3 | Categories + Transactions | Epic 3 (+ Categories) | Backend | M1 |
| M4 | Wire transactions page | Epic 3 | Frontend | M3 |
| M5 | Profile & Settings | Epic 1/9 | Full-stack | M1 |
| M6 | Budgets | Epic 5 | Full-stack | M3 |
| M7 | Goals | Epic 6 | Full-stack | M1 |
| M8 | Dashboard | Epic 2 | Full-stack | M3, M6, M7 |
| M9 | Bank statement import | Epic 4 | Full-stack | M3 |
| M10 | Analytics | Epic 7 | Full-stack | M3 |
| M11 | Reports | Epic 8 | Full-stack | M3 |
| M12 | Cross-cutting hardening | — | Backend | M1–M11 |
| M13 | Full regression pass | — | Full-stack | M12 |

`M5` and `M7` are the only branches that don't depend on Transactions — good candidates to pick up whenever the main path (M3 → M6/M9/M10/M11 → M8) is blocked.

---

## 2. Milestone Details

### M0 — Project Scaffolding
**Scope:** initialize `backend/` per Folder-Structure.md §2 (`config/`, empty `app.ts`/`server.ts` with a `GET /health` route, ESLint/Prettier/TS config, test runner with one smoke test); run the first migration to create the tables in Database-Design.md.
**Depends on:** Folder-Structure.md and Database-Design.md being final.
**Open items:** migration tool not yet pinned (Folder-Structure.md, Open Question #1).
**Definition of done:** `npm run dev` boots, connects to the database, `GET /health` returns `200`.

### M1 — Auth & Account (backend)
**Scope:** `POST /auth/register`, `/login`, `/refresh`, `/logout`; bcrypt hashing (*FR-1.3*); JWT issuance + refresh-token cookie (*FR-1.2, FR-1.4, FR-1.5*); `auth.middleware` attaching `req.userId`; login/register rate limiting (*NFR-2.8*).
**Depends on:** M0.
**Open items:** access/refresh token TTLs not yet specified (API-Design.md, Open Question #2) — needed before `/auth/refresh` expiry logic is final.
**Definition of done:** integration tests cover register → login → refresh → logout, plus 401 on a missing/expired token.

### M2 — Wire Login / Register
**Scope:** `login.html`, `register.html` → real `auth.api.js`; `client.js` stores the access token and retries once via `/auth/refresh` on a 401; prototype's placeholder forms get inline field errors (*NFR-3.3*) instead of an alert popup.
**Depends on:** M1.
**Definition of done:** a real account can register, log in, and land on `dashboard.html` (still showing prototype data at this point — M8 replaces that).

### M3 — Categories + Transactions (backend)
**Scope:** category CRUD, including the delete-reassigns-to-"Uncategorized" rule (*NFR-4.2*) and the `422` guard on deleting the system row itself; transaction CRUD with filtering/pagination (`categoryId`, `dateFrom`, `dateTo`, `search`, `type` — *FR-3.1, FR-3.6, FR-3.7*).
**Depends on:** M1 (every repository call filters by `req.userId` — *NFR-2.3, FR-9.2*).
**Definition of done:** integration tests for the filter/pagination combinations and the categories delete-reassignment edge case.

### M4 — Wire Transactions Page
**Scope:** `transactions.html` → live list, filters, create/edit/delete, category dropdown sourced from `/categories`.
**Depends on:** M3.

### M5 — Profile & Settings
**Scope:** `GET/PUT /profile`, `PUT /profile/password` (verifies current password before storing the new one — *FR-1.8*), `GET/PUT /settings`; wire `profile.html` and `settings.html`.
**Depends on:** M1 only — can run in parallel with M3/M4.

### M6 — Budgets
**Scope:** budget CRUD, `409` on a duplicate category+month (*FR-5.1*), `spent` computed live from Transactions rather than stored (*NFR-4.3*), status thresholds (*FR-5.4, FR-5.5*), history endpoint (*FR-5.6*); wire `budgets.html` — overview ring, category cards, alerts, history.
**Depends on:** M3 (status calc reads Transactions).

### M7 — Goals
**Scope:** goal CRUD, contribution log endpoint with the achievement-flip + `justAchieved` flag (*FR-6.3, FR-6.5*), archive endpoint (*FR-6.7*); wire `goals.html` — progress rings, gold-ribbon achieved state, contribution log.
**Depends on:** M1 only — `currentAmount` sums from `GoalContributions`, not from Transactions, so this doesn't wait on M3.

### M8 — Dashboard
**Scope:** the single composite `GET /dashboard`, reusing the exact computed fields from the budgets and goals endpoints so the two pages never disagree on a number (*FR-2.1–FR-2.8*); wire `dashboard.html` to the real payload, replacing the placeholder numbers left over from M2.
**Depends on:** M3, M6, M7 — this is the milestone that forces those three to be functioning first.

### M9 — Bank Statement Import
**Scope:** `POST /imports/preview` (multipart upload, file validation — *NFR-2.4* — parsing, auto-categorization, duplicate flagging — *FR-4.1–FR-4.3, FR-4.6*), `POST /imports/confirm` (single DB transaction, all-or-nothing — *NFR-4.1*), `GET /imports` history (*FR-4.8*); wire `import-bank-statement.html` — upload, editable preview table, confirm.
**Depends on:** M3 (writes Transactions, suggests against Categories).
**Open items:** the stateless preview/confirm design (API-Design.md, Open Question #1) and the assumed fixed CSV column layout (Open Question #3) should be confirmed before this milestone starts — both shape the preview table's columns and the confirm payload.

### M10 — Analytics
**Scope:** category-breakdown, trends, top-merchants endpoints (*FR-7.1, FR-7.2, FR-7.4*); wire `analytics.html` charts.
**Depends on:** M3.

### M11 — Reports
**Scope:** `POST /reports/generate` (on-screen preview), `GET /reports/export/pdf`, `GET /reports/export/csv` (*FR-8.1–FR-8.4*); wire `reports.html` preview + export buttons.
**Depends on:** M3.
**Open items:** confirm both PDF and CSV are actually required for v1 (API-Design.md, Open Question #4) before building both exporters.

### M12 — Cross-Cutting Hardening
**Scope:** centralized error-handling middleware on every route (*FR-9.3*), validation schemas on every write endpoint (*FR-9.4*), HTTPS/HSTS in production config (*NFR-2.6*), an indexing/pagination pass to confirm list endpoints hold under 500ms (*NFR-1.3*).
**Depends on:** M1–M11, since it touches every route already built.

### M13 — Full Regression Pass
**Scope:** walk every flow documented in User-Flow.md end-to-end against the now-wired frontend; once a `prototype-html/*.html` page has a working `frontend/public/` counterpart, retire the prototype copy.
**Depends on:** M12.

---

## 3. Critical Path

`M1 (Auth)` blocks every other milestone. `M3 (Categories + Transactions)` is the next bottleneck — it gates Budgets, Import, Analytics, Reports, and indirectly Dashboard. `M5 (Profile/Settings)` and `M7 (Goals)` are the only branches independent of M3, making them the best use of time if M3 or an open question is blocking progress.

---

## Open Questions / Needs Confirmation

1. **No calendar estimates:** milestones above are ordered by dependency only, not by days/weeks — solo development pace varies enough that a fixed schedule would likely be wrong. Add time estimates once a target ship date exists.
2. **Single-developer assumption:** the ordering assumes one person working roughly top-to-bottom through section 1. If a second contributor joins, M5 and M7 are the first candidates to split off since they don't block or get blocked by the main path.
3. **Carried-forward blockers:** several milestones above can't fully start until an earlier doc's open question is resolved — token TTLs (M1), migration tooling (M0), import statelessness + CSV column mapping (M9), and the PDF/CSV export requirement (M11). They're called out inline above so they're visible without re-opening API-Design.md or Folder-Structure.md.