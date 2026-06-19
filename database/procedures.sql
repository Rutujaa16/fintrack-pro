-- =============================================================================
-- FinTrack Pro — Stored Procedures
-- Engine : Microsoft SQL Server 2022
-- =============================================================================
-- Naming convention: usp_<entity>_<verb>
-- All procedures use:
--   - TRY/CATCH + THROW for error propagation
--   - Explicit transactions where multiple writes occur
--   - OUTPUT parameters for returning IDs back to the caller
-- =============================================================================

USE FinTrackPro;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- Drop helpers
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.usp_user_register',               'P') IS NOT NULL DROP PROCEDURE dbo.usp_user_register;
IF OBJECT_ID('dbo.usp_transaction_upsert',          'P') IS NOT NULL DROP PROCEDURE dbo.usp_transaction_upsert;
IF OBJECT_ID('dbo.usp_transaction_soft_delete',     'P') IS NOT NULL DROP PROCEDURE dbo.usp_transaction_soft_delete;
IF OBJECT_ID('dbo.usp_import_begin_session',        'P') IS NOT NULL DROP PROCEDURE dbo.usp_import_begin_session;
IF OBJECT_ID('dbo.usp_import_bulk_insert',          'P') IS NOT NULL DROP PROCEDURE dbo.usp_import_bulk_insert;
IF OBJECT_ID('dbo.usp_import_complete_session',     'P') IS NOT NULL DROP PROCEDURE dbo.usp_import_complete_session;
IF OBJECT_ID('dbo.usp_budget_create_monthly',       'P') IS NOT NULL DROP PROCEDURE dbo.usp_budget_create_monthly;
IF OBJECT_ID('dbo.usp_budget_check_alerts',         'P') IS NOT NULL DROP PROCEDURE dbo.usp_budget_check_alerts;
IF OBJECT_ID('dbo.usp_goal_add_contribution',       'P') IS NOT NULL DROP PROCEDURE dbo.usp_goal_add_contribution;
IF OBJECT_ID('dbo.usp_account_recalc_balance',      'P') IS NOT NULL DROP PROCEDURE dbo.usp_account_recalc_balance;
GO


-- =============================================================================
-- 1. usp_user_register
--    Creates user + default preferences + default categories in one transaction.
-- =============================================================================
CREATE PROCEDURE dbo.usp_user_register
    @email          NVARCHAR(255),
    @full_name      NVARCHAR(150),
    @password_hash  NVARCHAR(255),
    @currency_code  NCHAR(3)       = 'INR',
    @user_id        UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.app_user WHERE email = @email AND is_deleted = 0)
        THROW 50001, 'Email already registered.', 1;

    SET @user_id = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

            -- 1a. Insert user
            INSERT INTO dbo.app_user (user_id, email, full_name, password_hash)
            VALUES (@user_id, @email, @full_name, @password_hash);

            -- 1b. Default preferences
            INSERT INTO dbo.user_preference (user_id, currency_code)
            VALUES (@user_id, @currency_code);

            -- 1c. Seed default categories for this user
            --     (copies system categories into user scope so they can customise)
            INSERT INTO dbo.category (user_id, parent_category_id, name, icon, color, category_type, is_system)
            SELECT
                @user_id,
                NULL,
                name, icon, color, category_type,
                0   -- user copy, not system
            FROM dbo.category
            WHERE is_system = 1 AND parent_category_id IS NULL AND is_deleted = 0;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


