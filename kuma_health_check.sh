#!/bin/bash

LOG_FILE="/var/log/siem/service_status.txt"
mkdir -p /var/log/siem
: > "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] KUMA Service Status Report" >> "$LOG_FILE"
echo "=========================================================" >> "$LOG_FILE"

unset GROUPS
declare -A GROUPS
GROUPS["Agent"]="kuma-agent"
GROUPS["Collector"]="kuma-collector"
GROUPS["Core"]="kuma-core"
GROUPS["Correlator"]="kuma-correlator"
GROUPS["Metrics"]="kuma-metrics"
GROUPS["Storage"]="kuma-storage"

for GROUP in "${!GROUPS[@]}"; do
    PREFIX="${GROUPS[$GROUP]}"
    echo -e "\n### $GROUP Services ###" >> "$LOG_FILE"

    mapfile -t SERVICES < <(systemctl list-units --type=service --no-legend | grep "^$PREFIX" | awk '{print $1}')

    unset STATUS_MAP
    declare -A STATUS_MAP

    for SERVICE in "${SERVICES[@]}"; do
        STATUS=$(systemctl is-active "$SERVICE")
        STATUS_MAP["$STATUS"]+="$SERVICE"$'\n'
    done

    for STATUS in "${!STATUS_MAP[@]}"; do
        echo -e "\n-- Status: $STATUS --" >> "$LOG_FILE"
        while read -r SERVICE; do
            [[ -z "$SERVICE" ]] && continue
            echo -n "$SERVICE" >> "$LOG_FILE"

            if [[ "$STATUS" != "active" ]]; then
                ERROR_LINE=$(journalctl -xu "$SERVICE" -n 50 2>/dev/null | \
                    grep -Ei 'error|fail|exit|exception|critical' | \
                    grep -v '^--' | \
                    grep -v 'systemd\[' | \
                    grep -E 'kuma\[|Error:|{.*}' | \
                    tail -n 1)

                if [[ -n "$ERROR_LINE" ]]; then
                    if echo "$ERROR_LINE" | grep -q '{.*}'; then
                        ERROR_MSG=$(echo "$ERROR_LINE" | grep -oP '\{.*\}')
                    elif echo "$ERROR_LINE" | grep -q 'Error:'; then
                        ERROR_MSG=$(echo "$ERROR_LINE" | awk -F'Error: ' '{print $2}')
                    else
                        ERROR_MSG="$ERROR_LINE"
                    fi
                    echo -e " ? Error: $ERROR_MSG" >> "$LOG_FILE"
                else
                    echo "" >> "$LOG_FILE"
                fi
            else
                echo "" >> "$LOG_FILE"
            fi
        done <<< "${STATUS_MAP[$STATUS]}"
    done
done
