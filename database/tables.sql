-- =============================================================================
-- FinTrack Pro — Database Schema
-- Engine  : Microsoft SQL Server 2022
-- Schema  : dbo (default)
-- Created : 2026-06-19
-- =============================================================================
-- Conventions:
--   PK  → UNIQUEIDENTIFIER (NEWID()) — safe for distributed inserts / Azure
--   Timestamps → DATETIME2(0)  (second precision, no fractional noise)
--   Soft-delete → is_deleted BIT + deleted_at DATETIME2
--   Money → DECIMAL(18,2)  — never FLOAT for currency
--   All FK columns end in _id
-- =============================================================================

USE FinTrackPro;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. UTILITY — drop all tables in dependency order (dev convenience)
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.notification',           'U') IS NOT NULL DROP TABLE dbo.notification;
IF OBJECT_ID('dbo.goal_contribution',      'U') IS NOT NULL DROP TABLE dbo.goal_contribution;
IF OBJECT_ID('dbo.goal',                   'U') IS NOT NULL DROP TABLE dbo.goal;
IF OBJECT_ID('dbo.import_row',             'U') IS NOT NULL DROP TABLE dbo.import_row;
IF OBJECT_ID('dbo.import_session',         'U') IS NOT NULL DROP TABLE dbo.import_session;
IF OBJECT_ID('dbo.transaction',            'U') IS NOT NULL DROP TABLE dbo.[transaction];
IF OBJECT_ID('dbo.budget_category',        'U') IS NOT NULL DROP TABLE dbo.budget_category;
IF OBJECT_ID('dbo.budget',                 'U') IS NOT NULL DROP TABLE dbo.budget;
IF OBJECT_ID('dbo.category',               'U') IS NOT NULL DROP TABLE dbo.category;
IF OBJECT_ID('dbo.account',                'U') IS NOT NULL DROP TABLE dbo.account;
IF OBJECT_ID('dbo.user_preference',        'U') IS NOT NULL DROP TABLE dbo.user_preference;
IF OBJECT_ID('dbo.app_user',               'U') IS NOT NULL DROP TABLE dbo.app_user;
GO


-- =============================================================================
-- 1. app_user
--    Core identity table. Avoid "user" — reserved word in SQL Server.
-- =============================================================================
CREATE TABLE dbo.app_user (
    user_id             UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    email               NVARCHAR(255)       NOT NULL,
    email_verified_at   DATETIME2(0)                    NULL,
    full_name           NVARCHAR(150)       NOT NULL,
    avatar_url          NVARCHAR(500)                   NULL,

    -- auth
    password_hash       NVARCHAR(255)       NOT NULL,   -- bcrypt / argon2
    password_changed_at DATETIME2(0)                    NULL,
    two_fa_enabled      BIT                 NOT NULL    DEFAULT 0,
    two_fa_secret       NVARCHAR(64)                    NULL,   -- TOTP seed (encrypted at rest)

    -- plan
    plan                NVARCHAR(20)        NOT NULL    DEFAULT 'free'
                            CONSTRAINT chk_user_plan CHECK (plan IN ('free','premium','enterprise')),

    -- status
    is_active           BIT                 NOT NULL    DEFAULT 1,
    is_deleted          BIT                 NOT NULL    DEFAULT 0,
    last_login_at       DATETIME2(0)                    NULL,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    deleted_at          DATETIME2(0)                    NULL,

    CONSTRAINT pk_app_user PRIMARY KEY (user_id),
    CONSTRAINT uq_app_user_email UNIQUE (email)
);
GO

-- index for login lookup
CREATE NONCLUSTERED INDEX ix_app_user_email
    ON dbo.app_user (email)
    WHERE is_deleted = 0;
GO


