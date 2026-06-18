# API Design

REST API for the Node.js + Express + TypeScript backend, following the layered architecture decided in Path A: **routes → controllers → services → repositories** (*NFR-5.1*). Every endpoint below maps to a route, which delegates to a controller, which calls a service (business rules — budget recalculation, duplicate detection, goal-achievement checks), which calls a repository (the only layer that talks to the tables in Database-Design.md).

Base URL: `/api/v1`

---

## 1. Conventions

### Authentication
- All endpoints except `POST /auth/register`, `POST /auth/login`, and `POST /auth/refresh` require a valid JWT access token in the `Authorization: Bearer <token>` header — *NFR-2.2*.
- Auth middleware decodes the token and attaches `req.userId`; every repository call downstream filters by this value, never by a client-supplied `userId` in the body/query — *NFR-2.3, FR-9.2*.
- The refresh token is never sent in a JSON body; it lives in an `httpOnly`, `Secure` cookie set by `/auth/login` and `/auth/refresh` — *NFR-2.7*.
- `POST /auth/login` and `POST /auth/register` are rate-limited (e.g. 10 requests / 15 min / IP) — *NFR-2.8*.

### Response Envelope
Successful responses:
```json
{ "data": { /* resource or array */ } }
```
List endpoints add a `pagination` block:
```json
{
  "data": [ /* items */ ],
  "pagination": { "page": 1, "limit": 25, "total": 132, "totalPages": 6 }
}
```

### Error Envelope
*(supports inline, field-level form errors per NFR-3.3 — the frontend never shows a generic alert popup)*
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "One or more fields are invalid.",
    "fields": { "amount": "Amount must be greater than 0" }
  }
}
```
Internal failures return a generic message; the real error is logged server-side only — *FR-9.3*.

### Standard Status Codes

| Code | Meaning |
|---|---|
| 200 | Success |
| 201 | Resource created |
| 400 | Validation error (see `fields` in error body) |
| 401 | Missing/expired/invalid access token |
| 403 | Authenticated but not permitted (e.g. editing another user's data — should be unreachable given *NFR-2.3*, but returned defensively) |
| 404 | Resource not found, or not owned by the requesting user (404, not 403, to avoid confirming existence of other users' resource IDs) |
| 409 | Conflict (e.g. duplicate email on register, duplicate budget for the same category/month) |
| 422 | Semantically invalid but well-formed (e.g. deleting the system "Uncategorized" category) |
| 429 | Rate limited |
| 500 | Unhandled server error |

### Pagination & Filtering Query Params
Used by any list endpoint (`Transactions` is the main consumer per *NFR-6.1*): `page`, `limit` (default 25, max 100), plus endpoint-specific filters documented per-resource below.

---

## 2. Auth & Account — Epic 1
*(FR-1.1 – FR-1.6)*

| Method & Path | Auth | Description |
|---|---|---|
| `POST /auth/register` | No | Create account. Body: `{ name, email, password }`. Hashes password (bcrypt) before storing — *FR-1.3*. Returns `201` + the same payload shape as login. |
| `POST /auth/login` | No | Body: `{ email, password }`. On success, sets refresh-token cookie and returns `{ accessToken, user: { id, name, email } }` — *FR-1.2, FR-1.4*. |
| `POST /auth/refresh` | Cookie only | Reads the refresh-token cookie, validates against `RefreshTokens`, issues a new access token. No request body — *FR-1.5*. |
| `POST /auth/logout` | Yes | Revokes the current refresh token (`RevokedAt`) and clears the cookie — *FR-1.6*. |

**Example — `POST /auth/login` response:**
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJI...",
    "user": { "id": 14, "name": "Asha Verma", "email": "asha@example.com" }
  }
}
```

---

## 3. Profile & Settings — Epic 1 / Epic 9
*(FR-1.7, FR-1.8, FR-1.9)*

| Method & Path | Description |
|---|---|
| `GET /profile` | Returns `{ id, name, email, createdAt }`. |
| `PUT /profile` | Body: `{ name, email }` — *FR-1.7*. |
| `PUT /profile/password` | Body: `{ currentPassword, newPassword }`. Verifies current password before hashing and storing the new one — *FR-1.8*. |
| `GET /settings` | Returns `{ currency, emailNotificationsEnabled, budgetAlertNotificationsEnabled }`. |
| `PUT /settings` | Partial update of the same fields — *FR-1.9*. |

---

## 4. Dashboard — Epic 2
*(FR-2.1 – FR-2.8)*

Implemented as a **single composite endpoint** rather than one call per widget — the dashboard's 2-second load target (*NFR-1.1*) is much easier to hit with one round trip than six.

| Method & Path | Description |
|---|---|
| `GET /dashboard` | Returns everything `dashboard.html` needs in one payload. |

