-- =============================================================================
-- FinTrack Pro — User-Defined Functions
-- Engine : Microsoft SQL Server 2022
-- =============================================================================
-- Scalar functions  → fn_<name>   (return a single value)
-- Table-valued      → tvf_<name>  (return a result set, use like a table)
-- =============================================================================

USE FinTrackPro;
GO

IF OBJECT_ID('dbo.fn_get_period_label',         'FN') IS NOT NULL DROP FUNCTION dbo.fn_get_period_label;
IF OBJECT_ID('dbo.fn_savings_rate',             'FN') IS NOT NULL DROP FUNCTION dbo.fn_savings_rate;
IF OBJECT_ID('dbo.fn_days_until_budget_reset',  'FN') IS NOT NULL DROP FUNCTION dbo.fn_days_until_budget_reset;
IF OBJECT_ID('dbo.fn_mask_account_number',      'FN') IS NOT NULL DROP FUNCTION dbo.fn_mask_account_number;
IF OBJECT_ID('dbo.tvf_user_cashflow',           'IF') IS NOT NULL DROP FUNCTION dbo.tvf_user_cashflow;
IF OBJECT_ID('dbo.tvf_transactions_paged',      'IF') IS NOT NULL DROP FUNCTION dbo.tvf_transactions_paged;
GO


-- =============================================================================
-- 1. fn_get_period_label
--    Returns a human-readable month label: "Jun 2026"
-- =============================================================================
CREATE FUNCTION dbo.fn_get_period_label (@date DATE)
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN LEFT(DATENAME(MONTH, @date), 3) + ' ' + CAST(YEAR(@date) AS NVARCHAR(4));
END;
GO


