# Functional Requirements

Each requirement is tagged with an ID (for traceability into User-Stories.md and API-Design.md), a source (where it was inferred from), and a priority.

**Priority key:** `P0` = must-have for v1 (per the 4-6 week Path A scope) · `P1` = nice-to-have if time allows · `P2` = future scope, not in current build.

---

## 1. Authentication & Account Management

| ID | Requirement | Source | Priority |
|---|---|---|---|
| FR-1.1 | User can register with name, email, and password | `register.html` (inferred from filename) | P0 |
| FR-1.2 | User can log in with email + password | `login.html` | P0 |
| FR-1.3 | Passwords are hashed before storage, never stored in plain text | Security best practice, not yet confirmed in HTML (no backend exists yet) | P0 |
| FR-1.4 | User receives a JWT access token on login | Architecture decision from Path A | P0 |
| FR-1.5 | User session persists via refresh token, avoiding re-login on every visit | Architecture decision from Path A | P1 |
| FR-1.6 | User can log out, invalidating their session | Standard auth flow | P0 |
| FR-1.7 | User can view and edit their profile (name, email) | `profile.html` (inferred from filename) | P0 |
| FR-1.8 | User can change their password | `profile.html` or `settings.html` — **needs confirmation which page owns this** | P0 |
| FR-1.9 | User can configure app-level settings (currency display, theme, notification preferences) | `settings.html` (inferred — exact settings unconfirmed) | P1 |

## 2. Dashboard

*(Source: `dashboard.html`, fully reviewed)*

| ID | Requirement | Priority |
|---|---|---|
| FR-2.1 | Dashboard displays total balance across all accounts | P0 |
| FR-2.2 | Dashboard displays current month income, with % change vs. previous month | P0 |
| FR-2.3 | Dashboard displays current month expenses, with % change vs. previous month | P0 |
| FR-2.4 | Dashboard displays savings rate (% of income not spent) | P0 |
| FR-2.5 | Dashboard displays a 6-month cash flow chart (income vs. expenses, grouped bars) | P0 |
| FR-2.6 | Dashboard displays the 5 most recent transactions with merchant, category, date, amount | P0 |
| FR-2.7 | Dashboard displays budget remaining per category (progress bar, amount spent / limit) | P0 |
| FR-2.8 | Dashboard displays active goals with progress ring (% complete) and current/target amount | P0 |
| FR-2.9 | Dashboard provides quick-action shortcuts: add transaction, create budget, new goal, export report | P1 |
| FR-2.10 | Dashboard greets user by name and shows current date | P1 |

## 3. Transactions