**Example response:**
```json
{
  "data": {
    "totalBalance": 184250.50,
    "currentMonth": {
      "income": 92000, "incomeChangePct": 4.2,
      "expense": 61320, "expenseChangePct": -8.1,
      "savingsRate": 33.3
    },
    "cashFlow": [
      { "month": "2026-01", "income": 88000, "expense": 65000 },
      { "month": "2026-02", "income": 90500, "expense": 59800 }
    ],
    "recentTransactions": [
      { "id": 4821, "merchant": "Swiggy", "category": "Food & Dining", "date": "2026-06-17", "amount": 480, "type": "expense" }
    ],
    "budgetsSummary": [
      { "categoryId": 3, "category": "Food & Dining", "limit": 8000, "spent": 6420, "status": "warning" }
    ],
    "goalsSummary": [
      { "id": 7, "name": "Japan Trip", "targetAmount": 250000, "currentAmount": 142000, "status": "active" }
    ]
  }
}
```
`cashFlow` covers the trailing 6 months (*FR-2.5*); `recentTransactions` is capped at 5, newest first (*FR-2.6*); `budgetsSummary`/`goalsSummary` reuse the same computed fields as their full-page endpoints (sections 7 and 8) so the dashboard and `budgets.html`/`goals.html` never disagree on a number.

---

## 5. Categories
*(supports FR-3.8, NFR-4.2 — not a standalone epic, but needed by Transactions/Budgets)*

| Method & Path | Description |
|---|---|
| `GET /categories` | Returns system categories + this user's custom ones. |
| `POST /categories` | Body: `{ name, kind, colorHex? }`. |
| `PUT /categories/:id` | Renames/recolors a user-owned category. `403`/`404` if attempting to edit a system category or another user's category. |
| `DELETE /categories/:id` | Reassigns this user's transactions in that category to "Uncategorized," then deletes the category — *NFR-4.2*. Returns `422` if `id` refers to the system "Uncategorized" row itself. |

---

## 6. Transactions — Epic 3
*(FR-3.1 – FR-3.9)*

| Method & Path | Description |
|---|---|
| `GET /transactions` | Query params: `page`, `limit`, `categoryId`, `dateFrom`, `dateTo`, `search` (merchant), `type` (income/expense) — *FR-3.1, FR-3.6, FR-3.7*. Sorted by `transactionDate DESC` by default. |
| `POST /transactions` | Body: `{ date, amount, type, categoryId, merchant, accountSource?, notes? }` — *FR-3.3*. |
| `PUT /transactions/:id` | Same body shape, partial update allowed — covers both general edits (*FR-3.4*) and re-categorization (*FR-3.7*). |
| `DELETE /transactions/:id` | *FR-3.5*. |

**List item shape** (used here and reused inside `/dashboard` and `/reports`):
```json
{ "id": 4821, "date": "2026-06-17", "amount": 480, "type": "expense",
  "category": { "id": 3, "name": "Food & Dining" }, "merchant": "Swiggy",
  "accountSource": "**** 4821", "notes": null, "source": "import" }
```

---

## 7. Bank Statement Import — Epic 4
*(FR-4.1 – FR-4.6, FR-4.8, NFR-4.1, NFR-2.4)*

Modeled as a **two-step preview/confirm flow**, matching UF-7 exactly — nothing is written to `Transactions` until the user explicitly confirms.

| Method & Path | Description |
|---|---|
| `POST /imports/preview` | `multipart/form-data` file upload. Validates file type/size before parsing (*NFR-2.4*). Parses rows, runs rule-based auto-categorization, flags likely duplicates against existing transactions, and returns the full row set **without writing anything to the database** — *FR-4.1 – FR-4.3, FR-4.6*. |
| `POST /imports/confirm` | Body: `{ fileName, rows: [...] }` — the same rows returned by `preview`, with any user edits to `category`/`merchant` and any duplicate rows the user chose to exclude (*FR-4.4, FR-4.5*) already applied client-side. The server re-validates and writes the `Imports` row plus all `Transactions` rows inside one database transaction — succeeds completely or not at all (*NFR-4.1*). |
| `GET /imports` | Import history: `{ id, fileName, rowCount, status, importedAt }[]` — *FR-4.8*. |

**`POST /imports/preview` response row shape:**
```json
{
  "rowNumber": 1,
  "date": "2026-06-10",
  "merchant": "SWIGGY BANGALORE",
  "amount": 480,
  "type": "expense",
  "suggestedCategory": "Food & Dining",
  "isDuplicate": false
}
```

---

## 8. Budgets — Epic 5
*(FR-5.1 – FR-5.8)*

| Method & Path | Description |
|---|---|
| `GET /budgets?month=YYYY-MM` | Returns the overview ring total plus per-category cards, with `spent` always computed live from `Transactions` (never read from a stored column, per *NFR-4.3*) — *FR-5.2, FR-5.3*. Defaults to the current month if `month` is omitted. |
| `POST /budgets` | Body: `{ categoryId, month, limitAmount }` — *FR-5.1*. `409` if a budget already exists for that category + month. |
| `PUT /budgets/:id` | Update `limitAmount` — *FR-5.7*. |
| `DELETE /budgets/:id` | *FR-5.7*. |
| `GET /budgets/history?categoryId=&months=` | Past months' performance for one or all categories — *FR-5.6*. |

