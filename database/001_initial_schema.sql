-- =============================================================================
-- FinTrack Pro — Migration: 001_initial_schema
-- Engine : Microsoft SQL Server 2022
-- Run    : Once, on a fresh database
-- =============================================================================
-- This migration bootstraps the entire schema by calling the individual
-- schema files in dependency order. Run each block separately in SSMS
-- or use the setup.ps1 script which executes them in sequence via sqlcmd.
--
-- Order:
--   1. Create database
--   2. tables.sql
--   3. functions.sql   (views depend on functions)
--   4. views.sql
--   5. procedures.sql  (procedures reference views & functions)
--   6. triggers.sql
--   7. seed-data.sql   (optional — dev/staging only)
-- =============================================================================

-- Step 1: Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'FinTrackPro')
BEGIN
    CREATE DATABASE FinTrackPro
        COLLATE SQL_Latin1_General_CP1_CI_AS;   -- case-insensitive, accent-sensitive
    PRINT 'Database FinTrackPro created.';
END
ELSE
    PRINT 'Database FinTrackPro already exists — skipping create.';
GO

USE FinTrackPro;
GO

-- Record this migration in a tracking table (idempotent)
IF OBJECT_ID('dbo.schema_migrations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.schema_migrations (
        migration_id    INT             IDENTITY(1,1)   PRIMARY KEY,
        version         NVARCHAR(50)    NOT NULL        UNIQUE,
        description     NVARCHAR(200)   NOT NULL,
        applied_at      DATETIME2(0)    NOT NULL        DEFAULT SYSUTCDATETIME(),
        applied_by      NVARCHAR(100)   NOT NULL        DEFAULT SUSER_SNAME()
    );
    PRINT 'schema_migrations table created.';
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.schema_migrations WHERE version = '001')
BEGIN
    INSERT INTO dbo.schema_migrations (version, description)
    VALUES ('001', 'Initial schema — tables, views, procedures, functions, triggers');
    PRINT 'Migration 001 recorded.';
END
ELSE
    PRINT 'Migration 001 already applied — skipping.';
GO

PRINT '=========================================================';
PRINT ' FinTrackPro schema migration 001 complete.';
PRINT ' Next steps:';
PRINT '   sqlcmd -S . -d FinTrackPro -i schema/tables.sql';
PRINT '   sqlcmd -S . -d FinTrackPro -i schema/functions.sql';
PRINT '   sqlcmd -S . -d FinTrackPro -i schema/views.sql';
PRINT '   sqlcmd -S . -d FinTrackPro -i schema/procedures.sql';
PRINT '   sqlcmd -S . -d FinTrackPro -i schema/triggers.sql';
PRINT '   sqlcmd -S . -d FinTrackPro -i seed-data/seed-data.sql';
PRINT '=========================================================';
GO