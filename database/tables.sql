/* ============================================================
   tables.sql
   FinTrackPro — Personal Finance & Budget Tracker
   Purpose: Create ALL tables only. No views, functions,
            procedures, triggers, or seed data.
   Target: SQL Server 2025 / Azure SQL Database
   Depends on: 001_initial_schema.sql (database + SchemaMigrations
               must already exist)
   ============================================================
   DEPENDENCY ORDER (strict — do not reorder):
   1. Users
   2. Accounts          -> Users
   3. Categories        -> Users (nullable, supports system defaults)
   4. Transactions       -> Users, Accounts, Categories
   5. Budgets            -> Users, Categories
   6. Goals               -> Users
   7. GoalContributions    -> Goals
   8. ImportSessions        -> Users
   9. ImportRecords          -> ImportSessions, Transactions (nullable)
   10. Notifications          -> Users
   11. AuditLogs               -> Users (nullable)

   No circular dependencies exist in this model:
   - Categories does not reference Transactions.
   - Budgets/Goals do not reference Transactions (progress is
     calculated at query time from Transactions/GoalContributions,
     never stored as a running total — see NFR-4.3).
   ============================================================ */

/* ============================================================
   1. Users
   Root entity. No foreign key dependencies.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Users' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Users
    (
        userId          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        fullName        NVARCHAR(150)    NOT NULL,
        email           NVARCHAR(255)    NOT NULL,
        passwordHash    NVARCHAR(255)    NOT NULL,
        currencyCode    CHAR(3)          NOT NULL DEFAULT 'INR',
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Users PRIMARY KEY (userId),
        CONSTRAINT UQ_Users_Email UNIQUE (email),
        CONSTRAINT CK_Users_CurrencyCode CHECK (LEN(currencyCode) = 3)
    );
    PRINT 'Created table dbo.Users.';
END
GO

/* ============================================================
   2. Accounts
   A bank account or card a user tracks. Depends on Users.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Accounts' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Accounts
    (
        accountId       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NOT NULL,
        accountName     NVARCHAR(100)    NOT NULL,
        accountType     NVARCHAR(20)     NOT NULL,
        lastFourDigits  CHAR(4)          NULL,
        currentBalance  DECIMAL(18,2)    NOT NULL DEFAULT 0,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Accounts PRIMARY KEY (accountId),
        CONSTRAINT FK_Accounts_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT CK_Accounts_AccountType CHECK (accountType IN ('bank','credit_card','cash','wallet')),
        CONSTRAINT CK_Accounts_LastFourDigits CHECK (lastFourDigits IS NULL OR LEN(lastFourDigits) = 4)
    );
    PRINT 'Created table dbo.Accounts.';
END
GO

/* ============================================================
   3. Categories
   userId is NULLABLE: NULL = system-default category (seeded
   once, shared by all users), NOT NULL = a user's custom category.
   Depends on Users.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Categories' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Categories
    (
        categoryId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NULL,
        categoryName    NVARCHAR(80)     NOT NULL,
        categoryType    NVARCHAR(10)     NOT NULL,
        icon            NVARCHAR(50)     NULL,
        colorHex        CHAR(7)          NULL,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Categories PRIMARY KEY (categoryId),
        CONSTRAINT FK_Categories_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT CK_Categories_CategoryType CHECK (categoryType IN ('income','expense')),
        CONSTRAINT CK_Categories_ColorHex CHECK (colorHex IS NULL OR colorHex LIKE '#%'),
        CONSTRAINT UQ_Categories_UserName UNIQUE (userId, categoryName)
    );
    PRINT 'Created table dbo.Categories.';
END
GO

/* ============================================================
   4. Transactions
   The core financial record. Depends on Users, Accounts, Categories.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Transactions' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Transactions
    (
        transactionId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NOT NULL,
        accountId       UNIQUEIDENTIFIER NULL,
        categoryId      UNIQUEIDENTIFIER NULL,
        merchantName    NVARCHAR(150)    NOT NULL,
        amount          DECIMAL(18,2)    NOT NULL,
        transactionType NVARCHAR(10)     NOT NULL,
        transactionDate DATE             NOT NULL,
        notes           NVARCHAR(500)    NULL,
        source          NVARCHAR(20)     NOT NULL DEFAULT 'manual',
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Transactions PRIMARY KEY (transactionId),
        CONSTRAINT FK_Transactions_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT FK_Transactions_Accounts FOREIGN KEY (accountId)
            REFERENCES dbo.Accounts (accountId),
        CONSTRAINT FK_Transactions_Categories FOREIGN KEY (categoryId)
            REFERENCES dbo.Categories (categoryId),
        CONSTRAINT CK_Transactions_TransactionType CHECK (transactionType IN ('income','expense')),
        CONSTRAINT CK_Transactions_Amount CHECK (amount > 0),
        CONSTRAINT CK_Transactions_Source CHECK (source IN ('manual','import'))
    );
    PRINT 'Created table dbo.Transactions.';
END
GO

/* ============================================================
   5. Budgets
   A spending limit per category per period. Depends on Users,
   Categories. Does NOT reference Transactions — spent amount is
   calculated at query time (see Database-Design.md / NFR-4.3).
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Budgets' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Budgets
    (
        budgetId        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NOT NULL,
        categoryId      UNIQUEIDENTIFIER NOT NULL,
        limitAmount     DECIMAL(18,2)    NOT NULL,
        periodType      NVARCHAR(10)     NOT NULL DEFAULT 'monthly',
        periodStart     DATE             NOT NULL,
        alertThreshold  DECIMAL(5,2)     NOT NULL DEFAULT 80.00,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Budgets PRIMARY KEY (budgetId),
        CONSTRAINT FK_Budgets_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT FK_Budgets_Categories FOREIGN KEY (categoryId)
            REFERENCES dbo.Categories (categoryId),
        CONSTRAINT CK_Budgets_LimitAmount CHECK (limitAmount > 0),
        CONSTRAINT CK_Budgets_PeriodType CHECK (periodType IN ('weekly','monthly','yearly')),
        CONSTRAINT CK_Budgets_AlertThreshold CHECK (alertThreshold > 0 AND alertThreshold <= 100),
        CONSTRAINT UQ_Budgets_UserCategoryPeriod UNIQUE (userId, categoryId, periodStart)
    );
    PRINT 'Created table dbo.Budgets.';
END
GO

/* ============================================================
   6. Goals
   A savings target. Depends on Users only.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Goals' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Goals
    (
        goalId          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NOT NULL,
        goalName        NVARCHAR(150)    NOT NULL,
        targetAmount    DECIMAL(18,2)    NOT NULL,
        targetDate      DATE             NULL,
        status          NVARCHAR(10)     NOT NULL DEFAULT 'active',
        achievedAt      DATETIME2(3)     NULL,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Goals PRIMARY KEY (goalId),
        CONSTRAINT FK_Goals_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT CK_Goals_TargetAmount CHECK (targetAmount > 0),
        CONSTRAINT CK_Goals_Status CHECK (status IN ('active','achieved','archived'))
    );
    PRINT 'Created table dbo.Goals.';
END
GO

/* ============================================================
   7. GoalContributions
   A logged contribution toward a goal. Depends on Goals.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'GoalContributions' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.GoalContributions
    (
        contributionId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        goalId          UNIQUEIDENTIFIER NOT NULL,
        amount          DECIMAL(18,2)    NOT NULL,
        contributionDate DATE            NOT NULL,
        notes           NVARCHAR(300)    NULL,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_GoalContributions PRIMARY KEY (contributionId),
        CONSTRAINT FK_GoalContributions_Goals FOREIGN KEY (goalId)
            REFERENCES dbo.Goals (goalId),
        CONSTRAINT CK_GoalContributions_Amount CHECK (amount > 0)
    );
    PRINT 'Created table dbo.GoalContributions.';
END
GO

/* ============================================================
   8. ImportSessions
   One row per bank-statement upload event. Depends on Users.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportSessions' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.ImportSessions
    (
        importSessionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NOT NULL,
        accountId       UNIQUEIDENTIFIER NULL,
        fileName        NVARCHAR(255)    NOT NULL,
        fileFormat      NVARCHAR(10)     NOT NULL DEFAULT 'csv',
        status          NVARCHAR(20)     NOT NULL DEFAULT 'pending',
        totalRows       INT              NOT NULL DEFAULT 0,
        importedRows    INT              NOT NULL DEFAULT 0,
        duplicateRows   INT              NOT NULL DEFAULT 0,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_ImportSessions PRIMARY KEY (importSessionId),
        CONSTRAINT FK_ImportSessions_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT FK_ImportSessions_Accounts FOREIGN KEY (accountId)
            REFERENCES dbo.Accounts (accountId),
        CONSTRAINT CK_ImportSessions_FileFormat CHECK (fileFormat IN ('csv','ofx','pdf')),
        CONSTRAINT CK_ImportSessions_Status CHECK (status IN ('pending','processing','completed','failed'))
    );
    PRINT 'Created table dbo.ImportSessions.';
END
GO

/* ============================================================
   9. ImportRecords
   One row per parsed line from an import file. transactionId is
   NULLABLE: NULL until the row is confirmed and converted into a
   real Transaction (supports the "preview before confirming"
   flow from FR-4.4, and duplicate flagging from FR-4.6).
   Depends on ImportSessions, Transactions.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ImportRecords' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.ImportRecords
    (
        importRecordId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        importSessionId UNIQUEIDENTIFIER NOT NULL,
        transactionId   UNIQUEIDENTIFIER NULL,
        rawMerchantText NVARCHAR(255)    NOT NULL,
        rawAmountText   NVARCHAR(50)     NOT NULL,
        rawDateText     NVARCHAR(50)     NOT NULL,
        parsedAmount    DECIMAL(18,2)    NULL,
        parsedDate      DATE             NULL,
        suggestedCategoryId UNIQUEIDENTIFIER NULL,
        isDuplicate     BIT              NOT NULL DEFAULT 0,
        isConfirmed     BIT              NOT NULL DEFAULT 0,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_ImportRecords PRIMARY KEY (importRecordId),
        CONSTRAINT FK_ImportRecords_ImportSessions FOREIGN KEY (importSessionId)
            REFERENCES dbo.ImportSessions (importSessionId),
        CONSTRAINT FK_ImportRecords_Transactions FOREIGN KEY (transactionId)
            REFERENCES dbo.Transactions (transactionId),
        CONSTRAINT FK_ImportRecords_Categories FOREIGN KEY (suggestedCategoryId)
            REFERENCES dbo.Categories (categoryId)
    );
    PRINT 'Created table dbo.ImportRecords.';
END
GO

/* ============================================================
   10. Notifications
   In-app alerts (budget warnings, goal achieved, import done).
   Depends on Users.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Notifications
    (
        notificationId  UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NOT NULL,
        notificationType NVARCHAR(30)    NOT NULL,
        title           NVARCHAR(150)    NOT NULL,
        message         NVARCHAR(500)    NOT NULL,
        isRead          BIT              NOT NULL DEFAULT 0,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_Notifications PRIMARY KEY (notificationId),
        CONSTRAINT FK_Notifications_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId),
        CONSTRAINT CK_Notifications_Type CHECK (notificationType IN ('budget_warning','budget_exceeded','goal_achieved','import_completed','system'))
    );
    PRINT 'Created table dbo.Notifications.';
END
GO

/* ============================================================
   11. AuditLogs
   Tracks who-did-what across the system. userId is NULLABLE to
   allow system-generated events with no associated user.
   Depends on Users.
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'AuditLogs' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.AuditLogs
    (
        auditLogId      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        userId          UNIQUEIDENTIFIER NULL,
        action          NVARCHAR(100)    NOT NULL,
        entityName      NVARCHAR(100)    NOT NULL,
        entityId        UNIQUEIDENTIFIER NULL,
        details         NVARCHAR(1000)   NULL,
        ipAddress       NVARCHAR(45)     NULL,
        createdAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        updatedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
        isDeleted       BIT              NOT NULL DEFAULT 0,
        deletedAt       DATETIME2(3)     NULL,

        CONSTRAINT PK_AuditLogs PRIMARY KEY (auditLogId),
        CONSTRAINT FK_AuditLogs_Users FOREIGN KEY (userId)
            REFERENCES dbo.Users (userId)
    );
    PRINT 'Created table dbo.AuditLogs.';
END
GO

/* ============================================================
   RECORD THIS MIGRATION
   ============================================================ */
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrations WHERE migrationName = N'002_tables')
BEGIN
    INSERT INTO dbo.SchemaMigrations (migrationName) VALUES (N'002_tables');
    PRINT 'Recorded migration: 002_tables';
