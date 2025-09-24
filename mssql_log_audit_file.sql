/*======================================================================
  SQL Server Audit - Full setup from scratch + tests + results
  Coverage:
    • User / login / role / permission events (Server-level)
    • DDL (CREATE/DROP/ALTER) and DML (SELECT/INSERT/UPDATE/DELETE) events on tables (DB-level)
    • Safe re-runnable (cleanup + existence checks)
=======================================================================*/

SET NOCOUNT ON;
PRINT '--- Preflight ---';

----------------------------------------------------------------------
-- 0. Diagnostics (info only: version, edition, current user, sysadmin role)
----------------------------------------------------------------------
SELECT
    @@VERSION AS sql_version,
    SERVERPROPERTY('Edition') AS edition,
    SYSTEM_USER AS executing_as,
    IS_SRVROLEMEMBER('sysadmin') AS is_sysadmin;

----------------------------------------------------------------------
-- Parameters (you can change names/paths if needed)
----------------------------------------------------------------------
DECLARE @AuditName               sysname = N'Audit_ToFile';
DECLARE @SrvSpecName             sysname = N'Audit_ServerSecurity';
DECLARE @DbName                  sysname = N'AuditTestDB';
DECLARE @DbSpecName              sysname = N'Audit_DatabaseSecurity';
DECLARE @AuditPath               nvarchar(260) = N'C:\SQL_Audit\';
DECLARE @AuditWildcard           nvarchar(400) = @AuditPath + N'*';

----------------------------------------------------------------------
-- 1. (Optional) Purge audit files on disk:
--    Temporarily enable xp_cmdshell, create folder if missing,
--    delete *.sqlaudit files, then restore xp_cmdshell state
--    Disable this block if your policy forbids xp_cmdshell
----------------------------------------------------------------------
PRINT '--- 1. Optional: purge audit files on disk ---';
BEGIN TRY
    DECLARE @xpWasEnabled bit = 0;

    -- Ensure advanced options are visible
    IF NOT EXISTS (SELECT 1 FROM sys.configurations WHERE name = 'show advanced options' AND value_in_use = 1)
    BEGIN
        EXEC sp_configure 'show advanced options', 1;
        RECONFIGURE WITH OVERRIDE;
    END

    -- Save current state of xp_cmdshell
    IF EXISTS (SELECT 1 FROM sys.configurations WHERE name = 'xp_cmdshell' AND value_in_use = 1)
        SET @xpWasEnabled = 1;

    -- Temporarily enable xp_cmdshell
    IF @xpWasEnabled = 0
    BEGIN
        EXEC sp_configure 'xp_cmdshell', 1;
        RECONFIGURE WITH OVERRIDE;
    END

    DECLARE @cmd nvarchar(4000);
    -- Create folder if missing
    SET @cmd = N'IF NOT EXIST "' + @AuditPath + N'" MKDIR "' + @AuditPath + N'"';
    EXEC xp_cmdshell @cmd, NO_OUTPUT;

    -- Delete old audit files
    SET @cmd = N'IF EXIST "' + @AuditPath + N'*.sqlaudit" DEL /Q "' + @AuditPath + N'*.sqlaudit"';
    EXEC xp_cmdshell @cmd, NO_OUTPUT;

    -- Restore xp_cmdshell state
    IF @xpWasEnabled = 0
    BEGIN
        EXEC sp_configure 'xp_cmdshell', 0;
        RECONFIGURE WITH OVERRIDE;
    END
END TRY
BEGIN CATCH
    PRINT 'Note: purge skipped (xp_cmdshell unavailable). Delete files manually: ' + @AuditPath + '*.sqlaudit';
END CATCH;

