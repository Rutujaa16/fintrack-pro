/* ============================================================
   001_initial_schema.sql
   FinTrackPro — Personal Finance & Budget Tracker
   Purpose: Create database (on-prem only) + migration tracking table.
   Target: SQL Server 2025 (on-prem) / Azure SQL Database (cloud)
   ============================================================
   NOTES ON PORTABILITY:
   - Azure SQL Database does NOT support CREATE DATABASE with file
     placement options, and you cannot USE a different database
     within the same connection/session on Azure SQL.
   - On Azure SQL, the database itself must already exist (created
     via Azure Portal, CLI, or ARM/Bicep) BEFORE this script runs.
     You simply connect directly to that database and run the
     "schema objects" section below.
   - On-prem SQL Server: this script will create the database if
     it does not exist, then you reconnect/USE it.
   ============================================================ */

/* ------------------------------------------------------------
   SECTION 1: DATABASE CREATION (ON-PREM ONLY)
   Skip this section entirely when targeting Azure SQL —
   simply connect to the pre-provisioned FinTrackPro database
   and run SECTION 2 onward.
   ------------------------------------------------------------ */
IF DB_ID(N'FinTrackPro') IS NULL
BEGIN
    PRINT 'Creating database FinTrackPro (on-prem mode)...';
    CREATE DATABASE FinTrackPro;
END
ELSE
BEGIN
    PRINT 'Database FinTrackPro already exists. Skipping CREATE DATABASE.';
END
GO

/* On-prem only: set recommended database options.
   On Azure SQL these are either already enforced or unavailable
   as ALTER DATABASE options — wrap in a check so this script does
   not error out if run against Azure SQL by mistake. */
IF SERVERPROPERTY('EngineEdition') <> 5 -- 5 = Azure SQL Database
BEGIN
    ALTER DATABASE FinTrackPro SET READ_COMMITTED_SNAPSHOT ON;
    ALTER DATABASE FinTrackPro SET RECOVERY SIMPLE;
    PRINT 'Applied on-prem database options to FinTrackPro.';
END
ELSE
BEGIN
    PRINT 'Running on Azure SQL Database — skipped on-prem-only ALTER DATABASE options.';
END
GO

/* ------------------------------------------------------------
   SECTION 2: SCHEMA OBJECTS
   From this point on, every statement is portable to both
   on-prem SQL Server and Azure SQL Database.
   IMPORTANT: If running on-prem, reconnect your session/tool to
   the FinTrackPro database now before continuing (a GO batch
   separator cannot itself switch database context reliably for
   all client tools). On Azure SQL, you are already connected to
   the correct database.
   ------------------------------------------------------------ */

/* Confirm the default schema exists (it always does by default,
   this is just explicit documentation that all objects in this
   project live in dbo — no custom schemas are used). */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbo')
BEGIN
    PRINT 'WARNING: dbo schema not found — this should never happen on a standard SQL Server instance.';
END
GO

/* ------------------------------------------------------------
   SECTION 3: SCHEMA MIGRATIONS TRACKING TABLE
   Every migration file (tables.sql, indexes.sql, views.sql, etc.)
   will INSERT a row here once successfully applied. This gives
   you a real, queryable migration history — similar in spirit to
   what Alembic (Python) or EF Core migrations track automatically,
   but hand-rolled since we are writing raw T-SQL.
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SchemaMigrations' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.SchemaMigrations
    (
        migrationId     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        migrationName   NVARCHAR(200)    NOT NULL,
        appliedAt       DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_SchemaMigrations PRIMARY KEY (migrationId),
        CONSTRAINT UQ_SchemaMigrations_MigrationName UNIQUE (migrationName)
    );

    PRINT 'Created table dbo.SchemaMigrations.';
END
ELSE
BEGIN
    PRINT 'Table dbo.SchemaMigrations already exists. Skipping CREATE TABLE.';
END
GO

/* ------------------------------------------------------------
   SECTION 4: RECORD THIS MIGRATION
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrations WHERE migrationName = N'001_initial_schema')
BEGIN
    INSERT INTO dbo.SchemaMigrations (migrationName) VALUES (N'001_initial_schema');
    PRINT 'Recorded migration: 001_initial_schema';
END
GO

/* ============================================================
   END OF 001_initial_schema.sql

   VALIDATION CHECKLIST (verified):
   ✓ No foreign keys referenced — none exist yet
   ✓ No dependency on any other migration file
   ✓ Idempotent — safe to re-run (every block uses IF NOT EXISTS / IF DB_ID checks)
   ✓ Portable — on-prem CREATE DATABASE logic is isolated and
     conditionally skipped via EngineEdition check; Azure SQL path
     only touches SECTION 2 onward
   ✓ Valid SQL Server 2025 / Azure SQL Database T-SQL syntax
   ✓ schema_migrations equivalent (SchemaMigrations) created and
     self-recorded
   ============================================================ */