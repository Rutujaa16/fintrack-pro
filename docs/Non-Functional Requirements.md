# Non-Functional Requirements

Non-functional requirements (NFRs) describe *how well* the system performs its functions, not *what* it does. These are written to fit the 4-6 week, single-developer, learning-focused scope from Path A — not enterprise-scale targets.

## 1. Performance

| ID | Requirement |
|---|---|
| NFR-1.1 | Dashboard should load and render within 2 seconds on a typical broadband connection, for a user with up to ~5,000 transactions. |
| NFR-1.2 | CSV bank-statement import should process files up to 1,000 rows within 10 seconds. |
| NFR-1.3 | API responses for list endpoints (transactions, budgets, goals) should return in under 500ms under normal load. |
| NFR-1.4 | Charts (cash flow, analytics) should be computed server-side or client-side without blocking the UI thread for more than 200ms. |

> Note: these are reasonable *targets* for a portfolio project, not load-tested SLAs. Document them, implement sensibly (pagination, indexes — see Database-Design.md), but don't over-invest in performance engineering before functionality is complete.

## 2. Security

| ID | Requirement |
|---|---|
| NFR-2.1 | Passwords must be hashed using bcrypt (or equivalent) — never stored or logged in plain text. |
| NFR-2.2 | All API endpoints (except register/login) require a valid JWT access token. |
| NFR-2.3 | Every database query for user-owned data (transactions, budgets, goals) must be scoped by the authenticated user's ID — enforced at the service/repository layer, not just trusted from client input. |
| NFR-2.4 | File uploads (bank statements) must validate file type and size before processing, to prevent malicious or oversized uploads. |
| NFR-2.5 | Sensitive configuration (DB connection strings, JWT secrets) must be stored in environment variables / Azure Key Vault, never committed to source control. |
| NFR-2.6 | All traffic between client and server must use HTTPS in production. |
| NFR-2.7 | Refresh tokens should be stored securely (httpOnly cookie, not localStorage) to reduce XSS token-theft risk. |
| NFR-2.8 | Rate limiting should be applied to login/register endpoints to reduce brute-force risk. |

## 3. Usability

| ID | Requirement |
|---|---|
| NFR-3.1 | The UI must remain visually consistent with the existing prototype design system (dark theme, gold accent, Plus Jakarta Sans / Inter / IBM Plex Mono typography) across all pages. |
| NFR-3.2 | All monetary inputs/outputs use a consistent currency format and the IBM Plex Mono font, matching the prototype's numeric styling convention. |
| NFR-3.3 | Forms must show clear validation errors inline, not via generic alert popups. |
| NFR-3.4 | Empty states (no transactions yet, no budgets yet) must be designed intentionally, not left blank/broken. |
| NFR-3.5 | The app must be usable on common desktop screen sizes (1280px+ width, matching the prototype's `max-width:1280px` main content). Mobile responsiveness is a stretch goal (P1), not a v1 requirement. |

## 4. Reliability & Data Integrity

| ID | Requirement |
|---|---|
| NFR-4.1 | A failed bank-statement import must not partially write transactions — it's all-or-nothing per import batch (use a database transaction). |
| NFR-4.2 | Deleting a category that has existing transactions must be handled gracefully (reassign to "Uncategorized" or block deletion) — not silently corrupt data. |
| NFR-4.3 | Budget and goal progress values are always calculated from underlying transaction/contribution data, never stored as a manually-edited running total — preventing drift between displayed and actual values. |

## 5. Maintainability

| ID | Requirement |
|---|---|
| NFR-5.1 | Backend follows a layered architecture (routes → controllers → services → repositories), per Path A's architecture decision. |
| NFR-5.2 | Frontend components follow the component inventory derived from the HTML prototypes (Sidebar, StatCard, BudgetRow, GoalRing, etc.) rather than one-off page-specific markup. |
| NFR-5.3 | Shared design tokens (colors, fonts, spacing) are centralized in one location (Tailwind config or CSS variables file), not duplicated per page — directly addressing the current prototype's per-file `<style>` block duplication. |
| NFR-5.4 | Code follows consistent naming conventions (camelCase for variables/functions, PascalCase for components/classes, kebab-case for file names) as specified in Folder-Structure.md. |

## 6. Scalability (Portfolio-Appropriate Scope)

| ID | Requirement |
|---|---|
| NFR-6.1 | Database schema should support pagination on large tables (transactions) via indexed columns (user_id, date) — see Database-Design.md. |
| NFR-6.2 | The system is designed single-tenant (one user owns their data) — multi-tenant scaling is explicitly out of scope, per Project-Overview.md. |
| NFR-6.3 | Architecture should not block a future move to a queue-based import process (e.g., for very large files) but does not need to implement one now. |

## 7. Availability & Deployment

| ID | Requirement |
|---|---|
| NFR-7.1 | The application should be containerized (Docker) so it runs identically in local dev and Azure. |
| NFR-7.2 | CI/CD pipeline (GitHub Actions) must run automated checks (build, lint, basic tests) before allowing deployment. |
| NFR-7.3 | The deployed app should have basic uptime suitable for demo purposes — formal SLA/uptime guarantees are out of scope. |

## 8. Compliance & Data Privacy (Portfolio Context)

| ID | Requirement |
|---|---|
| NFR-8.1 | Since this handles financial data, treat all transaction/account data as sensitive even though it's a portfolio project — don't use real personal bank statements with real account numbers in demos; use sanitized/sample data. |
| NFR-8.2 | If demoing publicly, mask or use fictional merchant/account data (the prototype's `**** 4821` masked card pattern is a good model to keep). |

## 9. File Format Support (Import Feature)

| ID | Requirement |
|---|---|
| NFR-9.1 | v1 supports CSV import only. |
| NFR-9.2 | PDF and OFX/QFX statement format support are explicitly deferred to a post-v1 phase (P2) — do not attempt mid-build, it adds significant parsing complexity (PDF table extraction is non-trivial). |