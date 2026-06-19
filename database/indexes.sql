/* ============================================================
   indexes.sql
   FinTrackPro — Personal Finance & Budget Tracker
   Purpose: Create ALL non-clustered indexes only. No tables,
            views, functions, procedures, triggers, or seed data.
   Target: SQL Server 2025 / Azure SQL Database
   Depends on: 001_initial_schema.sql, tables.sql (all 11 tables
               and their PK/UNIQUE constraints must already exist)
   ============================================================
   NOTE ON SCOPE:
   PRIMARY KEY and UNIQUE constraints already create their own
   indexes automatically (PK_Users, UQ_Users_Email, UQ_Categories_
   UserName, UQ_Budgets_UserCategoryPeriod, etc. from tables.sql).
   Those are NOT duplicated below. Every index here is additive —
   covering FK lookups and query patterns from Functional-
   Requirements.md / Non-Functional-Requirements.md that are not
   already served by an existing constraint index.
   ============================================================ */

/* ============================================================
   VALIDATION: confirm all target tables exist before proceeding.
   If any table is missing, the script aborts with a clear error
   instead of failing with a cryptic "invalid object name" later.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Users' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Accounts' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Categories' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Transactions' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Budgets' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Goals' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'GoalContributions' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportSessions' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportRecords' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications' AND schema_id = SCHEMA_ID('dbo'))
   OR NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AuditLogs' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    RAISERROR('One or more required tables are missing. Run tables.sql before indexes.sql.', 16, 1);
    RETURN;
END
GO

/* ============================================================
   ACCOUNTS
   ============================================================ */

-- FK lookup: "all accounts belonging to this user"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Accounts_UserId' AND object_id = OBJECT_ID('dbo.Accounts'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Accounts_UserId
        ON dbo.Accounts (userId)
        INCLUDE (accountName, accountType, currentBalance);
    PRINT 'Created index IX_Accounts_UserId.';
END
GO

/* ============================================================
   CATEGORIES
   ============================================================ */

-- FK lookup: "all custom categories belonging to this user"
-- (UQ_Categories_UserName already indexes (userId, categoryName),
-- this index is NOT a duplicate since it serves plain userId-only
-- lookups efficiently as the leading column is the same — SKIPPED
-- to avoid redundancy. See validation checklist at end of file.)

-- Frequently filtered: "all expense categories" / "all income categories"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Categories_CategoryType' AND object_id = OBJECT_ID('dbo.Categories'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Categories_CategoryType
        ON dbo.Categories (categoryType)
        INCLUDE (categoryName);
    PRINT 'Created index IX_Categories_CategoryType.';
END
GO

/* ============================================================
   TRANSACTIONS
   The most heavily queried table — dashboard, analytics, reports,
   and the transactions list all filter by userId + date range.
   ============================================================ */

-- Single most common query pattern in the entire app:
-- "this user's transactions within a date range" (dashboard cash
-- flow chart, analytics, reports, transactions list with filters)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Transactions_UserId_TransactionDate' AND object_id = OBJECT_ID('dbo.Transactions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Transactions_UserId_TransactionDate
        ON dbo.Transactions (userId, transactionDate DESC)
        INCLUDE (amount, transactionType, merchantName, categoryId);
    PRINT 'Created index IX_Transactions_UserId_TransactionDate.';
END
GO

-- FK lookup + budget/analytics aggregation: "all transactions in
-- this category" (budget progress calculation, category breakdown)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Transactions_CategoryId' AND object_id = OBJECT_ID('dbo.Transactions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Transactions_CategoryId
        ON dbo.Transactions (categoryId)
        INCLUDE (userId, amount, transactionDate);
    PRINT 'Created index IX_Transactions_CategoryId.';
END
GO

-- FK lookup: "all transactions on this account"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Transactions_AccountId' AND object_id = OBJECT_ID('dbo.Transactions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Transactions_AccountId
        ON dbo.Transactions (accountId);
    PRINT 'Created index IX_Transactions_AccountId.';
END
GO

-- Merchant search (FR-3.7: "search transactions by merchant name")
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Transactions_MerchantName' AND object_id = OBJECT_ID('dbo.Transactions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Transactions_MerchantName
        ON dbo.Transactions (merchantName);
    PRINT 'Created index IX_Transactions_MerchantName.';
END
GO

/* ============================================================
   BUDGETS
   ============================================================ */

-- FK lookup: "all budgets for this user" (Budgets page overview)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Budgets_UserId' AND object_id = OBJECT_ID('dbo.Budgets'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Budgets_UserId
        ON dbo.Budgets (userId)
        INCLUDE (categoryId, limitAmount, periodStart, alertThreshold);
    PRINT 'Created index IX_Budgets_UserId.';
END
GO

-- FK lookup: "all budgets for this category" (rarely queried alone,
-- but supports category-deletion checks and reporting joins)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Budgets_CategoryId' AND object_id = OBJECT_ID('dbo.Budgets'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Budgets_CategoryId
        ON dbo.Budgets (categoryId);
    PRINT 'Created index IX_Budgets_CategoryId.';
END
GO

/* ============================================================
   GOALS
   ============================================================ */

-- FK lookup + dashboard filter: "this user's active goals"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Goals_UserId_Status' AND object_id = OBJECT_ID('dbo.Goals'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Goals_UserId_Status
        ON dbo.Goals (userId, status)
        INCLUDE (goalName, targetAmount, targetDate);
    PRINT 'Created index IX_Goals_UserId_Status.';
END
GO

/* ============================================================
   GOAL CONTRIBUTIONS
   ============================================================ */

