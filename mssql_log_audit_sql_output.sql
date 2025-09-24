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

/*======================================================================
  SQL Server Audit action_id Cheat Sheet
  Use this reference when reading results from sys.fn_get_audit_file
=======================================================================

--- DML (Data Manipulation Language) ---
SL  = SELECT
IN  = INSERT
UP  = UPDATE
DL  = DELETE

--- DDL (Data Definition Language) ---
CR  = CREATE object
DR  = DROP object
AL  = ALTER object
SC  = CREATE SCHEMA
DS  = DROP SCHEMA
SO  = CREATE/DROP/ALTER Server Object

--- Security & Permissions ---
LG  = LOGIN attempt (success/failure depending on group)
PW  = LOGIN password change
PR  = CREATE/ALTER/DROP USER (principal change)
RO  = Role membership changes (ADD/DROP MEMBER)
GR  = GRANT permission
DV  = DENY permission
RV  = REVOKE permission

--- Audit & Server ---
AD  = Audit configuration change
AP  = Application role password change
AU  = Audit action (record itself)
SV  = Server permission change
DB  = Database permission change

=======================================================================*/
