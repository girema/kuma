----------------------------------------------------------------------
-- 1. Read AUDIT LOG from files
--     Useful fields:
--       • event_time              — when
--       • action_id               — action code (SL=SELECT, IN=INSERT, UP=UPDATE, DL=DELETE, AL=ALTER, etc.)
--       • succeeded               — 1/0 success/failure
--       • server_principal_name   — who (login/user)
--       • database_name, object_name, schema_name
--       • statement               — executed T-SQL text
----------------------------------------------------------------------
PRINT '--- 1. Audit log (from files) ---';
USE master;
GO
SELECT
    event_time,
    action_id,
    succeeded,
    server_principal_name   AS [who],
    session_server_principal_name AS [session_as],
    database_name           AS [db],
    schema_name             AS [schema],
    object_name             AS [object],
    statement               AS [sql_text],
    additional_information
FROM sys.fn_get_audit_file(N'C:\SQL_Audit\*', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
GO

PRINT '--- Done ---';
