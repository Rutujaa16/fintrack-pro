-- =============================================================================
-- FinTrack Pro — Views
-- Engine : Microsoft SQL Server 2022
-- =============================================================================
-- Views here are READ-ONLY query helpers — no indexed views to keep writes fast.
-- All monetary aggregations use ISNULL(..., 0) so the API never gets NULL.
-- =============================================================================

USE FinTrackPro;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- Drop if exists helpers
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.vw_monthly_summary',          'V') IS NOT NULL DROP VIEW dbo.vw_monthly_summary;
IF OBJECT_ID('dbo.vw_category_monthly_totals',  'V') IS NOT NULL DROP VIEW dbo.vw_category_monthly_totals;
IF OBJECT_ID('dbo.vw_budget_utilization',       'V') IS NOT NULL DROP VIEW dbo.vw_budget_utilization;
IF OBJECT_ID('dbo.vw_goal_progress',            'V') IS NOT NULL DROP VIEW dbo.vw_goal_progress;
IF OBJECT_ID('dbo.vw_account_balance',          'V') IS NOT NULL DROP VIEW dbo.vw_account_balance;
IF OBJECT_ID('dbo.vw_recent_transactions',      'V') IS NOT NULL DROP VIEW dbo.vw_recent_transactions;
IF OBJECT_ID('dbo.vw_top_merchants',            'V') IS NOT NULL DROP VIEW dbo.vw_top_merchants;
IF OBJECT_ID('dbo.vw_import_history',           'V') IS NOT NULL DROP VIEW dbo.vw_import_history;
GO


-- =============================================================================
-- 1. vw_monthly_summary
--    Income / expense / net savings per user per calendar month.
--    Used by: Dashboard KPI cards, Analytics trend chart.
-- =============================================================================
CREATE VIEW dbo.vw_monthly_summary AS
SELECT
    t.user_id,
    YEAR(t.txn_date)                                            AS txn_year,
    MONTH(t.txn_date)                                           AS txn_month,
    -- ISO-formatted label e.g. "2026-06"
    FORMAT(t.txn_date, 'yyyy-MM')                               AS period,

    ISNULL(SUM(CASE WHEN t.txn_type = 'credit' THEN t.amount ELSE 0 END), 0) AS total_income,
    ISNULL(SUM(CASE WHEN t.txn_type = 'debit'  THEN t.amount ELSE 0 END), 0) AS total_expense,
    ISNULL(SUM(CASE WHEN t.txn_type = 'credit' THEN t.amount
                    WHEN t.txn_type = 'debit'  THEN -t.amount
                    ELSE 0 END), 0)                             AS net_savings,

    COUNT(*)                                                    AS total_transactions,
    COUNT(CASE WHEN t.txn_type = 'credit' THEN 1 END)          AS income_count,
    COUNT(CASE WHEN t.txn_type = 'debit'  THEN 1 END)          AS expense_count
FROM
    dbo.[transaction] t
WHERE
    t.is_deleted    = 0
    AND t.is_excluded = 0
    AND t.txn_type  IN ('credit','debit')
GROUP BY
    t.user_id,
    YEAR(t.txn_date),
    MONTH(t.txn_date),
    FORMAT(t.txn_date, 'yyyy-MM');
GO


-- =============================================================================
-- 2. vw_category_monthly_totals
--    Total spend per category per user per month.
--    Used by: Donut chart, Budget utilization, Analytics breakdown.
-- =============================================================================
CREATE VIEW dbo.vw_category_monthly_totals AS
SELECT
    t.user_id,
    t.category_id,
    c.name                                  AS category_name,
    c.icon                                  AS category_icon,
    c.color                                 AS category_color,
    c.category_type,
    FORMAT(t.txn_date, 'yyyy-MM')           AS period,
    YEAR(t.txn_date)                        AS txn_year,
    MONTH(t.txn_date)                       AS txn_month,
    ISNULL(SUM(t.amount), 0)               AS total_amount,
    COUNT(*)                                AS transaction_count
FROM
    dbo.[transaction] t
    INNER JOIN dbo.category c ON t.category_id = c.category_id
WHERE
    t.is_deleted    = 0
    AND t.is_excluded = 0
    AND c.is_deleted  = 0