-- =============================================================================
-- 2. usp_transaction_upsert
--    INSERT or UPDATE a single transaction.
--    Pass @transaction_id = NULL to insert, or an existing ID to update.
-- =============================================================================
CREATE PROCEDURE dbo.usp_transaction_upsert
    @transaction_id     UNIQUEIDENTIFIER    = NULL,
    @user_id            UNIQUEIDENTIFIER,
    @account_id         UNIQUEIDENTIFIER,
    @category_id        UNIQUEIDENTIFIER    = NULL,
    @import_session_id  UNIQUEIDENTIFIER    = NULL,
    @txn_date           DATE,
    @description        NVARCHAR(500),
    @amount             DECIMAL(18,2),
    @txn_type           NVARCHAR(10),
    @currency_code      NCHAR(3)            = 'INR',
    @merchant_name      NVARCHAR(150)       = NULL,
    @reference_id       NVARCHAR(100)       = NULL,
    @notes              NVARCHAR(1000)      = NULL,
    @tags               NVARCHAR(500)       = NULL,
    @is_recurring       BIT                 = 0,
    @out_id             UNIQUEIDENTIFIER    OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate amount
    IF @amount <= 0
        THROW 50010, 'Transaction amount must be positive.', 1;

    IF @transaction_id IS NULL
    BEGIN
        -- INSERT
        SET @out_id = NEWID();
        INSERT INTO dbo.[transaction] (
            transaction_id, user_id, account_id, category_id, import_session_id,
            txn_date, description, amount, txn_type, currency_code,
            merchant_name, reference_id, notes, tags, is_recurring
        ) VALUES (
            @out_id, @user_id, @account_id, @category_id, @import_session_id,
            @txn_date, @description, @amount, @txn_type, @currency_code,
            @merchant_name, @reference_id, @notes, @tags, @is_recurring
        );
    END
    ELSE
    BEGIN
        -- UPDATE — only the calling user's own transaction
        IF NOT EXISTS (
            SELECT 1 FROM dbo.[transaction]
            WHERE transaction_id = @transaction_id AND user_id = @user_id AND is_deleted = 0
        )
            THROW 50011, 'Transaction not found or access denied.', 1;

        SET @out_id = @transaction_id;
        UPDATE dbo.[transaction]
        SET
            account_id      = @account_id,
            category_id     = @category_id,
            txn_date        = @txn_date,
            description     = @description,
            amount          = @amount,
            txn_type        = @txn_type,
            currency_code   = @currency_code,
            merchant_name   = @merchant_name,
            reference_id    = @reference_id,
            notes           = @notes,
            tags            = @tags,
            is_recurring    = @is_recurring,
            updated_at      = SYSUTCDATETIME()
        WHERE transaction_id = @transaction_id AND user_id = @user_id;
    END;

    -- Sync account balance
    EXEC dbo.usp_account_recalc_balance @account_id;
END;
GO


-- =============================================================================
-- 3. usp_transaction_soft_delete
--    Soft-deletes a transaction (or bulk if @transaction_ids JSON array passed).
-- =============================================================================
CREATE PROCEDURE dbo.usp_transaction_soft_delete
    @user_id            UNIQUEIDENTIFIER,
    @transaction_ids    NVARCHAR(MAX)       -- JSON array: ["id1","id2",...]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            UPDATE dbo.[transaction]
            SET
                is_deleted  = 1,
                deleted_at  = SYSUTCDATETIME(),
                updated_at  = SYSUTCDATETIME()
            WHERE
                user_id         = @user_id
                AND is_deleted  = 0
                AND transaction_id IN (
                    SELECT CAST(value AS UNIQUEIDENTIFIER)
                    FROM OPENJSON(@transaction_ids)
                );

            -- Recalculate affected accounts
            DECLARE @acc UNIQUEIDENTIFIER;
            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT account_id
                FROM dbo.[transaction]
                WHERE user_id = @user_id
                  AND transaction_id IN (
                      SELECT CAST(value AS UNIQUEIDENTIFIER)
                      FROM OPENJSON(@transaction_ids)
                  );

            OPEN cur;
            FETCH NEXT FROM cur INTO @acc;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC dbo.usp_account_recalc_balance @acc;
                FETCH NEXT FROM cur INTO @acc;
            END;
            CLOSE cur;
            DEALLOCATE cur;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


-- =============================================================================
-- 4. usp_import_begin_session
--    Creates an import_session row and returns its ID to the caller.
-- =============================================================================
CREATE PROCEDURE dbo.usp_import_begin_session
    @user_id            UNIQUEIDENTIFIER,
    @account_id         UNIQUEIDENTIFIER,
    @original_filename  NVARCHAR(260),
    @file_type          NVARCHAR(10),
    @file_size_bytes    BIGINT          = NULL,
    @storage_path       NVARCHAR(500)   = NULL,
    @session_id         UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @session_id = NEWID();

    INSERT INTO dbo.import_session (
        import_session_id, user_id, account_id,
        original_filename, file_type, file_size_bytes, storage_path, status
    ) VALUES (
        @session_id, @user_id, @account_id,
        @original_filename, @file_type, @file_size_bytes, @storage_path, 'pending'
    );
END;
GO


