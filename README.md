The section is dedicated to KUMA SIEM and some automation scripts, that can help with routine tasks:
1) Backup_cron.sh - before start you need to make some preparation:
   a) create a dedicated user for API interection
   b) grant an appropriate API rights to create and restore from the backup
   c) generate API token and copy it to the script
   d) specify KUMA SIEM IP-address and API port (7223 is in use by default)
2) Make the script executable: chmod +x backup_cron.sh
3) Run the script: ./backup_cron.sh
4) The backup will be created in /opt/kaspersky/kuma/backup folder once and then every Friday at 4pm.
