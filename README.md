## KUMA SIEM Automation Scripts

This section is dedicated to KUMA SIEM and provides automation scripts that can assist with routine tasks.
Below are the steps to set up and use these script:

### 1. KUMA Backup via API `backup_cron.sh`
Before running the script, you need to make some adjustments:

   a) Create a dedicated user for API interaction.  
   b) Grant the user appropriate API rights to create and restore backups.  
   c) Generate an API token and copy it into the script.  
   d) Specify the KUMA SIEM IP address and API port (7223 is used by default).

Run the following command to make the script executable:

```bash
chmod +x backup_cron.sh
./backup_cron.sh
```
Backups will be automatically created in the `/opt/kaspersky/kuma/backup` folder every Friday at 4 PM.

### 2. Clear KUMA Collectors log files
## Directory Formatter and Cleaner Script

This script performs two tasks:

1. **Part 1**: It scans the current directory, identifies all subdirectories, and generates a file called `directories.txt` containing formatted paths for each subdirectory. Each path is appended with `/opt/kaspersky/kuma/collector/<directory_name>/log/`.

2. **Part 2**: It reads the paths from `directories.txt` and deletes all files inside each listed directory.

### Usage

1. Run the script in the directory you want to scan for subdirectories:
```bash
chmod +x clear_collector_logs.sh
./clear_collector_logs.sh
```

### 3. KUMA Log collection for troubleshooting