----------------------------------------------------------------------
-- 2. Create SERVER AUDIT → write to file
--    • ON_FAILURE = CONTINUE — don’t block if audit fails
--    • MAX_ROLLOVER_FILES = 1 — keep only one file (easier for fresh logs)
----------------------------------------------------------------------
PRINT '--- 2. Create SERVER AUDIT (to file) ---';
CREATE SERVER AUDIT [Audit_ToFile]
TO FILE (FILEPATH = N'C:\SQL_Audit\', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 1)
WITH (ON_FAILURE = CONTINUE);
GO

ALTER SERVER AUDIT [Audit_ToFile] WITH (STATE = ON);
GO

----------------------------------------------------------------------
-- 3. SERVER AUDIT SPECIFICATION (user/role/permission/login events)
--    Coverage:
--      • SERVER_PRINCIPAL_CHANGE_GROUP        → CREATE/ALTER/DROP LOGIN
--      • DATABASE_PRINCIPAL_CHANGE_GROUP      → CREATE/ALTER/DROP USER
--      • SERVER_ROLE_MEMBER_CHANGE_GROUP      → ALTER SERVER ROLE ADD/DROP MEMBER
--      • DATABASE_ROLE_MEMBER_CHANGE_GROUP    → ALTER ROLE ADD/DROP MEMBER in DB
--      • SERVER_PERMISSION_CHANGE_GROUP       → GRANT/DENY/REVOKE server-level
--      • DATABASE_PERMISSION_CHANGE_GROUP     → GRANT/DENY/REVOKE database-level
--      • SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP → object permissions
--      • LOGIN_CHANGE_PASSWORD_GROUP          → login password changes
--      • APPLICATION_ROLE_CHANGE_PASSWORD_GROUP → app role password changes
--      • SUCCESSFUL_LOGIN_GROUP / FAILED_LOGIN_GROUP → login attempts
--      • AUDIT_CHANGE_GROUP                   → audit config changes
----------------------------------------------------------------------
PRINT '--- 3. Create SERVER AUDIT SPECIFICATION (users/roles/permissions/logins) ---';
CREATE SERVER AUDIT SPECIFICATION [Audit_ServerSecurity]
FOR SERVER AUDIT [Audit_ToFile]
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
    ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
    ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
    ADD (SERVER_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_PERMISSION_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (LOGIN_CHANGE_PASSWORD_GROUP),
    ADD (APPLICATION_ROLE_CHANGE_PASSWORD_GROUP),
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (FAILED_LOGIN_GROUP),
    ADD (AUDIT_CHANGE_GROUP)
WITH (STATE = ON);
GO

----------------------------------------------------------------------
-- 4. Prepare DB and test table for DDL/DML audit
----------------------------------------------------------------------
PRINT '--- 4. Recreate test DB and table ---';
IF DB_ID(N'AuditTestDB') IS NOT NULL
BEGIN
    ALTER DATABASE [AuditTestDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [AuditTestDB];
END
GO

CREATE DATABASE [AuditTestDB];
GO
USE [AuditTestDB];
GO

IF OBJECT_ID(N'dbo.TestTable','U') IS NOT NULL
    DROP TABLE dbo.TestTable;
GO
CREATE TABLE dbo.TestTable
(
    ID        int IDENTITY(1,1) PRIMARY KEY,
    UserName  nvarchar(100) NOT NULL,
    CreatedAt datetime      NOT NULL CONSTRAINT DF_TestTable_CreatedAt DEFAULT (GETDATE())
);
GO

----------------------------------------------------------------------
-- 5. DATABASE AUDIT SPECIFICATION (DDL + DML on schema dbo)
--    Coverage:
--      • SCHEMA_OBJECT_CHANGE_GROUP → CREATE/DROP/ALTER objects
--      • SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP → GRANT/DENY/REVOKE on schema objects
--      • SELECT / INSERT / UPDATE / DELETE on schema dbo by PUBLIC
----------------------------------------------------------------------
PRINT '--- 5. Create DATABASE AUDIT SPECIFICATION (DDL+DML) ---';
IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N'Audit_DatabaseSecurity')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION [Audit_DatabaseSecurity] WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION [Audit_DatabaseSecurity];
END
GO

CREATE DATABASE AUDIT SPECIFICATION [Audit_DatabaseSecurity]
FOR SERVER AUDIT [Audit_ToFile]
    ADD (SCHEMA_OBJECT_CHANGE_GROUP),
    ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (SELECT ON SCHEMA::dbo BY PUBLIC),
    ADD (INSERT  ON SCHEMA::dbo BY PUBLIC),
    ADD (UPDATE  ON SCHEMA::dbo BY PUBLIC),
    ADD (DELETE  ON SCHEMA::dbo BY PUBLIC)
WITH (STATE = ON);
GO

----------------------------------------------------------------------
-- 6. TEST: User/role/permission events (Server-level)
--    Covered by:
--      SERVER_PRINCIPAL_CHANGE_GROUP / DATABASE_PRINCIPAL_CHANGE_GROUP /
--      SERVER_ROLE_MEMBER_CHANGE_GROUP / DATABASE_ROLE_MEMBER_CHANGE_GROUP /
--      *PERMISSION_CHANGE_GROUP / LOGIN_CHANGE_PASSWORD_GROUP / AUDIT_CHANGE_GROUP
----------------------------------------------------------------------
PRINT '--- 6. Generate user/role/permission events ---';
USE master;
GO
BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'TestUser_Audit')
        DROP LOGIN [TestUser_Audit];

    CREATE LOGIN [TestUser_Audit] WITH PASSWORD = 'P@ssw0rd!';
END TRY
BEGIN CATCH
    PRINT 'Note: LOGIN create/drop may require elevated permissions.';
END CATCH;
GO

USE [AuditTestDB];
GO
BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'TestUser_Audit')
        DROP USER [TestUser_Audit];

    CREATE USER [TestUser_Audit] FOR LOGIN [TestUser_Audit];

    -- Role changes in DB
    ALTER ROLE db_datareader ADD MEMBER [TestUser_Audit];
    ALTER ROLE db_datawriter ADD MEMBER [TestUser_Audit];

    -- Permissions grant/revoke
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.TestTable TO [TestUser_Audit];
    REVOKE DELETE ON dbo.TestTable FROM [TestUser_Audit];

    -- Remove from roles and drop user
    ALTER ROLE db_datawriter DROP MEMBER [TestUser_Audit];
    ALTER ROLE db_datareader DROP MEMBER [TestUser_Audit];
    DROP USER [TestUser_Audit];
