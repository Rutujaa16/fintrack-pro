# Folder Structure

Concrete, on-disk layout for both halves of the project — the Node.js + Express + TypeScript backend and the frontend currently prototyped as static pages in `prototype-html/` — so that the layered architecture (`routes → controllers → services → repositories`, *NFR-5.1*) and every endpoint in API-Design.md has an unambiguous home before coding starts.

Repository: single Git repo (monorepo), with `backend/`, `frontend/`, and `docs/` as top-level siblings.

---

## 1. Top-Level Layout

```
finance-tracker/
├── docs/                     # this folder — Project-Overview.md, API-Design.md, etc.
├── prototype-html/           # existing static prototypes — frozen reference until frontend/ replaces it
├── backend/                  # Express + TypeScript API (section 2)
├── frontend/                 # production pages + client JS, wired to the API (section 3)
├── .env.example
├── .gitignore
└── README.md                 # local setup for both halves
```

| Folder | Purpose |
|---|---|
| `docs/` | Planning artifacts only — never imported by code. |
| `prototype-html/` | Visual reference for `frontend/`. Not deployed; superseded page-by-page as each one is wired to a live endpoint (see Open Questions). |
| `backend/` | Everything in section 2. |
| `frontend/` | Everything in section 3. |

---

## 2. Backend — `backend/`

One file per resource at each layer, mirroring the eleven sections of API-Design.md so a route's controller, service, and repository can be found by name alone.

```
backend/
├── src/
│   ├── config/
│   │   ├── env.ts                  # loads & validates env vars (PORT, JWT secrets, DB URL)
│   │   ├── db.ts                   # database connection/pool
│   │   └── constants.ts            # e.g. budget status thresholds — FR-5.4, FR-5.5
│   ├── routes/
│   │   ├── index.ts                # mounts every router under /api/v1
│   │   ├── auth.routes.ts
│   │   ├── profile.routes.ts
│   │   ├── settings.routes.ts
│   │   ├── dashboard.routes.ts
│   │   ├── categories.routes.ts
│   │   ├── transactions.routes.ts
│   │   ├── imports.routes.ts
│   │   ├── budgets.routes.ts
│   │   ├── goals.routes.ts
│   │   ├── analytics.routes.ts
│   │   └── reports.routes.ts
│   ├── controllers/                # one *.controller.ts per file above — parses req, builds the response envelope, no business logic
│   ├── services/
│   │   ├── auth.service.ts         # hashing, token issuance — FR-1.2–FR-1.6
│   │   ├── budget.service.ts       # live spent/limit recalculation, status derivation — FR-5.3–FR-5.5, NFR-4.3
│   │   ├── goal.service.ts         # currentAmount recompute + achievement flip — FR-6.3, FR-6.5
│   │   ├── import.service.ts       # parsing, auto-categorization, duplicate flagging — FR-4.1–FR-4.3, FR-4.6
│   │   ├── dashboard.service.ts    # aggregates the other services into one payload — FR-2.1–FR-2.8
│   │   ├── report.service.ts       # summary + breakdown for PDF/CSV export — FR-8.1–FR-8.4
│   │   └── …                       # one per remaining resource
│   ├── repositories/
│   │   ├── user.repository.ts
│   │   ├── refreshToken.repository.ts
│   │   ├── category.repository.ts
│   │   ├── transaction.repository.ts
│   │   ├── import.repository.ts
│   │   ├── budget.repository.ts
│   │   ├── goal.repository.ts
│   │   ├── goalContribution.repository.ts
│   │   ├── setting.repository.ts
│   │   └── analytics.repository.ts # the only place raw aggregate SQL (breakdowns, top merchants) lives — FR-7.1, FR-7.4
│   ├── middleware/
│   │   ├── auth.middleware.ts      # decodes JWT, sets req.userId — NFR-2.2, NFR-2.3
│   │   ├── rateLimit.middleware.ts # login/register limiter — NFR-2.8
│   │   ├── validate.middleware.ts  # wraps the zod/joi schemas below — FR-9.4
│   │   ├── upload.middleware.ts    # multer config, file type/size checks — NFR-2.4
│   │   └── errorHandler.middleware.ts # logs stack traces server-side, returns { code, message } only — FR-9.3
│   ├── validators/                 # one zod/joi schema per write endpoint
│   ├── types/
│   │   └── dto/                    # request/response shapes, copied from the JSON examples in API-Design.md
│   ├── utils/
│   │   ├── jwt.ts
│   │   ├── password.ts             # bcrypt helpers — FR-1.3
│   │   ├── csvParser.ts            # bank-statement row parsing — FR-4.1
│   │   └── pdfGenerator.ts         # FR-8.2
│   ├── app.ts                      # express() instance, middleware + route mounting
│   └── server.ts                   # http.listen(), reads PORT from config
├── migrations/                     # mirrors the tables in Database-Design.md — exact tool TBD, see Open Questions
├── tests/
│   ├── unit/                       # services/ + utils/, one test file per source file
│   ├── integration/                # supertest against routes/, one suite per resource
│   └── fixtures/
├── package.json
├── tsconfig.json
└── .eslintrc.json
```

