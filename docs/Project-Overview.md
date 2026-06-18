# Project Overview

## Project Name
**FinTrack-Pro** — Personal Finance & Budget Tracker with Bank-Statement Import

> Name taken from the prototype HTML (`dashboard.html` title tag). Rename here and in `index.html` titles if you want something else.

## One-Line Pitch
A web application that lets a user import their bank statement, automatically organizes transactions into categories, tracks spending against budgets, and visualizes progress toward savings goals — replacing manual spreadsheet tracking.

## Problem Statement
Most people track personal finances using one of three methods, all flawed:
1. **Mental tracking** — inaccurate, no historical record, no early warning when overspending.
2. **Spreadsheets** — requires manual data entry for every transaction, easy to abandon after a few weeks.
3. **Generic banking apps** — show balances and raw transaction lists, but rarely offer category-level budgeting, goal tracking, or trend analysis in one place.

There is a gap for a lightweight, self-hosted-style tool that takes a CSV/statement export a user already has, auto-categorizes it, and gives them an at-a-glance view of where money goes — without requiring a live bank API integration (which needs paid third-party aggregators like Plaid and is out of scope for a portfolio project).

## Target Users
- Individuals who want a clearer picture of personal spending without manually building spreadsheets.
- Early-career professionals trying to build saving habits (the prototype's "Japan Trip" and "Emergency Fund" goals reflect this persona).
- As a portfolio project: technical reviewers (interviewers) evaluating full-stack, data-handling, and UI/UX skill.

## Core Value Proposition
| Without FinTrack-Pro | With FinTrack-Pro |
|---|---|
| Manually type every transaction into Excel | Import a bank statement file once; transactions appear automatically |
| No idea if you're overspending until the month ends | Live budget progress bars with near-limit warnings |
| Savings goals tracked in a separate note or not at all | Visual goal rings with contribution history |
| One big transaction list, no story | Dashboard + Analytics pages turn raw data into trends |

## Scope (What This Project IS)
- Single-user accounts (register/login) — not multi-tenant, not a B2B SaaS.
- Manual transaction entry **and** bulk import via bank statement file (CSV to start; PDF/OFX as stretch goals — see Non-Functional-Requirements.md).
- Category-based budgeting with progress tracking and overspend alerts.
- Goal-based savings tracking with contribution logs.
- Dashboard, Analytics, and Reports views for visualizing financial data.
- Exportable reports (PDF/Excel — confirm exact format once `reports.html` is reviewed).

## Scope (What This Project Is NOT)
- **Not** a live bank-account connector (no Plaid/Yodlee integration — those require paid API access and business verification, which is unrealistic for a student portfolio project).
- **Not** multi-tenant / multi-organization SaaS (each user only sees their own data — simpler tenancy than the earlier SaaS concepts discussed).
- **Not** a payments or money-movement product — it is read-only/tracking only. No real transactions are initiated.
- **Not** a mobile native app (web-responsive only, unless a future phase adds React Native).

## Pages Confirmed From Prototype (10 screens)
1. `login.html` — authentication
2. `register.html` — new account creation
3. `dashboard.html` — overview: balance, income/expense, cash flow chart, recent transactions, budget summary, goals summary, quick actions ✅ *reviewed in full*
4. `transactions.html` — full transaction list/management
5. `import-bank-statement.html` — file upload + mapping + categorization flow
6. `budgets.html` — overview ring, alerts, category cards, history
7. `goals.html` — progress rings, achieved-goal "gold ribbon" state, contribution log
8. `analytics.html` — deeper trend/breakdown visualizations
9. `reports.html` — exportable report generation
10. `profile.html` — user profile management
11. `settings.html` — app/account settings

> Note: that's 11 listed, not 10 — `profile.html` and `settings.html` are two separate pages. Worth double-checking this is intentional and not a duplicate.

## Design Language (from dashboard.html)
- **Theme:** Dark mode, near-black base (`#0A0E1A`) with layered surface tones.
- **Accent color:** Muted gold (`#C9A661`) — premium/private-banking feel, used for primary actions and brand mark.
- **Semantic colors:** Success green, error red, warning amber, info blue, indigo accent — all with soft 12%-opacity background variants for badges/icons.
- **Typography:** Plus Jakarta Sans (display/headings), Inter (body), IBM Plex Mono (all numeric values — balances, amounts, percentages).
- **Layout:** Fixed 264px sidebar + fluid main content, card-based grid layout, 16px corner radius on cards.

## Tech Stack (per Path A decision)
- **Frontend:** React + TypeScript (porting the static HTML/CSS prototypes into components)
- **Backend:** Node.js + Express + TypeScript
- **Database:** Microsoft SQL Server (MSSQL)
- **Cloud:** Azure (App Service, Azure SQL, Blob Storage for any uploaded statement files)
- **DevOps:** Docker, Docker Compose, GitHub Actions CI/CD

## Success Criteria
The project is "done" for portfolio purposes when:
- A user can register, log in, and see an empty-state dashboard.
- A user can upload a CSV bank statement and see transactions appear, auto-categorized.
- A user can create a budget per category and see live progress + an alert when near/over limit.
- A user can create a savings goal, log contributions, and see the goal marked "achieved" when reached.
- Analytics/Reports pages reflect real data from the database, not hardcoded values.
- The app is Dockerized and deployed to Azure with a working CI/CD pipeline.