*(Source: `transactions.html` — page exists but not yet reviewed in detail; requirements below are inferred from dashboard's transaction table structure and standard finance-tracker behavior. **Confirm once file is shared.**)*

| ID | Requirement | Priority |
|---|---|---|
| FR-3.1 | User can view a paginated/scrollable list of all transactions | P0 |
| FR-3.2 | Each transaction shows: merchant name, category, date, amount, account/card source | P0 |
| FR-3.3 | User can manually add a new transaction (date, amount, category, merchant, notes) | P0 |
| FR-3.4 | User can edit an existing transaction | P0 |
| FR-3.5 | User can delete a transaction | P0 |
| FR-3.6 | User can filter transactions by category, date range, or account | P1 |
| FR-3.7 | User can search transactions by merchant name | P1 |
| FR-3.8 | User can manually re-categorize an imported transaction | P0 |
| FR-3.9 | Income and expense transactions are visually distinguished (color, sign) | P0 |

## 4. Bank Statement Import

*(Source: `import-bank-statement.html` — page exists but not yet reviewed. Requirements inferred from the feature name and standard import-flow UX patterns. **Confirm once file is shared.**)*

| ID | Requirement | Priority |
|---|---|---|
| FR-4.1 | User can upload a bank statement file (CSV format for v1) | P0 |
| FR-4.2 | System parses the uploaded file and extracts transaction rows (date, description, amount) | P0 |
| FR-4.3 | System auto-categorizes imported transactions using rule-based matching (e.g., "SWIGGY" → Food) | P0 |
| FR-4.4 | User can preview parsed transactions before confirming import | P0 |
| FR-4.5 | User can manually correct a transaction's category or merchant name during import review | P0 |
| FR-4.6 | System detects and flags potential duplicate transactions (already-imported entries) | P1 |
| FR-4.7 | System supports PDF or OFX statement formats | P2 (stretch — CSV only for v1) |
| FR-4.8 | User can view history of past imports (filename, date imported, number of transactions) | P1 |

## 5. Budgets

*(Source: user-provided description — "overview ring, alerts, category cards, history". Page not yet reviewed in raw HTML.)*

| ID | Requirement | Priority |
|---|---|---|
| FR-5.1 | User can create a budget for a category with a limit amount and period (monthly) | P0 |
| FR-5.2 | Budgets page shows an overview ring summarizing total budget usage across all categories | P0 |
| FR-5.3 | Each budget category is shown as a card with spent/limit amount and progress bar | P0 |
| FR-5.4 | System triggers an alert/warning state when a budget crosses a near-limit threshold (e.g., 80%) | P0 |
| FR-5.5 | System triggers an over-limit alert state when spending exceeds the budget | P0 |
| FR-5.6 | User can view historical budget performance for past months | P1 |
| FR-5.7 | User can edit or delete an existing budget | P0 |
| FR-5.8 | Budget progress automatically updates as new transactions are added/imported into that category | P0 |

## 6. Goals

*(Source: user-provided description — "progress rings, an achieved-goal state with the gold ribbon treatment, contribution log". Page not yet reviewed in raw HTML.)*

| ID | Requirement | Priority |
|---|---|---|
| FR-6.1 | User can create a savings goal with a name, target amount, and optional target date | P0 |
| FR-6.2 | Goal progress is displayed as a ring/percentage, consistent with the dashboard's goal-ring pattern | P0 |
| FR-6.3 | User can log a contribution toward a goal (amount + date) | P0 |
| FR-6.4 | User can view a contribution log/history per goal | P0 |
| FR-6.5 | When a goal reaches 100%, it transitions to an "achieved" visual state (gold ribbon treatment) | P0 |
| FR-6.6 | User can edit or delete a goal | P0 |
| FR-6.7 | User can archive an achieved goal | P1 |

## 7. Analytics

*(Source: page name only — `analytics.html` not yet reviewed. Requirements are best-guess based on typical finance-app analytics, distinct from the Dashboard's summary charts. **Confirm once file is shared.**)*

| ID | Requirement | Priority |
|---|---|---|
| FR-7.1 | User can view spending breakdown by category (pie/donut chart) for a selected period | P0 |
| FR-7.2 | User can view spending trends over time (line chart, multi-month) | P0 |
| FR-7.3 | User can compare income vs. expenses across custom date ranges | P1 |
| FR-7.4 | User can view top merchants by total spend | P1 |
| FR-7.5 | User can filter analytics by account, category, or date range | P1 |

## 8. Reports

*(Source: page name only — `reports.html` not yet reviewed. **Confirm once file is shared.**)*

| ID | Requirement | Priority |
|---|---|---|
| FR-8.1 | User can generate a report for a selected date range | P0 |
| FR-8.2 | User can export a report as PDF | P0 |
| FR-8.3 | User can export transaction data as Excel/CSV | P0 |
| FR-8.4 | Report includes summary totals (income, expenses, savings) and category breakdown | P0 |

## 9. Cross-Cutting Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-9.1 | All monetary values are displayed in a consistent currency format (₹ INR, per dashboard prototype) | P0 |
| FR-9.2 | All data shown is scoped to the logged-in user only (no cross-user data leakage) | P0 |
| FR-9.3 | System logs errors server-side without exposing internal details to the client | P0 |
| FR-9.4 | All forms validate input before submission (required fields, number formats, date formats) | P0 |

---

## Open Questions / Needs Confirmation
These can't be finalized until the remaining 9 HTML files are reviewed:
1. Does `settings.html` overlap with `profile.html`, or are responsibilities clearly split?
2. Does the import flow (FR-4.x) support multiple bank formats, or one fixed CSV layout?
3. Are "accounts" (bank account / credit card) a first-class entity the user manages, or is "account/card source" just a free-text field on each transaction?
4. What exact export formats does `reports.html` offer — PDF only, Excel only, or both?
5. Does `analytics.html` duplicate any dashboard charts, or is it strictly additional views?