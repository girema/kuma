#!/bin/bash

# Define main directories of the services
SERVICE_DIRS=(
    "/opt/kaspersky/kuma/collector"
    "/opt/kaspersky/kuma/correlator"
    "/opt/kaspersky/kuma/storage"
    "/opt/kaspersky/kuma/agent"
    "/opt/kaspersky/kuma/core"
)

# Create troubleshooting directory with current timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TROUBLESHOOT_DIR="/opt/kaspersky/kuma/troubleshooting/$TIMESTAMP"
mkdir -p "$TROUBLESHOOT_DIR"

# Function to collect log files from service directories
collect_logs() {
    local service_dir="$1"
    local service_name="$2"

    # Loop through the unique folders inside the service directory
    for unique_folder in "$service_dir"/*/; do
        if [[ -d "$unique_folder" ]]; then
            echo "Processing unique folder: $unique_folder"

            log_dir="${unique_folder%/}/log"  # Remove trailing slash and add /log
            echo "Looking for log directory: $log_dir"
            
            if [[ -d "$log_dir" ]]; then
                log_file="$log_dir/$service_name"
                echo "Checking log file: $log_file"
                
                if [[ -f "$log_file" ]]; then
                    # Create a sub-directory in the troubleshooting folder with service name and unique ID
                    unique_folder_name=$(basename "$unique_folder")
                    target_dir="$TROUBLESHOOT_DIR/${service_name}_${unique_folder_name}"
                    mkdir -p "$target_dir"

                    # Copy the log file to the target directory
                    cp "$log_file" "$target_dir/"
                    echo "Collected log file: $log_file -> $target_dir/"
                else
                    echo "Log file not found for service $service_name in: $log_file"
                fi
            else
                echo "Log directory not found in: $log_dir"
            fi
        else
            echo "No unique folders found in: $service_dir"
        fi
    done
}

# Collect logs for each service directory
for service_dir in "${SERVICE_DIRS[@]}"; do
    service_name=$(basename "$service_dir")
    echo "Collecting logs for service: $service_name"
    collect_logs "$service_dir" "$service_name"
done

# Create a system info file inside the troubleshooting folder
SYS_INFO_FILE="$TROUBLESHOOT_DIR/system_info.txt"
echo "Collecting system information..."

{
    echo "===== IP Address Information (ip a) ====="
    ip a
    echo

    echo "===== Routing Information (show route) ====="
    ip route show
    echo
    
    echo "===== Hostname (hostname -f) ====="
    hostname -f
    echo

    echo "===== Hosts file (/etc/hosts) ====="
    cat /etc/hosts
    echo

    echo "===== Resolve.conf (/etc/resolv.conf) ====="
    cat /etc/resolv.conf
    echo

    echo "===== Service Status (systemctl status kuma-*) ====="
    systemctl status kuma-* || echo "No kuma services found."
    echo

    echo "===== Recent System Logs (journalctl -xe) ====="
    journalctl -xe
} > "$SYS_INFO_FILE"

echo "System information collected in: $SYS_INFO_FILE"

# Ensure the troubleshooting directory exists before archiving
if [[ -d "$TROUBLESHOOT_DIR" ]]; then
    echo "Starting the archive and compression process..."

    # Archive and compress the troubleshooting folder
    ARCHIVE_PATH="/opt/kaspersky/kuma/troubleshooting/troubleshooting_$TIMESTAMP.tar.gz"
    tar -czf "$ARCHIVE_PATH" -C "/opt/kaspersky/kuma/troubleshooting" "$TIMESTAMP"

    if [[ $? -eq 0 ]]; then
        echo "Logs have been archived and compressed at: $ARCHIVE_PATH"
        # Remove the troubleshooting folder after archiving
        rm -rf "$TROUBLESHOOT_DIR"
        echo "Removed the troubleshooting folder: $TROUBLESHOOT_DIR"
    else
        echo "Error creating archive."
    fi
else
    echo "Error: Troubleshooting directory $TROUBLESHOOT_DIR does not exist."
fi

echo "All log files have been collected in: $TROUBLESHOOT_DIR"