-- =============================================================================
-- 2. user_preference
--    One row per user. Stores all personalisation settings as columns
--    (avoids EAV anti-pattern for a bounded settings set).
-- =============================================================================
CREATE TABLE dbo.user_preference (
    preference_id       UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,

    -- display
    currency_code       NCHAR(3)            NOT NULL    DEFAULT 'INR',
    date_format         NVARCHAR(20)        NOT NULL    DEFAULT 'DD MMM YYYY',
    number_format       NVARCHAR(10)        NOT NULL    DEFAULT 'IN',   -- 'IN' | 'US'
    language            NVARCHAR(10)        NOT NULL    DEFAULT 'en',
    theme               NVARCHAR(10)        NOT NULL    DEFAULT 'dark'
                            CONSTRAINT chk_pref_theme CHECK (theme IN ('dark','light','system')),
    accent_color        NCHAR(7)            NOT NULL    DEFAULT '#C9A661',  -- hex

    -- budget
    budget_cycle_day    TINYINT             NOT NULL    DEFAULT 1            -- 1–28
                            CONSTRAINT chk_pref_cycle_day CHECK (budget_cycle_day BETWEEN 1 AND 28),
    carry_forward       BIT                 NOT NULL    DEFAULT 0,

    -- privacy
    hide_on_launch      BIT                 NOT NULL    DEFAULT 0,
    app_lock_enabled    BIT                 NOT NULL    DEFAULT 0,
    auto_categorize     BIT                 NOT NULL    DEFAULT 1,
    analytics_opt_in    BIT                 NOT NULL    DEFAULT 1,

    -- notifications (bitmask approach kept simple via individual columns)
    notif_email         BIT                 NOT NULL    DEFAULT 1,
    notif_push          BIT                 NOT NULL    DEFAULT 1,
    notif_sms           BIT                 NOT NULL    DEFAULT 0,
    notif_budget_80     BIT                 NOT NULL    DEFAULT 1,
    notif_budget_over   BIT                 NOT NULL    DEFAULT 1,
    notif_large_txn     BIT                 NOT NULL    DEFAULT 1,
    notif_import_done   BIT                 NOT NULL    DEFAULT 1,
    notif_goal_milestone BIT                NOT NULL    DEFAULT 1,
    notif_weekly_digest BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_user_preference   PRIMARY KEY (preference_id),
    CONSTRAINT uq_user_preference   UNIQUE (user_id),
    CONSTRAINT fk_pref_user         FOREIGN KEY (user_id) REFERENCES dbo.app_user (user_id)
);
GO


-- =============================================================================
-- 3. account
--    A bank / credit card / cash account belonging to a user.
-- =============================================================================
CREATE TABLE dbo.account (
    account_id          UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,

    name                NVARCHAR(100)       NOT NULL,           -- "HDFC Savings"
    institution         NVARCHAR(100)                   NULL,   -- "HDFC Bank"
    account_type        NVARCHAR(20)        NOT NULL
                            CONSTRAINT chk_account_type
                            CHECK (account_type IN ('savings','current','credit','wallet','cash','investment','other')),
    masked_number       NCHAR(4)                        NULL,   -- last 4 digits
    currency_code       NCHAR(3)            NOT NULL    DEFAULT 'INR',
    current_balance     DECIMAL(18,2)       NOT NULL    DEFAULT 0.00,
    color               NCHAR(7)                        NULL,   -- hex for UI card
    icon                NVARCHAR(50)                    NULL,   -- lucide icon name
    is_default          BIT                 NOT NULL    DEFAULT 0,
    is_active           BIT                 NOT NULL    DEFAULT 1,
    is_deleted          BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    deleted_at          DATETIME2(0)                    NULL,

    CONSTRAINT pk_account       PRIMARY KEY (account_id),
    CONSTRAINT fk_account_user  FOREIGN KEY (user_id) REFERENCES dbo.app_user (user_id)
);
GO

CREATE NONCLUSTERED INDEX ix_account_user
    ON dbo.account (user_id)
    WHERE is_deleted = 0;
GO


-- =============================================================================
-- 4. category
--    User-defined + system defaults. parent_category_id enables sub-categories.
-- =============================================================================
CREATE TABLE dbo.category (
    category_id         UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER                NULL,   -- NULL = system/global category
    parent_category_id  UNIQUEIDENTIFIER                NULL,

    name                NVARCHAR(80)        NOT NULL,
    icon                NVARCHAR(50)                    NULL,   -- lucide icon name
    color               NCHAR(7)                        NULL,   -- hex
    category_type       NVARCHAR(10)        NOT NULL
                            CONSTRAINT chk_category_type
                            CHECK (category_type IN ('income','expense','transfer')),
    is_system           BIT                 NOT NULL    DEFAULT 0,  -- shipped defaults
    is_deleted          BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    deleted_at          DATETIME2(0)                    NULL,

    CONSTRAINT pk_category          PRIMARY KEY (category_id),
    CONSTRAINT fk_category_user     FOREIGN KEY (user_id)            REFERENCES dbo.app_user (user_id),
    CONSTRAINT fk_category_parent   FOREIGN KEY (parent_category_id) REFERENCES dbo.category (category_id)
);
GO

CREATE NONCLUSTERED INDEX ix_category_user
    ON dbo.category (user_id)
    WHERE is_deleted = 0;
GO