GROUP BY
    t.user_id,
    t.category_id,
    c.name, c.icon, c.color, c.category_type,
    FORMAT(t.txn_date, 'yyyy-MM'),
    YEAR(t.txn_date),
    MONTH(t.txn_date);
GO


-- =============================================================================
-- 3. vw_budget_utilization
--    Current-period spend vs limit for each budget_category.
--    Used by: Budget page progress bars, Dashboard budget widget, Alerts engine.
-- =============================================================================
CREATE VIEW dbo.vw_budget_utilization AS
SELECT
    b.budget_id,
    b.user_id,
    b.name                                                          AS budget_name,
    b.period_start,
    b.period_end,
    b.total_limit,

    bc.budget_category_id,
    bc.category_id,
    c.name                                                          AS category_name,
    c.icon                                                          AS category_icon,
    c.color                                                         AS category_color,
    bc.amount_limit,
    bc.alert_at_percent,

    -- actual spend in period
    ISNULL(SUM(t.amount), 0)                                        AS amount_spent,

    -- derived metrics
    ISNULL(bc.amount_limit - SUM(t.amount), bc.amount_limit)       AS amount_remaining,
    CASE
        WHEN bc.amount_limit = 0 THEN 0
        ELSE ROUND(ISNULL(SUM(t.amount), 0) / bc.amount_limit * 100, 2)
    END                                                             AS utilization_pct,

    -- status label used by the frontend badge
    CASE
        WHEN ISNULL(SUM(t.amount), 0) > bc.amount_limit            THEN 'over'
        WHEN ISNULL(SUM(t.amount), 0) >= bc.amount_limit
                                       * bc.alert_at_percent / 100 THEN 'warning'
        ELSE 'ok'
    END                                                             AS status
FROM
    dbo.budget              b
    INNER JOIN dbo.budget_category bc ON b.budget_id      = bc.budget_id
    INNER JOIN dbo.category        c  ON bc.category_id   = c.category_id
    LEFT  JOIN dbo.[transaction]   t  ON t.category_id    = bc.category_id
                                      AND t.user_id        = b.user_id
                                      AND t.txn_date       BETWEEN b.period_start AND b.period_end
                                      AND t.txn_type       = 'debit'
                                      AND t.is_deleted     = 0
                                      AND t.is_excluded    = 0
WHERE
    b.is_active = 1
GROUP BY
    b.budget_id, b.user_id, b.name, b.period_start, b.period_end, b.total_limit,
    bc.budget_category_id, bc.category_id, bc.amount_limit, bc.alert_at_percent,
    c.name, c.icon, c.color;
GO


-- =============================================================================
-- 4. vw_goal_progress
--    Goal with computed progress percentage and projected completion date.
--    Used by: Goals page, Dashboard goal widget.
-- =============================================================================
CREATE VIEW dbo.vw_goal_progress AS
SELECT
    g.goal_id,
    g.user_id,
    g.name,
    g.description,
    g.icon,
    g.color,
    g.target_amount,
    g.current_amount,
    g.currency_code,
    g.monthly_contribution,
    g.target_date,
    g.achieved_at,
    g.status,
    g.created_at,

    -- progress percentage (0–100, capped)
    CASE
        WHEN g.target_amount = 0 THEN 0
        ELSE LEAST(ROUND(g.current_amount / g.target_amount * 100, 2), 100)
    END                                                         AS progress_pct,

    -- amount still needed
    GREATEST(g.target_amount - g.current_amount, 0)            AS amount_remaining,

    -- projected months to goal based on monthly_contribution
    CASE
        WHEN g.monthly_contribution IS NULL OR g.monthly_contribution = 0 THEN NULL
        WHEN g.current_amount >= g.target_amount THEN 0
        ELSE CEILING((g.target_amount - g.current_amount) / g.monthly_contribution)
    END                                                         AS months_to_goal,

    -- total contributions count
    (
        SELECT COUNT(*)
        FROM dbo.goal_contribution gc
        WHERE gc.goal_id = g.goal_id
          AND gc.contribution_type <> 'withdrawal'
    )                                                           AS contribution_count
FROM
    dbo.goal g
WHERE
    g.is_deleted = 0;
GO