-- =============================================================================
-- 5. usp_import_bulk_insert
--    High-performance bulk insert of validated rows from a single import session.
--    Receives a JSON array of transaction objects from the FastAPI service.
--    Skips rows that are exact duplicates (same account, date, amount, description).
-- =============================================================================
CREATE PROCEDURE dbo.usp_import_bulk_insert
    @import_session_id  UNIQUEIDENTIFIER,
    @user_id            UNIQUEIDENTIFIER,
    @account_id         UNIQUEIDENTIFIER,
    @rows_json          NVARCHAR(MAX),      -- JSON array of mapped rows
    @inserted_count     INT OUTPUT,
    @skipped_count      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate JSON
    IF ISJSON(@rows_json) = 0
        THROW 50020, 'rows_json is not valid JSON.', 1;

    DECLARE @staging TABLE (
        row_number          INT,
        txn_date            DATE,
        description         NVARCHAR(500),
        amount              DECIMAL(18,2),
        txn_type            NVARCHAR(10),
        merchant_name       NVARCHAR(150),
        reference_id        NVARCHAR(100),
        category_id         UNIQUEIDENTIFIER,
        is_duplicate        BIT DEFAULT 0
    );

    -- Parse JSON into staging
    INSERT INTO @staging (row_number, txn_date, description, amount, txn_type, merchant_name, reference_id, category_id)
    SELECT
        CAST(j.row_number     AS INT),
        CAST(j.txn_date       AS DATE),
        CAST(j.description    AS NVARCHAR(500)),
        CAST(j.amount         AS DECIMAL(18,2)),
        CAST(j.txn_type       AS NVARCHAR(10)),
        CAST(j.merchant_name  AS NVARCHAR(150)),
        CAST(j.reference_id   AS NVARCHAR(100)),
        TRY_CAST(j.category_id AS UNIQUEIDENTIFIER)
    FROM OPENJSON(@rows_json) WITH (
        row_number      INT             '$.row_number',
        txn_date        NVARCHAR(20)    '$.txn_date',
        description     NVARCHAR(500)   '$.description',
        amount          NVARCHAR(30)    '$.amount',
        txn_type        NVARCHAR(10)    '$.txn_type',
        merchant_name   NVARCHAR(150)   '$.merchant_name',
        reference_id    NVARCHAR(100)   '$.reference_id',
        category_id     NVARCHAR(36)    '$.category_id'
    ) j;

    -- Flag duplicates: same account + date + amount + description already exists
    UPDATE s
    SET s.is_duplicate = 1
    FROM @staging s
    WHERE EXISTS (
        SELECT 1 FROM dbo.[transaction] t
        WHERE t.account_id  = @account_id
          AND t.txn_date    = s.txn_date
          AND t.amount      = s.amount
          AND t.description = s.description
          AND t.is_deleted  = 0
    );

    BEGIN TRY
        BEGIN TRANSACTION;

            -- Bulk insert non-duplicate rows
            INSERT INTO dbo.[transaction] (
                transaction_id, user_id, account_id, category_id, import_session_id,
                txn_date, description, original_description,
                amount, txn_type, currency_code,
                merchant_name, reference_id
            )
            SELECT
                NEWID(), @user_id, @account_id, s.category_id, @import_session_id,
                s.txn_date, s.description, s.description,
                s.amount, s.txn_type, 'INR',
                s.merchant_name, s.reference_id
            FROM @staging s
            WHERE s.is_duplicate = 0
              AND s.amount > 0;

            SET @inserted_count = @@ROWCOUNT;
            SET @skipped_count  = (SELECT COUNT(*) FROM @staging WHERE is_duplicate = 1);

            -- Update session counters and status
            UPDATE dbo.import_session
            SET
                imported_rows   = @inserted_count,
                skipped_rows    = @skipped_count,
                status          = 'completed',
                completed_at    = SYSUTCDATETIME(),
                updated_at      = SYSUTCDATETIME()
            WHERE import_session_id = @import_session_id;

            -- Sync account balance
            EXEC dbo.usp_account_recalc_balance @account_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        -- Mark session as failed
        UPDATE dbo.import_session
        SET status = 'failed', error_message = ERROR_MESSAGE(), updated_at = SYSUTCDATETIME()
        WHERE import_session_id = @import_session_id;

        THROW;
    END CATCH;
END;
GO


-- =============================================================================
-- 6. usp_import_complete_session
--    Finalises column_mapping JSON and row counts after validation step.
-- =============================================================================
CREATE PROCEDURE dbo.usp_import_complete_session
    @import_session_id  UNIQUEIDENTIFIER,
    @column_mapping     NVARCHAR(MAX),
    @total_rows         INT,
    @valid_rows         INT,
    @error_rows         INT
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@column_mapping) = 0
        THROW 50021, 'column_mapping is not valid JSON.', 1;

    UPDATE dbo.import_session
    SET
        column_mapping  = @column_mapping,
        total_rows      = @total_rows,
        valid_rows      = @valid_rows,
        error_rows      = @error_rows,
        status          = 'validating',
        updated_at      = SYSUTCDATETIME()
    WHERE import_session_id = @import_session_id;
END;
GO


