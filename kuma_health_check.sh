#!/bin/bash

# Output file
LOG_FILE="/var/log/siem/service_status.txt"
mkdir -p /var/log/siem
: > "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] KUMA Service Status Report" >> "$LOG_FILE"
echo "=========================================================" >> "$LOG_FILE"

# Declare associative array for service groups
unset GROUPS
declare -A GROUPS
GROUPS["Agent"]="kuma-agent"
GROUPS["Collector"]="kuma-collector"
GROUPS["Core"]="kuma-core"
GROUPS["Correlator"]="kuma-correlator"
GROUPS["Metrics"]="kuma-metrics"
GROUPS["Storage"]="kuma-storage"

# Loop through each group
for GROUP in "${!GROUPS[@]}"; do
    PREFIX="${GROUPS[$GROUP]}"
    echo -e "\n### $GROUP Services ###" >> "$LOG_FILE"

    # Get matching services
    mapfile -t SERVICES < <(systemctl list-units --type=service --no-legend | grep "^$PREFIX" | awk '{print $1}')

    # Temporary associative array for grouping by status
    unset STATUS_MAP
    declare -A STATUS_MAP

    for SERVICE in "${SERVICES[@]}"; do
        STATUS=$(systemctl is-active "$SERVICE")
        STATUS_MAP["$STATUS"]+="$SERVICE"$'\n'
    done

    # Output services grouped by status
    for STATUS in "${!STATUS_MAP[@]}"; do
        echo -e "\n-- Status: $STATUS --" >> "$LOG_FILE"
        echo -n "${STATUS_MAP[$STATUS]}" >> "$LOG_FILE"
    done
done
