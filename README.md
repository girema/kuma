### Scripts Overview

| File | Description |
|---|---|
| **WEC_GPO_policy.ps1** | PowerShell script for configuring Group Policy settings for Windows Event Collector (WEC). |
| **backup_kuma_cron.sh** | Automates KUMA backup creation via API and sets up a cron job to run backups weekly (default: Friday 4 PM). |
| **clear_collector_logs.sh** | Generates a list of collector log directories and deletes log files inside them. Useful for cleanup. |
| **collect_logs.sh** | Collects logs from KUMA components (collector, correlator, storage, agent, core) plus system info, then archives them for troubleshooting. |
| **fortinet_log_generator** | Test utility to generate Fortinet-style logs for integration or simulation purposes. |
| **kuma_health_check.sh** | Checks the status and health of KUMA services to verify availability and functionality. |
| **kuma_installation.sh** | Automates installation of KUMA, including environment preparation and dependency setup. |
| **mssql_log_audit_app.sql** | SQL script for auditing MSSQL application-level events and logging them for SIEM ingestion. |
| **mssql_log_audit_file.sql** | SQL script for auditing file-related activities in MSSQL. |
| **mssql_log_audit_sql_cleanup.sql** | Cleans up SQL audit objects created during testing or configuration. |
| **mssql_log_audit_sql_output.sql** | Script to output MSSQL audit logs into a file or table for SIEM integration. |
| **os_preparation_kuma_new.sh** | Prepares a fresh operating system for KUMA installation (updates, dependencies, kernel/system settings). |
| **os_preparation_kuma_old.sh** | Prepares an older operating system version for KUMA installation, ensuring compatibility. |
| **restore_kuma.sh** | Restores KUMA from a backup (data and configuration recovery). |
| **rsyslog_auditd_kuma.conf** | Rsyslog configuration for forwarding Linux auditd logs to KUMA. |
| **ubuntu_disk_change_size.sh** | Expands disk partitions and filesystems on Ubuntu to increase storage size. |
| **xml_forwarder_http.py** | Python script to forward XML logs to a remote HTTP endpoint (e.g., KUMA). |
| **xml_forwarder_http_guide.md** | Documentation on how to configure and use the `xml_forwarder_http.py` script. |