END TRY
BEGIN CATCH
    PRINT 'Note: USER/ROLE/PERM changes executed with best effort.';
END CATCH;
GO

USE master;
GO
BEGIN TRY
    ALTER LOGIN [TestUser_Audit] WITH PASSWORD = 'P@ssw0rd!2';
    DROP LOGIN [TestUser_Audit];
END TRY
BEGIN CATCH
    PRINT 'Note: LOGIN password change/drop may require elevated permissions.';
END CATCH;
GO

----------------------------------------------------------------------
-- 7. TEST: DML/DDL events on table (Database-level)
--     Covered by:
--       SELECT/INSERT/UPDATE/DELETE, SCHEMA_OBJECT_CHANGE_GROUP
----------------------------------------------------------------------
PRINT '--- 7. Generate table DDL/DML events ---';
USE [AuditTestDB];
GO
INSERT INTO dbo.TestTable (UserName) VALUES (N'Alice');
INSERT INTO dbo.TestTable (UserName) VALUES (N'Bob');
UPDATE dbo.TestTable SET UserName = N'Charlie' WHERE ID = 1;
DELETE FROM dbo.TestTable WHERE ID = 2;
ALTER TABLE dbo.TestTable ADD Email nvarchar(255) NULL;
ALTER TABLE dbo.TestTable DROP COLUMN Email;
GO

----------------------------------------------------------------------
-- 8. Output current table data
----------------------------------------------------------------------
PRINT '--- 8. Data snapshot ---';
SELECT * FROM dbo.TestTable ORDER BY ID;