-- =============================================================================
-- 5. transaction
--    Heart of the application. Every debit / credit / transfer lives here.
--    "transaction" is reserved in some contexts — wrap in brackets when needed.
-- =============================================================================
CREATE TABLE dbo.[transaction] (
    transaction_id      UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,
    account_id          UNIQUEIDENTIFIER    NOT NULL,
    category_id         UNIQUEIDENTIFIER                NULL,
    import_session_id   UNIQUEIDENTIFIER                NULL,   -- set when imported

    -- core fields
    txn_date            DATE                NOT NULL,
    description         NVARCHAR(500)       NOT NULL,
    original_description NVARCHAR(500)                  NULL,   -- raw merchant string from import
    amount              DECIMAL(18,2)       NOT NULL,           -- always positive
    txn_type            NVARCHAR(10)        NOT NULL
                            CONSTRAINT chk_txn_type
                            CHECK (txn_type IN ('debit','credit','transfer')),
    currency_code       NCHAR(3)            NOT NULL    DEFAULT 'INR',

    -- enrichment
    merchant_name       NVARCHAR(150)                   NULL,
    reference_id        NVARCHAR(100)                   NULL,   -- bank ref / cheque no
    notes               NVARCHAR(1000)                  NULL,   -- user note
    tags                NVARCHAR(500)                   NULL,   -- comma-separated

    -- transfer link
    linked_transaction_id UNIQUEIDENTIFIER              NULL,   -- the other leg of a transfer

    -- flags
    is_recurring        BIT                 NOT NULL    DEFAULT 0,
    is_verified         BIT                 NOT NULL    DEFAULT 0,
    is_excluded         BIT                 NOT NULL    DEFAULT 0,  -- exclude from budgets/analytics
    is_deleted          BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    deleted_at          DATETIME2(0)                    NULL,

    CONSTRAINT pk_transaction           PRIMARY KEY (transaction_id),
    CONSTRAINT fk_txn_user              FOREIGN KEY (user_id)             REFERENCES dbo.app_user (user_id),
    CONSTRAINT fk_txn_account           FOREIGN KEY (account_id)          REFERENCES dbo.account (account_id),
    CONSTRAINT fk_txn_category          FOREIGN KEY (category_id)         REFERENCES dbo.category (category_id),
    CONSTRAINT fk_txn_import            FOREIGN KEY (import_session_id)   REFERENCES dbo.import_session (import_session_id),
    CONSTRAINT fk_txn_linked            FOREIGN KEY (linked_transaction_id) REFERENCES dbo.[transaction] (transaction_id)
);
GO

-- queries: user's transactions sorted by date (most common)
CREATE NONCLUSTERED INDEX ix_txn_user_date
    ON dbo.[transaction] (user_id, txn_date DESC)
    INCLUDE (account_id, category_id, amount, txn_type, description)
    WHERE is_deleted = 0;
GO

-- queries: filter by account
CREATE NONCLUSTERED INDEX ix_txn_account
    ON dbo.[transaction] (account_id, txn_date DESC)
    WHERE is_deleted = 0;
GO

-- queries: filter by category (budget / analytics)
CREATE NONCLUSTERED INDEX ix_txn_category
    ON dbo.[transaction] (category_id, txn_date DESC)
    WHERE is_deleted = 0 AND category_id IS NOT NULL;
GO


-- =============================================================================
-- 6. import_session
--    One row per file upload. Tracks the full lifecycle of a statement import.
-- =============================================================================
CREATE TABLE dbo.import_session (
    import_session_id   UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,
    account_id          UNIQUEIDENTIFIER    NOT NULL,

    -- file metadata
    original_filename   NVARCHAR(260)       NOT NULL,
    file_type           NVARCHAR(10)        NOT NULL
                            CONSTRAINT chk_import_file_type
                            CHECK (file_type IN ('csv','xlsx','xls')),
    file_size_bytes     BIGINT                          NULL,
    storage_path        NVARCHAR(500)                   NULL,   -- Azure Blob path

    -- column mapping (JSON — e.g. {"date":"Txn Date","description":"Narration","debit":"Withdrawal Amt."})
    column_mapping      NVARCHAR(MAX)                   NULL
                            CONSTRAINT chk_import_mapping_json CHECK (ISJSON(column_mapping) = 1),

    -- counters
    total_rows          INT                 NOT NULL    DEFAULT 0,
    valid_rows          INT                 NOT NULL    DEFAULT 0,
    imported_rows       INT                 NOT NULL    DEFAULT 0,
    skipped_rows        INT                 NOT NULL    DEFAULT 0,
    error_rows          INT                 NOT NULL    DEFAULT 0,

    -- lifecycle
    status              NVARCHAR(20)        NOT NULL    DEFAULT 'pending'
                            CONSTRAINT chk_import_status
                            CHECK (status IN ('pending','mapping','validating','importing','completed','failed','cancelled')),
    error_message       NVARCHAR(MAX)                   NULL,
    completed_at        DATETIME2(0)                    NULL,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_import_session        PRIMARY KEY (import_session_id),
    CONSTRAINT fk_import_user           FOREIGN KEY (user_id)    REFERENCES dbo.app_user (user_id),
    CONSTRAINT fk_import_account        FOREIGN KEY (account_id) REFERENCES dbo.account (account_id)
);
GO

