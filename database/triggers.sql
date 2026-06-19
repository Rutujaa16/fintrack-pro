-- =============================================================================
-- FinTrack Pro — Triggers
-- Engine : Microsoft SQL Server 2022
-- =============================================================================
-- Triggers are kept lightweight — no business logic, only data integrity
-- and audit patterns that CANNOT be enforced by constraints alone.
-- =============================================================================

USE FinTrackPro;
GO

IF OBJECT_ID('dbo.trg_transaction_after_insert_update', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_transaction_after_insert_update;
IF OBJECT_ID('dbo.trg_transaction_after_delete',        'TR') IS NOT NULL DROP TRIGGER dbo.trg_transaction_after_delete;
IF OBJECT_ID('dbo.trg_goal_contribution_after_insert',  'TR') IS NOT NULL DROP TRIGGER dbo.trg_goal_contribution_after_insert;
IF OBJECT_ID('dbo.trg_app_user_updated_at',             'TR') IS NOT NULL DROP TRIGGER dbo.trg_app_user_updated_at;
IF OBJECT_ID('dbo.trg_category_no_delete_system',       'TR') IS NOT NULL DROP TRIGGER dbo.trg_category_no_delete_system;
GO


-- =============================================================================
-- 1. trg_transaction_after_insert_update
--    After any transaction is inserted or updated:
--      a) Stamp updated_at
--      b) Sync account.current_balance
-- =============================================================================
CREATE TRIGGER dbo.trg_transaction_after_insert_update
ON dbo.[transaction]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- a) Stamp updated_at on rows touched by UPDATE (INSERT already has DEFAULT)
    IF EXISTS (SELECT 1 FROM DELETED)   -- DELETED only populated on UPDATE
    BEGIN
        UPDATE dbo.[transaction]
        SET updated_at = SYSUTCDATETIME()
        WHERE transaction_id IN (SELECT transaction_id FROM INSERTED);
    END;

    -- b) Sync balances for all affected accounts
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
            WHERE account_id = a.account_id
              AND is_deleted  = 0
              AND is_excluded = 0
        ), 0),
        updated_at = SYSUTCDATETIME()
    FROM dbo.account a
    WHERE a.account_id IN (SELECT DISTINCT account_id FROM INSERTED);
END;
GO


-- =============================================================================
-- 2. trg_transaction_after_delete
--    Physical DELETE of transactions (should be rare — prefer soft-delete).
--    Still syncs account balance if a hard delete somehow occurs.
-- =============================================================================
CREATE TRIGGER dbo.trg_transaction_after_delete
ON dbo.[transaction]
AFTER DELETE
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
            WHERE account_id = a.account_id
              AND is_deleted  = 0
              AND is_excluded = 0
        ), 0),
        updated_at = SYSUTCDATETIME()
    FROM dbo.account a
    WHERE a.account_id IN (SELECT DISTINCT account_id FROM DELETED);
END;
GO


-- =============================================================================
-- 3. trg_goal_contribution_after_insert
--    After a contribution is added:
--      - Ensures goal.current_amount never exceeds target_amount (clamp)
--      - Sets achieved_at / status automatically
-- =============================================================================
CREATE TRIGGER dbo.trg_goal_contribution_after_insert
ON dbo.goal_contribution
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Update each goal touched by this batch
    UPDATE dbo.goal
    SET
        current_amount  = CASE
                            WHEN current_amount > target_amount THEN target_amount
                            ELSE current_amount
                          END,
        achieved_at     = CASE
                            WHEN achieved_at IS NULL
                             AND current_amount >= target_amount
                            THEN SYSUTCDATETIME()
                            ELSE achieved_at
                          END,
        status          = CASE
                            WHEN status = 'active'
                             AND current_amount >= target_amount
                            THEN 'achieved'
                            ELSE status
                          END,
        updated_at      = SYSUTCDATETIME()
    WHERE goal_id IN (SELECT DISTINCT goal_id FROM INSERTED);
END;
GO


-- =============================================================================
-- 4. trg_app_user_updated_at
--    Keeps updated_at current on every user row change.
--    (Simulates ON UPDATE behaviour absent from SQL Server.)
-- =============================================================================
CREATE TRIGGER dbo.trg_app_user_updated_at
ON dbo.app_user
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.app_user
    SET updated_at = SYSUTCDATETIME()
    WHERE user_id IN (SELECT user_id FROM INSERTED);
END;
GO


-- =============================================================================
-- 5. trg_category_no_delete_system
--    Prevents hard-DELETE of system categories — they can only be soft-deleted.
--    Soft-delete (is_deleted = 1) is allowed via UPDATE and passes through.
-- =============================================================================
CREATE TRIGGER dbo.trg_category_no_delete_system
ON dbo.category
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Reject hard-delete of system categories
    IF EXISTS (SELECT 1 FROM DELETED WHERE is_system = 1)
    BEGIN
        THROW 50050,
              'System categories cannot be hard-deleted. Set is_deleted = 1 instead.',
              1;
    END;

    -- Allow hard-delete for user-owned categories
    DELETE FROM dbo.category
    WHERE category_id IN (SELECT category_id FROM DELETED WHERE is_system = 0);
END;
GO

PRINT 'triggers.sql — all triggers created successfully.';
GO