-- =============================================================================
-- 7. usp_budget_create_monthly
--    Creates a budget + budget_category rows for the current/next month.
--    @categories_json: [{"category_id":"...","amount_limit":5000}, ...]
-- =============================================================================
CREATE PROCEDURE dbo.usp_budget_create_monthly
    @user_id            UNIQUEIDENTIFIER,
    @period_start       DATE,
    @total_limit        DECIMAL(18,2),
    @categories_json    NVARCHAR(MAX),
    @budget_id          UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@categories_json) = 0
        THROW 50030, 'categories_json is not valid JSON.', 1;

    SET @budget_id = NEWID();

    -- period_end = last day of the month containing period_start
    DECLARE @period_end DATE = EOMONTH(@period_start);

    BEGIN TRY
        BEGIN TRANSACTION;

            INSERT INTO dbo.budget (budget_id, user_id, name, period_start, period_end, total_limit)
            VALUES (@budget_id, @user_id,
                    CONCAT(DATENAME(MONTH,@period_start), ' ', YEAR(@period_start), ' Budget'),
                    @period_start, @period_end, @total_limit);

            INSERT INTO dbo.budget_category (budget_id, category_id, amount_limit)
            SELECT
                @budget_id,
                CAST(j.category_id AS UNIQUEIDENTIFIER),
                CAST(j.amount_limit AS DECIMAL(18,2))
            FROM OPENJSON(@categories_json) WITH (
                category_id  NVARCHAR(36) '$.category_id',
                amount_limit NVARCHAR(20) '$.amount_limit'
            ) j
            WHERE CAST(j.amount_limit AS DECIMAL(18,2)) > 0;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


-- =============================================================================
-- 8. usp_budget_check_alerts
--    Called after each transaction insert.
--    Returns a result-set of fired alerts → FastAPI notification service picks up.
-- =============================================================================
CREATE PROCEDURE dbo.usp_budget_check_alerts
    @user_id    UNIQUEIDENTIFIER,
    @txn_date   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        bu.budget_id,
        bu.budget_category_id,
        bu.category_id,
        bu.category_name,
        bu.amount_limit,
        bu.amount_spent,
        bu.utilization_pct,
        bu.status,
        bu.alert_at_percent,
        CASE
            WHEN bu.status = 'over'    THEN 'budget_exceeded'
            WHEN bu.status = 'warning' THEN 'budget_alert'
        END AS alert_type
    FROM
        dbo.vw_budget_utilization bu
    WHERE
        bu.user_id      = @user_id
        AND bu.status   IN ('warning','over')
        AND @txn_date   BETWEEN bu.period_start AND bu.period_end;
END;
GO


-- =============================================================================
-- 9. usp_goal_add_contribution
--    Adds money to a goal and updates current_amount.
--    Sets achieved_at if target is reached.
-- =============================================================================
CREATE PROCEDURE dbo.usp_goal_add_contribution
    @goal_id            UNIQUEIDENTIFIER,
    @user_id            UNIQUEIDENTIFIER,
    @amount             DECIMAL(18,2),
    @contribution_type  NVARCHAR(10)    = 'manual',
    @notes              NVARCHAR(300)   = NULL,
    @contribution_id    UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @amount = 0
        THROW 50040, 'Contribution amount cannot be zero.', 1;

    -- Ownership check
    IF NOT EXISTS (
        SELECT 1 FROM dbo.goal
        WHERE goal_id = @goal_id AND user_id = @user_id AND is_deleted = 0
    )
        THROW 50041, 'Goal not found or access denied.', 1;

    SET @contribution_id = NEWID();

    BEGIN TRY
        BEGIN TRANSACTION;

            INSERT INTO dbo.goal_contribution (contribution_id, goal_id, user_id, amount, contribution_type, notes)
            VALUES (@contribution_id, @goal_id, @user_id, @amount, @contribution_type, @notes);

            -- Update goal balance
            UPDATE dbo.goal
            SET
                current_amount  = current_amount + @amount,
                -- Mark achieved if target crossed
                achieved_at     = CASE
                                    WHEN achieved_at IS NULL
                                     AND (current_amount + @amount) >= target_amount
                                    THEN SYSUTCDATETIME()
                                    ELSE achieved_at
                                  END,
                status          = CASE
                                    WHEN status = 'active'
                                     AND (current_amount + @amount) >= target_amount
                                    THEN 'achieved'
                                    ELSE status
                                  END,
                updated_at      = SYSUTCDATETIME()
            WHERE goal_id = @goal_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


-- =============================================================================
-- 10. usp_account_recalc_balance
--     Recomputes and persists current_balance from raw transactions.
--     Called internally after every insert/delete/update.
-- =============================================================================
CREATE PROCEDURE dbo.usp_account_recalc_balance
    @account_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.account
    SET
        current_balance = ISNULL((
            SELECT SUM(
                CASE txn_type
                    WHEN 'credit' THEN  amount
                    WHEN 'debit'  THEN -amount
                    ELSE 0
                END
            )
            FROM dbo.[transaction]
            WHERE account_id = @account_id
              AND is_deleted  = 0
              AND is_excluded = 0
        ), 0),
        updated_at = SYSUTCDATETIME()
    WHERE account_id = @account_id;
END;
GO

PRINT 'procedures.sql — all stored procedures created successfully.';
GO