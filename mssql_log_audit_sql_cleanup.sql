----------------------------------------------------------------------
-- 1. CLEANUP: safely disable and drop old audit specs and objects
----------------------------------------------------------------------
DECLARE @AuditName               sysname = N'Audit_ToFile';
DECLARE @SrvSpecName             sysname = N'Audit_ServerSecurity';
DECLARE @DbName                  sysname = N'AuditTestDB';
DECLARE @DbSpecName              sysname = N'Audit_DatabaseSecurity';
DECLARE @AuditPath               nvarchar(260) = N'C:\SQL_Audit\';
DECLARE @AuditWildcard           nvarchar(400) = @AuditPath + N'*';

PRINT '--- 1. Cleanup DB Audit Specification ---';
IF DB_ID(@DbName) IS NOT NULL
BEGIN
    DECLARE @sql nvarchar(max);

    -- Disable and drop DB Audit Spec if it exists
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @DbName)
    BEGIN
        SET @sql = N'USE ' + QUOTENAME(@DbName) + N';
            IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N''' + @DbSpecName + N''')
            BEGIN
                ALTER DATABASE AUDIT SPECIFICATION ' + QUOTENAME(@DbSpecName) + N' WITH (STATE = OFF);
                DROP DATABASE AUDIT SPECIFICATION ' + QUOTENAME(@DbSpecName) + N';
            END';
        EXEC (@sql);
    END
END
GO

PRINT '--- 2. Cleanup Server Audit Specification ---';
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = N'Audit_ServerSecurity')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION Audit_ServerSecurity WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION Audit_ServerSecurity;
END
GO

PRINT '--- 3. Cleanup Server Audit ---';
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'Audit_ToFile')
BEGIN
    ALTER SERVER AUDIT Audit_ToFile WITH (STATE = OFF);
    DROP SERVER AUDIT Audit_ToFile;
END
GO

PRINT '--- 4. Drop database AuditTestDB ---';
IF DB_ID(N'AuditTestDB') IS NOT NULL
BEGIN
    ALTER DATABASE [AuditTestDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [AuditTestDB];
    PRINT 'Database AuditTestDB has been dropped.';
END
ELSE
BEGIN
    PRINT 'Database AuditTestDB does not exist. Nothing to drop.';
END
GO