**`GET /budgets` card shape** (status derived server-side from spent/limit ratio — *FR-5.4, FR-5.5*):
```json
{ "categoryId": 3, "category": "Food & Dining", "limit": 8000, "spent": 6420,
  "percentUsed": 80.25, "status": "warning" }
```
`status` is one of `ok` (< 80%), `warning` (≥ 80%, < 100%), `over` (≥ 100%) — computed in the service layer so the frontend never re-derives threshold logic itself.

---

## 9. Goals — Epic 6
*(FR-6.1 – FR-6.7)*

| Method & Path | Description |
|---|---|
| `GET /goals?status=active\|achieved\|archived` | List with `currentAmount` always summed live from `GoalContributions` (*NFR-4.3*) — *FR-6.1, FR-6.2*. |
| `POST /goals` | Body: `{ name, targetAmount, targetDate? }` — *FR-6.1*. |
| `PUT /goals/:id` | Edit name/target/date — *FR-6.6*. |
| `DELETE /goals/:id` | *FR-6.6*. |
| `PUT /goals/:id/archive` | Moves an achieved (or abandoned) goal to `archived` — *FR-6.7*. |
| `POST /goals/:id/contributions` | Body: `{ amount, date }`. After insert, the service recomputes `currentAmount`; if it now meets `targetAmount`, the goal flips to `achieved` and the response includes `"justAchieved": true` so the frontend can trigger the gold-ribbon animation — *FR-6.3, FR-6.5*. |
| `GET /goals/:id/contributions` | Full contribution log, newest first — *FR-6.4*. |

---

## 10. Analytics — Epic 7
*(FR-7.1, FR-7.2, FR-7.4)*

| Method & Path | Description |
|---|---|
| `GET /analytics/category-breakdown?dateFrom=&dateTo=` | `{ category, amount, percentOfTotal }[]` for a donut/pie chart — *FR-7.1*. |
| `GET /analytics/trends?months=6` | `{ month, income, expense }[]` — *FR-7.2*. (Same shape as the dashboard's `cashFlow`; kept as a separate endpoint so `analytics.html` can request a longer range without bloating the dashboard payload.) |
| `GET /analytics/top-merchants?dateFrom=&dateTo=&limit=5` | `{ merchant, totalSpent, transactionCount }[]` — *FR-7.4*. |

---

## 11. Reports — Epic 8
*(FR-8.1 – FR-8.4)*

| Method & Path | Description |
|---|---|
| `POST /reports/generate` | Body: `{ dateFrom, dateTo }`. Returns summary totals + category breakdown for that range as JSON, for on-screen preview before export — *FR-8.1, FR-8.4*. |
| `GET /reports/export/pdf?dateFrom=&dateTo=` | Streams a generated PDF — *FR-8.2*. |
| `GET /reports/export/csv?dateFrom=&dateTo=` | Streams transaction rows as CSV — *FR-8.3*. |

---

## 12. Cross-Cutting Rules

| Rule | Where it's enforced |
|---|---|
| Every query filters by `req.userId`, regardless of any `userId`/`categoryId` ownership implied by client input | Repository layer, on every call — *NFR-2.3* |
| All list endpoints return in < 500ms under normal load | Backed by the indexes in Database-Design.md — *NFR-1.3* |
| All write endpoints validate the request body before touching the database | Controller-level validation (e.g. `zod`/`joi` schema) — *FR-9.4* |
| Server-side errors are logged with stack traces; client receives only `code` + `message` | Centralized Express error-handling middleware — *FR-9.3* |
| HTTPS enforced in production (HSTS header, redirect HTTP → HTTPS) | Reverse proxy / Express middleware in production config — *NFR-2.6* |

---

## Open Questions / Needs Confirmation
1. **Import preview statelessness:** this design has the client hold the previewed rows in memory and resend the full (possibly edited) array to `/imports/confirm`. The alternative is a server-side staging table keyed by a `previewId`, which avoids resending potentially large payloads but adds a cleanup job for abandoned previews. Confirm the stateless approach is acceptable before building the import UI around it.
2. **Token lifetimes:** exact access-token TTL (e.g. 15 min) and refresh-token TTL (e.g. 30 days) aren't specified yet — needed before implementing `/auth/refresh`'s expiry logic.
3. **CSV column mapping:** `/imports/preview` assumes a fixed expected column layout (date, description, amount). If different banks export different column orders/headers, a column-mapping step may need to be inserted between upload and preview — relates to FR open question #2 in Functional-Requirements.md.
4. **Report export format confirmation:** Functional-Requirements.md still has this as an open question — confirm both PDF and CSV are required for v1 (this design assumes both, per FR-8.2/FR-8.3) rather than just one.