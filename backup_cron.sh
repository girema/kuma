#!/bin/bash

# Get the current date in YYYY-MM-DD format
BACKUP_DATE=$(date +%F)  # Example: 2024-09-20

# Define the backup command with the date appended to the filename
BACKUP_COMMAND="curl -k --header 'Authorization: Bearer <token>' 'https://<ip_kuma>:7223/api/v1/system/backup' -o /opt/kaspersky/kuma/backup/backup_$BACKUP_DATE.tar.gz"

# Step 1: Execute the command to perform the backup
echo "Running the backup command..."
mkdir /opt/kaspersky/kuma/backup
eval "$BACKUP_COMMAND"

if [[ $? -eq 0 ]]; then
    echo "Backup successfully created: /opt/kaspersky/kuma/backup/backup_$BACKUP_DATE.tar.gz"
else
    echo "Backup command failed."
    exit 1
fi

# Step 2: Create a cron job to run the script every week on Friday at 4 PM

# Get the current script's full path
SCRIPT_PATH="$(realpath "$0")"

# Define the cron job entry
CRON_JOB="0 16 * * 5 $SCRIPT_PATH"

# Check if the cron job already exists
(crontab -l | grep -F "$SCRIPT_PATH") >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo "Cron job already exists."
else
    # Add the cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job added: Run every Friday at 4 PM"
fi
