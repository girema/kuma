## KUMA SIEM Automation Scripts

This section is dedicated to KUMA SIEM and provides automation scripts that can assist with routine tasks.
Below are the steps to set up and use these script:

### 1. KUMA Backup via API `backup_cron.sh`

## Backup and Schedule Script for KUMA SIEM

This script automates the process of backing up KUMA SIEM and sets up a cron job to schedule regular backups.

### Functionality

1. **Run Backup Immediately**: 
   - Executes a `curl` command to create a KUMA SIEM backup using the API.
   - Saves the backup as `backup_<date>.tar.gz` in a specified folder, with the current date appended to the filename.

2. **Schedule Weekly Backups**: 
   - Sets up a cron job that runs the backup script every Friday at 4 PM.

### Prerequisites

- Ensure you have a valid API token for KUMA SIEM with appropriate backup privileges.
- Replace `<token>` and `<ip_kuma>` in the script with your actual KUMA SIEM token and IP address.

### Usage

Make the script executable and run:
```bash
chmod +x backup_cron.sh
./backup_cron.sh
```
```
Backups will be automatically created in the `/opt/kaspersky/kuma/backup` folder every Friday at 4 PM.

### 2. Clear KUMA Collectors log files

## Directory Formatter and Cleaner Script

This script performs two tasks:

1. **Part 1**: It scans the current directory, identifies all subdirectories, and generates a file called `directories.txt` containing formatted paths for each subdirectory. Each path is appended with `/opt/kaspersky/kuma/collector/<directory_name>/log/`.

2. **Part 2**: It reads the paths from `directories.txt` and deletes all files inside each listed directory.

### Usage

Run the script in the directory you want to scan for subdirectories:
```bash
chmod +x clear_collector_logs.sh
./clear_collector_logs.sh
```

### 3. KUMA Log collection for troubleshooting

## Log Collection and Archiving Script for KUMA SIEM

This script automates the process of collecting log files from various KUMA SIEM services, stores them in a designated troubleshooting directory, and compresses the logs into a `.tar.gz` archive. Additionally, it collects basic system information.

### Functionality

1. **Collect Logs**:
   - Gathers log files from the following service directories:
     - `/opt/vendor/siem/collector`
     - `/opt/vendor/siem/correlator`
     - `/opt/vendor/siem/clickhouse`
     - `/opt/vendor/siem/storage`
     - `/opt/vendor/siem/agent`
     - `/opt/vendor/siem/core`
   - Stores the collected logs in a troubleshooting folder named with the current timestamp.
   
2. **System Information**:
   - Collects basic system information (`ip a`, `hostname`, routing info, service status, and recent logs) and stores it in `system_info.txt`.

3. **Archiving and Cleanup**:
   - Compresses the logs and system information into a `.tar.gz` archive.
   - Removes the troubleshooting folder after the archive is created.

### Usage

Make the script executable and run:
```bash
chmod +x collect_logs.sh
./collect_logs.sh
```