CREATE NONCLUSTERED INDEX ix_import_user
    ON dbo.import_session (user_id, created_at DESC);
GO


-- =============================================================================
-- 7. import_row
--    One row per line from the uploaded file. Preserves raw data + validation
--    status — essential for the "Review flagged rows" feature.
-- =============================================================================
CREATE TABLE dbo.import_row (
    import_row_id       UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    import_session_id   UNIQUEIDENTIFIER    NOT NULL,
    transaction_id      UNIQUEIDENTIFIER                NULL,   -- set after successful import

    row_number          INT                 NOT NULL,           -- line in source file
    raw_data            NVARCHAR(MAX)       NOT NULL,           -- original CSV row as JSON
    mapped_date         DATE                            NULL,
    mapped_description  NVARCHAR(500)                   NULL,
    mapped_amount       DECIMAL(18,2)                   NULL,
    mapped_type         NVARCHAR(10)                    NULL,   -- 'debit' | 'credit'

    status              NVARCHAR(20)        NOT NULL    DEFAULT 'pending'
                            CONSTRAINT chk_row_status
                            CHECK (status IN ('pending','valid','imported','skipped','error')),
    validation_errors   NVARCHAR(MAX)                   NULL,   -- JSON array of error strings
    is_duplicate        BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_import_row        PRIMARY KEY (import_row_id),
    CONSTRAINT fk_row_session       FOREIGN KEY (import_session_id) REFERENCES dbo.import_session (import_session_id),
    CONSTRAINT fk_row_transaction   FOREIGN KEY (transaction_id)    REFERENCES dbo.[transaction] (transaction_id)
);
GO

CREATE NONCLUSTERED INDEX ix_import_row_session
    ON dbo.import_row (import_session_id, status);
GO


-- =============================================================================
-- 8. budget
--    Monthly (or custom-period) spending plan at the user level.
-- =============================================================================
CREATE TABLE dbo.budget (
    budget_id           UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,

    name                NVARCHAR(100)       NOT NULL    DEFAULT 'Monthly Budget',
    period_type         NVARCHAR(10)        NOT NULL    DEFAULT 'monthly'
                            CONSTRAINT chk_budget_period
                            CHECK (period_type IN ('monthly','weekly','custom')),
    period_start        DATE                NOT NULL,
    period_end          DATE                NOT NULL,
    total_limit         DECIMAL(18,2)       NOT NULL,
    currency_code       NCHAR(3)            NOT NULL    DEFAULT 'INR',
    is_active           BIT                 NOT NULL    DEFAULT 1,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_budget        PRIMARY KEY (budget_id),
    CONSTRAINT fk_budget_user   FOREIGN KEY (user_id) REFERENCES dbo.app_user (user_id),
    CONSTRAINT chk_budget_dates CHECK (period_end > period_start)
);
GO

CREATE NONCLUSTERED INDEX ix_budget_user
    ON dbo.budget (user_id, period_start DESC)
    WHERE is_active = 1;
GO


-- =============================================================================
-- 9. budget_category
--    Per-category spending limits within a budget period.
-- =============================================================================
CREATE TABLE dbo.budget_category (
    budget_category_id  UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    budget_id           UNIQUEIDENTIFIER    NOT NULL,
    category_id         UNIQUEIDENTIFIER    NOT NULL,

    amount_limit        DECIMAL(18,2)       NOT NULL,
    alert_at_percent    TINYINT             NOT NULL    DEFAULT 80   -- notify at X%
                            CONSTRAINT chk_alert_pct CHECK (alert_at_percent BETWEEN 1 AND 100),

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_budget_category           PRIMARY KEY (budget_category_id),
    CONSTRAINT fk_budcat_budget             FOREIGN KEY (budget_id)   REFERENCES dbo.budget (budget_id),
    CONSTRAINT fk_budcat_category           FOREIGN KEY (category_id) REFERENCES dbo.category (category_id),
    CONSTRAINT uq_budcat_budget_category    UNIQUE (budget_id, category_id)
);
GO


