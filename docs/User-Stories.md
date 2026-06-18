# User Stories

Format: `As a [user], I want to [action], so that [benefit].`
Each story references its related Functional Requirement ID(s) for traceability.

## Epic 1: Authentication & Account

- **US-1.1** — As a new user, I want to register with my name, email, and password, so that I can create my own private financial tracker. *(FR-1.1)*
- **US-1.2** — As a returning user, I want to log in with my email and password, so that I can access my saved financial data. *(FR-1.2, FR-1.3, FR-1.4)*
- **US-1.3** — As a logged-in user, I want my session to stay active without logging in every time I open the app, so that the experience feels seamless. *(FR-1.5)*
- **US-1.4** — As a user, I want to log out, so that my data is protected if I'm on a shared device. *(FR-1.6)*
- **US-1.5** — As a user, I want to update my profile information, so that my account details stay current. *(FR-1.7)*
- **US-1.6** — As a user, I want to change my password, so that I can keep my account secure. *(FR-1.8)*

## Epic 2: Dashboard Overview

- **US-2.1** — As a user, I want to see my total balance the moment I log in, so that I immediately know my financial position. *(FR-2.1)*
- **US-2.2** — As a user, I want to see this month's income and expenses compared to last month, so that I can spot trends quickly. *(FR-2.2, FR-2.3)*
- **US-2.3** — As a user, I want to see my savings rate, so that I know if I'm on track with my financial habits. *(FR-2.4)*
- **US-2.4** — As a user, I want to see a 6-month cash flow chart, so that I can visually understand my spending pattern over time. *(FR-2.5)*
- **US-2.5** — As a user, I want to see my most recent transactions on the dashboard, so that I don't have to navigate elsewhere to check recent activity. *(FR-2.6)*
- **US-2.6** — As a user, I want to see my budget progress at a glance, so that I know if I'm close to overspending in any category. *(FR-2.7)*
- **US-2.7** — As a user, I want to see my savings goals progress on the dashboard, so that I stay motivated toward my targets. *(FR-2.8)*
- **US-2.8** — As a user, I want quick-action buttons for common tasks, so that I can add a transaction or budget without extra navigation. *(FR-2.9)*

## Epic 3: Transaction Management

- **US-3.1** — As a user, I want to view all my transactions in one place, so that I can review my full financial history. *(FR-3.1, FR-3.2)*
- **US-3.2** — As a user, I want to manually add a transaction, so that I can log cash purchases that wouldn't appear in a bank statement. *(FR-3.3)*
- **US-3.3** — As a user, I want to edit a transaction, so that I can correct mistakes in amount, date, or category. *(FR-3.4)*
- **US-3.4** — As a user, I want to delete a transaction, so that I can remove duplicates or errors. *(FR-3.5)*
- **US-3.5** — As a user, I want to filter transactions by category or date range, so that I can find specific spending quickly. *(FR-3.6)*
- **US-3.6** — As a user, I want to search transactions by merchant name, so that I can quickly find all purchases from a specific store. *(FR-3.7)*
- **US-3.7** — As a user, I want to re-categorize a transaction that was auto-categorized incorrectly, so that my budgets and analytics stay accurate. *(FR-3.8)*

## Epic 4: Bank Statement Import

- **US-4.1** — As a user, I want to upload my bank statement file, so that I don't have to manually enter every transaction. *(FR-4.1, FR-4.2)*
- **US-4.2** — As a user, I want imported transactions to be automatically categorized, so that I save time on manual sorting. *(FR-4.3)*
- **US-4.3** — As a user, I want to preview my imported transactions before they're saved, so that I can catch errors before they pollute my data. *(FR-4.4)*
- **US-4.4** — As a user, I want to fix a category or merchant name during the import review step, so that my data is accurate from the start. *(FR-4.5)*
- **US-4.5** — As a user, I want the system to flag possible duplicate transactions during import, so that I don't accidentally double-count spending. *(FR-4.6)*
- **US-4.6** — As a user, I want to see a history of my past imports, so that I know what's already been added to my account. *(FR-4.8)*

## Epic 5: Budgets

- **US-5.1** — As a user, I want to set a monthly budget limit per category, so that I can control my spending intentionally. *(FR-5.1)*
- **US-5.2** — As a user, I want to see an overall budget usage summary, so that I understand my total spending discipline at a glance. *(FR-5.2)*
- **US-5.3** — As a user, I want to see each category's budget as a clear progress card, so that I can quickly spot which categories need attention. *(FR-5.3)*
- **US-5.4** — As a user, I want to be warned when I'm approaching a budget limit, so that I can adjust my spending before I go over. *(FR-5.4)*
- **US-5.5** — As a user, I want to be alerted when I've exceeded a budget, so that I'm aware and can course-correct next month. *(FR-5.5)*
- **US-5.6** — As a user, I want to view past months' budget performance, so that I can see if I'm improving over time. *(FR-5.6)*
- **US-5.7** — As a user, I want my budget progress to update automatically as I add or import transactions, so that I never have to manually recalculate it. *(FR-5.8)*

## Epic 6: Goals

- **US-6.1** — As a user, I want to create a savings goal with a target amount, so that I have something concrete to work toward. *(FR-6.1)*
- **US-6.2** — As a user, I want to see my goal progress as a visual ring, so that progress feels tangible and motivating. *(FR-6.2)*
- **US-6.3** — As a user, I want to log a contribution toward a goal, so that my progress reflects money I've actually set aside. *(FR-6.3)*
- **US-6.4** — As a user, I want to see a history of my contributions to a goal, so that I can track my saving consistency over time. *(FR-6.4)*
- **US-6.5** — As a user, I want my goal to visually celebrate when I reach it (gold ribbon), so that achieving a financial milestone feels rewarding. *(FR-6.5)*
- **US-6.6** — As a user, I want to edit or delete a goal, so that I can adjust my plans as life changes. *(FR-6.6)*

## Epic 7: Analytics

- **US-7.1** — As a user, I want to see my spending broken down by category, so that I understand where most of my money goes. *(FR-7.1)*
- **US-7.2** — As a user, I want to see spending trends over multiple months, so that I can identify whether my habits are improving or worsening. *(FR-7.2)*
- **US-7.3** — As a user, I want to see my top merchants by spend, so that I can identify where I might cut back. *(FR-7.4)*

## Epic 8: Reports

- **US-8.1** — As a user, I want to generate a report for a custom date range, so that I can review a specific period (e.g., for tax or budgeting purposes). *(FR-8.1)*
- **US-8.2** — As a user, I want to export a report as a PDF, so that I can save or share a clean summary of my finances. *(FR-8.2)*
- **US-8.3** — As a user, I want to export my transactions as Excel/CSV, so that I can do further analysis outside the app if I want to. *(FR-8.3)*

## Epic 9: Settings & Profile

- **US-9.1** — As a user, I want to configure app preferences (currency, notifications), so that the app fits how I want to use it. *(FR-1.9)*

---

## Story Mapping Note
Epics 2-8 map directly to the 10 (or 11) HTML prototype pages, meaning the UI design work is already largely done — the remaining effort for these stories is backend logic + wiring, not UI design from scratch. This is a meaningful head start on the timeline.