END
GO

/* ============================================================
   END OF tables.sql

   VALIDATION CHECKLIST:
   ✓ 11 tables created, zero views/functions/procedures/triggers/seed data
   ✓ All table names plural + PascalCase (Users, Accounts, Categories,
     Transactions, Budgets, Goals, GoalContributions, ImportSessions,
     ImportRecords, Notifications, AuditLogs)
   ✓ All column names camelCase
   ✓ Every table has: UNIQUEIDENTIFIER PK with NEWID() default,
     createdAt, updatedAt, isDeleted, deletedAt
     (AuditLogs and ImportRecords also carry these for consistency,
     even though audit/import rows are rarely soft-deleted in practice)
   ✓ Every FK references a table created EARLIER in this same file —
     verified line by line against the dependency order at the top
   ✓ No table references a table that appears later in the file
   ✓ No circular dependencies: Categories does not reference
     Transactions; Budgets/Goals do not reference Transactions
   ✓ CHECK constraints added: amount > 0 (Transactions, Budgets,
     Goals, GoalContributions), enum-style CHECKs for type/status
     columns, colorHex format, lastFourDigits length, currencyCode length
   ✓ DEFAULT constraints added: NEWID() on all PKs, SYSUTCDATETIME()
     on all createdAt/updatedAt, 0 on all isDeleted, sensible defaults
     on status/type/periodType/source columns
   ✓ UNIQUE constraints added: Users.email, Categories(userId,
     categoryName), Budgets(userId, categoryId, periodStart)
   ✓ All object names verified to exist before being referenced —
     no forward references anywhere in this file
   ============================================================ */