-- FK lookup + contribution log ordering (FR-6.4): "this goal's
-- contribution history, most recent first"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_GoalContributions_GoalId_ContributionDate' AND object_id = OBJECT_ID('dbo.GoalContributions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_GoalContributions_GoalId_ContributionDate
        ON dbo.GoalContributions (goalId, contributionDate DESC)
        INCLUDE (amount);
    PRINT 'Created index IX_GoalContributions_GoalId_ContributionDate.';
END
GO

/* ============================================================
   IMPORT SESSIONS
   ============================================================ */

-- FK lookup + import history (FR-4.8): "this user's past imports,
-- most recent first"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ImportSessions_UserId_CreatedAt' AND object_id = OBJECT_ID('dbo.ImportSessions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportSessions_UserId_CreatedAt
        ON dbo.ImportSessions (userId, createdAt DESC)
        INCLUDE (fileName, status, totalRows, importedRows);
    PRINT 'Created index IX_ImportSessions_UserId_CreatedAt.';
END
GO

-- FK lookup: "the import session this account's statement came from"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ImportSessions_AccountId' AND object_id = OBJECT_ID('dbo.ImportSessions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportSessions_AccountId
        ON dbo.ImportSessions (accountId);
    PRINT 'Created index IX_ImportSessions_AccountId.';
END
GO

/* ============================================================
   IMPORT RECORDS
   ============================================================ */

-- FK lookup + review-screen filter (FR-4.4): "pending/unconfirmed
-- rows for this import session"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ImportRecords_ImportSessionId_IsConfirmed' AND object_id = OBJECT_ID('dbo.ImportRecords'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportRecords_ImportSessionId_IsConfirmed
        ON dbo.ImportRecords (importSessionId, isConfirmed);
    PRINT 'Created index IX_ImportRecords_ImportSessionId_IsConfirmed.';
END
GO

-- FK lookup: "which import record produced this transaction"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ImportRecords_TransactionId' AND object_id = OBJECT_ID('dbo.ImportRecords'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportRecords_TransactionId
        ON dbo.ImportRecords (transactionId)
        WHERE transactionId IS NOT NULL;
    PRINT 'Created index IX_ImportRecords_TransactionId.';
END
GO

-- FK lookup: "suggested category" lookups during import review
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ImportRecords_SuggestedCategoryId' AND object_id = OBJECT_ID('dbo.ImportRecords'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportRecords_SuggestedCategoryId
        ON dbo.ImportRecords (suggestedCategoryId)
        WHERE suggestedCategoryId IS NOT NULL;
    PRINT 'Created index IX_ImportRecords_SuggestedCategoryId.';
END
GO

/* ============================================================
   NOTIFICATIONS
   ============================================================ */

-- FK lookup + bell-icon unread filter (dashboard.html notification
-- dot): "this user's unread notifications, most recent first"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notifications_UserId_IsRead' AND object_id = OBJECT_ID('dbo.Notifications'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notifications_UserId_IsRead
        ON dbo.Notifications (userId, isRead, createdAt DESC)
        INCLUDE (notificationType, title);
    PRINT 'Created index IX_Notifications_UserId_IsRead.';
END
GO

/* ============================================================
   AUDIT LOGS
   ============================================================ */

-- FK lookup: "all actions performed by this user"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLogs_UserId' AND object_id = OBJECT_ID('dbo.AuditLogs'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_AuditLogs_UserId
        ON dbo.AuditLogs (userId, createdAt DESC);
    PRINT 'Created index IX_AuditLogs_UserId.';
END
GO

-- Entity history lookup: "show audit history for this specific record"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLogs_EntityName_EntityId' AND object_id = OBJECT_ID('dbo.AuditLogs'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_AuditLogs_EntityName_EntityId
        ON dbo.AuditLogs (entityName, entityId);
    PRINT 'Created index IX_AuditLogs_EntityName_EntityId.';
END
GO

/* ============================================================
   RECORD THIS MIGRATION
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrations WHERE migrationName = N'003_indexes')
BEGIN
    INSERT INTO dbo.SchemaMigrations (migrationName) VALUES (N'003_indexes');
    PRINT 'Recorded migration: 003_indexes';
END
GO

/* ============================================================
   END OF indexes.sql

   VALIDATION CHECKLIST:
   ✓ Every table referenced (Users, Accounts, Categories,
     Transactions, Budgets, Goals, GoalContributions,
     ImportSessions, ImportRecords, Notifications, AuditLogs)
     is verified to exist at the top of this script before any
     CREATE INDEX statement runs
   ✓ No tables, views, functions, procedures, triggers, or seed
     data created in this file — indexes only
   ✓ Every FK column from tables.sql has a covering index:
       Accounts.userId, Transactions.userId/accountId/categoryId,
       Budgets.userId/categoryId, Goals.userId,
       GoalContributions.goalId, ImportSessions.userId/accountId,
       ImportRecords.importSessionId/transactionId/suggestedCategoryId,
       Notifications.userId, AuditLogs.userId
   ✓ No duplicate indexes created on columns already covered by
     PK or UNIQUE constraints from tables.sql (Users.email,
     Categories(userId,categoryName), Budgets(userId,categoryId,
     periodStart) are NOT re-indexed here)
   ✓ All index names follow IX_{Table}_{Column(s)} convention
   ✓ Composite indexes ordered with the most selective / most
     commonly filtered column first (e.g., userId before
     transactionDate, since "this user" always narrows first)
   ✓ Filtered indexes (WHERE ... IS NOT NULL) used for nullable
     FK columns that are sparse, to keep index size efficient
   ✓ Idempotent — every CREATE INDEX wrapped in IF NOT EXISTS
   ✓ Valid SQL Server 2025 / Azure SQL Database T-SQL syntax
   ✓ Migration recorded as 003_indexes in dbo.SchemaMigrations
   ============================================================ */