### Layer responsibilities

| Layer | Responsibility | Talks to |
|---|---|---|
| `routes/` | Declares the path + HTTP method, attaches `auth.middleware` and `validate.middleware`, hands off to a controller. | `controllers/` only |
| `controllers/` | Reads `req`, builds the success/error envelope, contains no business logic. | `services/` only |
| `services/` | Business rules — budget recalculation, duplicate detection, goal-achievement checks (*NFR-5.1*). | `repositories/` only |
| `repositories/` | The only layer that runs queries; every method filters by the `userId` passed in, never a client-supplied one — *NFR-2.3, FR-9.2*. | Database only |

---

## 3. Frontend — `frontend/`

The existing pages in `prototype-html/` (`dashboard.html`, `login.html`, `register.html`, `transactions.html`, `import-bank-statement.html`, `reports.html`, `profile.html`, `settings.html`, `budgets.html`, `goals.html`, `analytics.html`) move here one at a time as each gets a page-controller script that calls the real API instead of placeholder data.

```
frontend/
├── public/
│   ├── login.html
│   ├── register.html
│   ├── dashboard.html
│   ├── transactions.html
│   ├── import-bank-statement.html
│   ├── budgets.html
│   ├── goals.html
│   ├── analytics.html
│   ├── reports.html
│   ├── profile.html
│   ├── settings.html
│   ├── css/
│   │   ├── base.css                # variables, resets, typography
│   │   └── components/             # cards.css, modals.css, rings.css (budget/goal progress rings), ribbon.css
│   ├── js/
│   │   ├── api/
│   │   │   ├── client.js           # base fetch wrapper — attaches Bearer token, retries once via /auth/refresh on 401
│   │   │   ├── auth.api.js
│   │   │   ├── transactions.api.js
│   │   │   ├── imports.api.js
│   │   │   ├── budgets.api.js
│   │   │   ├── goals.api.js
│   │   │   └── …                   # one per resource, mirrors API-Design.md sections 2–11
│   │   ├── pages/                  # one controller script per .html file above
│   │   │   ├── dashboard.page.js
│   │   │   ├── import-bank-statement.page.js  # holds previewed rows in memory between preview/confirm — FR-4.4, FR-4.5
│   │   │   ├── goals.page.js       # triggers the gold-ribbon state on justAchieved — FR-6.5
│   │   │   └── …
│   │   ├── components/             # shared nav, inline field-error renderer — NFR-3.3, toast, modal
│   │   └── utils/
│   └── assets/                     # icons, illustrations
└── README.md                       # how to point this at a local backend/ instance
```

---

## 4. Naming & File Conventions

| Artifact | Convention | Example |
|---|---|---|
| Backend layer files | `<resource>.<layer>.ts` | `budgets.controller.ts`, `budget.service.ts`, `budget.repository.ts` |
| Frontend API wrappers | `<resource>.api.js` | `transactions.api.js` |
| Frontend page controllers | `<page>.page.js`, one per `prototype-html/*.html` file | `goals.page.js` |
| Validation schemas | `<resource>.schema.ts` | `transaction.schema.ts` |
| Test files | mirror the source path under `tests/unit` or `tests/integration` | `src/services/budget.service.ts` → `tests/unit/budget.service.test.ts` |
| Types | singular, PascalCase | `Transaction`, `BudgetCard`, `GoalContribution` |

---

## 5. Cross-Cutting

| Concern | Where it lives |
|---|---|
| Environment variables | `.env.example` at repo root documents every key; `backend/src/config/env.ts` validates them at boot. |
| DB schema source of truth | Database-Design.md; `backend/migrations/` should never drift from it. |
| Shared response/error shapes | Defined once in `backend/src/types/dto/`, matching the examples in API-Design.md — not redefined by hand on the frontend. |
| Local dev instructions | Root `README.md` — how to run `backend/` and `frontend/` together. |

---

## Open Questions / Needs Confirmation

1. **Migration tooling:** `backend/migrations/` is shown as a generic folder. The actual tool (Prisma, Knex, raw `.sql` files) depends on the DB engine chosen in Database-Design.md — confirm before scaffolding `backend/`.
2. **Frontend build pipeline:** this layout assumes `frontend/` stays plain HTML/CSS/JS with no bundler, matching how `prototype-html/` is already organized. If a bundler or framework is introduced later, `public/` and the `js/` module structure would need revisiting.
3. **`prototype-html/` cut-over:** assumed here is a page-by-page replace (rebuild each page inside `frontend/public/`, then retire its `prototype-html/` counterpart) rather than a single big-bang switch. Confirm this matches how Development-Roadmap.md should sequence the work.
4. **Repo split:** single monorepo assumed above for solo development. If `backend/` and `frontend/` ever need independent deploy pipelines, splitting into two repos would change section 1's tree.