-- =============================================================================
-- 2. fn_savings_rate
--    Savings rate as a percentage: (income - expense) / income * 100
--    Returns 0 if income is 0 to avoid division by zero.
-- =============================================================================
CREATE FUNCTION dbo.fn_savings_rate (
    @total_income   DECIMAL(18,2),
    @total_expense  DECIMAL(18,2)
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    IF @total_income = 0 RETURN 0;
    RETURN ROUND((@total_income - @total_expense) / @total_income * 100, 2);
END;
GO


-- =============================================================================
-- 3. fn_days_until_budget_reset
--    How many days until the next budget cycle starts for a given user.
--    Uses the user_preference.budget_cycle_day.
-- =============================================================================
CREATE FUNCTION dbo.fn_days_until_budget_reset (
    @user_id    UNIQUEIDENTIFIER,
    @as_of      DATE            -- pass CAST(SYSUTCDATETIME() AS DATE) from caller
)
RETURNS INT
AS
BEGIN
    DECLARE @cycle_day  TINYINT;
    DECLARE @next_reset DATE;

    SELECT @cycle_day = budget_cycle_day
    FROM   dbo.user_preference
    WHERE  user_id = @user_id;

    IF @cycle_day IS NULL RETURN NULL;

    -- Build next reset date
    DECLARE @this_month_reset DATE = DATEFROMPARTS(YEAR(@as_of), MONTH(@as_of), @cycle_day);

    IF @this_month_reset > @as_of
        SET @next_reset = @this_month_reset;
    ELSE
        -- move to next month
        SET @next_reset = DATEADD(MONTH, 1, @this_month_reset);

    RETURN DATEDIFF(DAY, @as_of, @next_reset);
END;
GO


-- =============================================================================
-- 4. fn_mask_account_number
--    Returns "**** XXXX" from a raw account number string.
-- =============================================================================
CREATE FUNCTION dbo.fn_mask_account_number (@account_number NVARCHAR(30))
RETURNS NVARCHAR(12)
AS
BEGIN
    IF LEN(@account_number) < 4 RETURN '****';
    RETURN '**** ' + RIGHT(@account_number, 4);
END;
GO


-- =============================================================================
-- 5. tvf_user_cashflow
--    Inline table-valued function: returns income, expense, savings per month
--    for the given user over a rolling N-month window.
--    Usage: SELECT * FROM dbo.tvf_user_cashflow('user-guid', 6)
-- =============================================================================
CREATE FUNCTION dbo.tvf_user_cashflow (
    @user_id        UNIQUEIDENTIFIER,
    @months_back    INT             -- e.g. 6 for last 6 months
)
RETURNS TABLE
AS
RETURN (
    SELECT
        ms.period,
        ms.txn_year,
        ms.txn_month,
        dbo.fn_get_period_label(
            DATEFROMPARTS(ms.txn_year, ms.txn_month, 1)
        )                                               AS period_label,
        ms.total_income,
        ms.total_expense,
        ms.net_savings,
        dbo.fn_savings_rate(ms.total_income, ms.total_expense) AS savings_rate_pct,
        ms.total_transactions
    FROM
        dbo.vw_monthly_summary ms
    WHERE
        ms.user_id  = @user_id
        AND DATEFROMPARTS(ms.txn_year, ms.txn_month, 1)
            >= DATEFROMPARTS(
                YEAR(DATEADD(MONTH, -(@months_back - 1), SYSUTCDATETIME())),
                MONTH(DATEADD(MONTH, -(@months_back - 1), SYSUTCDATETIME())),
                1
               )
);
GO


-- =============================================================================
-- 6. tvf_transactions_paged
--    Server-side pagination with optional filters.
--    Called by the Transactions API endpoint to avoid pulling the full table.
--
--    Usage:
--      SELECT * FROM dbo.tvf_transactions_paged(
--          'user-guid',
--          NULL,           -- @account_id filter (NULL = all)
--          NULL,           -- @category_id filter
--          NULL,           -- @txn_type filter ('debit'|'credit'|NULL)
--          NULL,           -- @date_from
--          NULL,           -- @date_to
--          NULL,           -- @search keyword
--          1,              -- @page (1-based)
--          20              -- @page_size
--      )
-- =============================================================================
CREATE FUNCTION dbo.tvf_transactions_paged (
    @user_id        UNIQUEIDENTIFIER,
    @account_id     UNIQUEIDENTIFIER    = NULL,
    @category_id    UNIQUEIDENTIFIER    = NULL,
    @txn_type       NVARCHAR(10)        = NULL,
    @date_from      DATE                = NULL,
    @date_to        DATE                = NULL,
    @search         NVARCHAR(200)       = NULL,
    @page           INT                 = 1,
    @page_size      INT                 = 20
)
RETURNS TABLE
AS
RETURN (
    SELECT
        vt.transaction_id,
        vt.user_id,
        vt.account_id,
        vt.account_name,
        vt.masked_number,
        vt.category_id,
        vt.category_name,
        vt.category_icon,
        vt.category_color,
        vt.txn_date,
        vt.description,
        vt.merchant_name,
        vt.amount,
        vt.txn_type,
        vt.currency_code,
        vt.notes,
        vt.tags,
        vt.is_recurring,
        vt.is_verified,
        vt.created_at,
        -- total rows for pagination header
        COUNT(*) OVER ()    AS total_count,
        -- row number for offset
        ROW_NUMBER() OVER (ORDER BY vt.txn_date DESC, vt.created_at DESC) AS row_num
    FROM
        dbo.vw_recent_transactions vt
    WHERE
        vt.user_id  = @user_id
        AND (@account_id    IS NULL OR vt.account_id  = @account_id)
        AND (@category_id   IS NULL OR vt.category_id = @category_id)
        AND (@txn_type      IS NULL OR vt.txn_type    = @txn_type)
        AND (@date_from     IS NULL OR vt.txn_date   >= @date_from)
        AND (@date_to       IS NULL OR vt.txn_date   <= @date_to)
        AND (
            @search IS NULL
            OR vt.description   LIKE '%' + @search + '%'
            OR vt.merchant_name LIKE '%' + @search + '%'
            OR vt.notes         LIKE '%' + @search + '%'
        )
);
GO


PRINT 'functions.sql — all functions created successfully.';
GO