-- =============================================================================
-- 5. vw_account_balance
--    Live balance = opening + sum of credits – sum of debits.
--    Used by: Account list, Dashboard total balance card.
-- =============================================================================
CREATE VIEW dbo.vw_account_balance AS
SELECT
    a.account_id,
    a.user_id,
    a.name                  AS account_name,
    a.institution,
    a.account_type,
    a.masked_number,
    a.currency_code,
    a.color,
    a.icon,
    a.is_default,

    -- recomputed from transactions (source of truth)
    ISNULL(SUM(
        CASE t.txn_type
            WHEN 'credit'   THEN  t.amount
            WHEN 'debit'    THEN -t.amount
            ELSE 0
        END
    ), 0)                   AS computed_balance,

    COUNT(t.transaction_id) AS total_transactions
FROM
    dbo.account a
    LEFT JOIN dbo.[transaction] t ON a.account_id = t.account_id
                                  AND t.is_deleted  = 0
                                  AND t.is_excluded = 0
WHERE
    a.is_deleted = 0
GROUP BY
    a.account_id, a.user_id, a.name, a.institution, a.account_type,
    a.masked_number, a.currency_code, a.color, a.icon, a.is_default;
GO


-- =============================================================================
-- 6. vw_recent_transactions
--    Pre-joined transaction rows for dashboard / list API endpoint.
--    Joins in category and account names so the API avoids N+1 queries.
-- =============================================================================
CREATE VIEW dbo.vw_recent_transactions AS
SELECT
    t.transaction_id,
    t.user_id,
    t.account_id,
    a.name          AS account_name,
    a.institution   AS account_institution,
    a.masked_number,

    t.category_id,
    c.name          AS category_name,
    c.icon          AS category_icon,
    c.color         AS category_color,
    c.category_type,

    t.txn_date,
    t.description,
    t.merchant_name,
    t.amount,
    t.txn_type,
    t.currency_code,
    t.reference_id,
    t.notes,
    t.tags,
    t.is_recurring,
    t.is_verified,
    t.is_excluded,
    t.import_session_id,
    t.created_at
FROM
    dbo.[transaction] t
    INNER JOIN dbo.account  a ON t.account_id  = a.account_id
    LEFT  JOIN dbo.category c ON t.category_id = c.category_id
WHERE
    t.is_deleted = 0
    AND a.is_deleted = 0;
GO


-- =============================================================================
-- 7. vw_top_merchants
--    Aggregated merchant spend per user per month.
--    Used by: Analytics "Top Merchants" table.
-- =============================================================================
CREATE VIEW dbo.vw_top_merchants AS
SELECT
    t.user_id,
    FORMAT(t.txn_date, 'yyyy-MM')       AS period,
    ISNULL(t.merchant_name, t.description) AS merchant,
    t.category_id,
    c.name                              AS category_name,
    COUNT(*)                            AS transaction_count,
    ISNULL(SUM(t.amount), 0)           AS total_spent
FROM
    dbo.[transaction] t
    LEFT JOIN dbo.category c ON t.category_id = c.category_id
WHERE
    t.is_deleted    = 0
    AND t.is_excluded = 0
    AND t.txn_type  = 'debit'
GROUP BY
    t.user_id,
    FORMAT(t.txn_date, 'yyyy-MM'),
    ISNULL(t.merchant_name, t.description),
    t.category_id,
    c.name;
GO


-- =============================================================================
-- 8. vw_import_history
--    Import sessions with summary stats for the Import History table.
-- =============================================================================
CREATE VIEW dbo.vw_import_history AS
SELECT
    i.import_session_id,
    i.user_id,
    i.account_id,
    a.name          AS account_name,
    i.original_filename,
    i.file_type,
    i.file_size_bytes,
    i.total_rows,
    i.valid_rows,
    i.imported_rows,
    i.skipped_rows,
    i.error_rows,
    i.status,
    i.completed_at,
    i.created_at,
    -- success rate %
    CASE
        WHEN i.total_rows = 0 THEN 0
        ELSE ROUND(CAST(i.imported_rows AS FLOAT) / i.total_rows * 100, 1)
    END             AS success_rate_pct
FROM
    dbo.import_session  i
    INNER JOIN dbo.account a ON i.account_id = a.account_id;
GO

PRINT 'views.sql — all views created successfully.';
GO