-- =============================================================================
-- 10. goal
--     Savings target with deadline and progress tracking.
-- =============================================================================
CREATE TABLE dbo.goal (
    goal_id             UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,

    name                NVARCHAR(100)       NOT NULL,
    description         NVARCHAR(500)                   NULL,
    icon                NVARCHAR(50)                    NULL,
    color               NCHAR(7)                        NULL,

    target_amount       DECIMAL(18,2)       NOT NULL,
    current_amount      DECIMAL(18,2)       NOT NULL    DEFAULT 0.00,
    currency_code       NCHAR(3)            NOT NULL    DEFAULT 'INR',
    monthly_contribution DECIMAL(18,2)                  NULL,   -- planned auto-transfer

    target_date         DATE                            NULL,
    achieved_at         DATETIME2(0)                    NULL,

    status              NVARCHAR(20)        NOT NULL    DEFAULT 'active'
                            CONSTRAINT chk_goal_status
                            CHECK (status IN ('active','achieved','paused','cancelled')),
    is_deleted          BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),
    deleted_at          DATETIME2(0)                    NULL,

    CONSTRAINT pk_goal      PRIMARY KEY (goal_id),
    CONSTRAINT fk_goal_user FOREIGN KEY (user_id) REFERENCES dbo.app_user (user_id),
    CONSTRAINT chk_goal_amounts CHECK (target_amount > 0 AND current_amount >= 0)
);
GO

CREATE NONCLUSTERED INDEX ix_goal_user
    ON dbo.goal (user_id)
    WHERE is_deleted = 0;
GO


-- =============================================================================
-- 11. goal_contribution
--     Tracks each deposit (manual or auto) toward a goal.
-- =============================================================================
CREATE TABLE dbo.goal_contribution (
    contribution_id     UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    goal_id             UNIQUEIDENTIFIER    NOT NULL,
    user_id             UNIQUEIDENTIFIER    NOT NULL,

    amount              DECIMAL(18,2)       NOT NULL,
    contribution_type   NVARCHAR(10)        NOT NULL    DEFAULT 'manual'
                            CONSTRAINT chk_contrib_type
                            CHECK (contribution_type IN ('manual','auto','withdrawal')),
    notes               NVARCHAR(300)                   NULL,
    contribution_date   DATE                NOT NULL    DEFAULT CAST(SYSUTCDATETIME() AS DATE),

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_goal_contribution     PRIMARY KEY (contribution_id),
    CONSTRAINT fk_contrib_goal          FOREIGN KEY (goal_id)  REFERENCES dbo.goal (goal_id),
    CONSTRAINT fk_contrib_user          FOREIGN KEY (user_id)  REFERENCES dbo.app_user (user_id),
    CONSTRAINT chk_contrib_amount       CHECK (amount <> 0)
);
GO

CREATE NONCLUSTERED INDEX ix_contrib_goal
    ON dbo.goal_contribution (goal_id, contribution_date DESC);
GO


-- =============================================================================
-- 12. notification
--     In-app notification log.
-- =============================================================================
CREATE TABLE dbo.notification (
    notification_id     UNIQUEIDENTIFIER    NOT NULL    DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,

    title               NVARCHAR(150)       NOT NULL,
    body                NVARCHAR(500)       NOT NULL,
    notif_type          NVARCHAR(30)        NOT NULL
                            CONSTRAINT chk_notif_type
                            CHECK (notif_type IN (
                                'budget_alert','budget_exceeded','large_transaction',
                                'import_complete','import_error',
                                'goal_milestone','goal_achieved',
                                'weekly_digest','system'
                            )),
    related_entity_type NVARCHAR(30)                    NULL,   -- 'budget','goal','import_session'
    related_entity_id   UNIQUEIDENTIFIER                NULL,
    is_read             BIT                 NOT NULL    DEFAULT 0,
    read_at             DATETIME2(0)                    NULL,
    is_dismissed        BIT                 NOT NULL    DEFAULT 0,

    created_at          DATETIME2(0)        NOT NULL    DEFAULT SYSUTCDATETIME(),

    CONSTRAINT pk_notification      PRIMARY KEY (notification_id),
    CONSTRAINT fk_notif_user        FOREIGN KEY (user_id) REFERENCES dbo.app_user (user_id)
);
GO

CREATE NONCLUSTERED INDEX ix_notif_user_unread
    ON dbo.notification (user_id, created_at DESC)
    WHERE is_read = 0 AND is_dismissed = 0;
GO

PRINT 'tables.sql — all tables and indexes created successfully.';
GO