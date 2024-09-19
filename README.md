## KUMA SIEM Automation Scripts

This section is dedicated to KUMA SIEM and provides automation scripts that can assist with routine tasks. Below are the steps to set up and use the backup script:

### 1. Modify `backup_cron.sh`
Before running the script, you need to make some adjustments:

   a) Create a dedicated user for API interaction.  
   b) Grant the user appropriate API rights to create and restore backups.  
   c) Generate an API token and copy it into the script.  
   d) Specify the KUMA SIEM IP address and API port (7223 is used by default).

### 2. Make the Script Executable
Run the following command to make the script executable:

```bash
chmod +x backup_cron.sh
./backup_cron.sh
