#!/bin/bash


# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print messages in green
print_green() {
    echo -e "${GREEN}$1${NC}"
}

# Function to print messages in red
print_red() {
    echo -e "${RED}$1${NC}"
}

# Function to check the status of systemd services
check_services_status() {
    local services
    services=$(systemctl list-units --type=service --state=active | grep '^kuma-' | awk '{print $1}')
    if [[ -z "$services" ]]; then
        echo "No kuma-* services are currently active."
        return 1
    fi
    local all_active=true
    for service in $services; do
        status=$(systemctl is-active "$service")
        if [[ "$status" != "active" ]]; then
            print_red "$service is not active. Status: $status"
            all_active=false
        fi
    done
    if $all_active; then
        print_green "All kuma-* services are running."
    fi
}

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Change to the script directory
cd "$SCRIPT_DIR" || { echo "Failed to change directory to $SCRIPT_DIR"; exit 1; }

# Print current directory and list files for debugging
echo "Current directory: $SCRIPT_DIR"
echo "Files in the directory:"
ls

# Find all relevant archive files in the script directory
archives=$(find . -maxdepth 1 -type f -name 'kuma-ansible-installer-[0-9]*.[0-9]*.[0-9]*.[0-9]*.tar.gz')

# Debug: Print found archives
echo "Found archives:"
echo "$archives"

# Initialize the highest version variable
highest_version=""
highest_archive=""

# Function to compare versions
compare_versions() {
    local version1="$1"
    local version2="$2"
    IFS=. read -r i1 i2 i3 i4 <<< "$version1"
    IFS=. read -r j1 j2 j3 j4 <<< "$version2"
    # Handle cases where version parts might be missing
    i1=${i1:-0} ; i2=${i2:-0} ; i3=${i3:-0} ; i4=${i4:-0}
    j1=${j1:-0} ; j2=${j2:-0} ; j3=${j3:-0} ; j4=${j4:-0}
    if (( i1 != j1 )); then
        (( i1 > j1 )) && echo "$version1" || echo "$version2"
    elif (( i2 != j2 )); then
        (( i2 > j2 )) && echo "$version1" || echo "$version2"
    elif (( i3 != j3 )); then
        (( i3 > j3 )) && echo "$version1" || echo "$version2"
    else
        (( i4 > j4 )) && echo "$version1" || echo "$version2"
    fi
}

# Iterate over the archives to find the highest version
for archive in $archives; do
    # Extract version number from the filename
    version=$(echo "$archive" | sed -r 's|.*/kuma-ansible-installer-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz|\1|')
    # Debug: Print the extracted version
    echo "Extracted version: $version"
    # Compare and update the highest version
    if [[ -z "$highest_version" ]]; then
        highest_version="$version"
        highest_archive="$archive"
    else
        latest_version=$(compare_versions "$highest_version" "$version")
        if [[ "$latest_version" == "$version" ]]; then
            highest_version="$version"
            highest_archive="$archive"
        fi
    fi
done

# Check if a highest archive was found
if [[ -n "$highest_archive" ]]; then
    echo "The highest version archive is: $highest_archive"
    # Check if the `kuma-ansible-installer` directory exists
    if [[ -d "kuma-ansible-installer" ]]; then
        # Remove existing `kuma-ansible-installer-old` directory if it exists
        if [[ -d "kuma-ansible-installer-old" ]]; then
            rm -rf "kuma-ansible-installer-old"
            print_green "Removed existing kuma-ansible-installer-old directory."
        fi
        # Rename existing directory
        mv "kuma-ansible-installer" "kuma-ansible-installer-old"
        print_green "Renamed existing kuma-ansible-installer directory to kuma-ansible-installer-old."
    fi
    # Create the target directory for extraction
    mkdir -p "kuma-ansible-installer"
    # Extract the highest version file into the target directory
    echo "Extracting $highest_archive into kuma-ansible-installer..."
    if tar -xzf "$highest_archive" -C "kuma-ansible-installer"; then
        print_green "Extraction completed."
    else
        echo "Failed to extract $highest_archive."
        exit 1
    fi
    # Check for a license key file and copy it
    license_key=$(find . -maxdepth 1 -type f -name '*.key')
    if [[ -n "$license_key" ]]; then
        echo "Found license key file: $license_key"
        # Copy and rename the license key file to the target directory
        cp "$license_key" "kuma-ansible-installer/kuma-ansible-installer/roles/kuma/files/license.key"
        print_green "License key copied to kuma-ansible-installer/kuma-ansible-installer/roles/kuma/files/ as license.key."
    else
        echo "No license key file found in the directory."
        exit 1
    fi
    # Change to the nested `kuma-ansible-installer` directory
    cd "kuma-ansible-installer/kuma-ansible-installer" || { echo "Failed to change directory to kuma-ansible-installer/kuma-ansible-installer"; exit 1; }
    # Execute the copy command
    echo "Copying single.inventory.yml.template to single.inventory.yml..."
    if cp single.inventory.yml.template single.inventory.yml; then
        print_green "Copy completed."
    else
        echo "Failed to copy single.inventory.yml.template to single.inventory.yml."
        exit 1
    fi
    # Get the fully qualified domain name (FQDN)
    fqdn=$(hostname -f)
    # Replace `kuma.example.com` with the FQDN in `single.inventory.yml`
    echo "Replacing kuma.example.com with $fqdn in single.inventory.yml..."
    if sed -i "s/kuma.example.com/$fqdn/g" single.inventory.yml; then
        print_green "Replacement completed."
    else
        echo "Failed to replace kuma.example.com in single.inventory.yml."
        exit 1
    fi
    # Prompt user for deploy_example_services value
    attempt=1
    max_attempts=3
    while (( attempt <= max_attempts )); do
        read -rp "Set deploy_example_services to true or false? " user_input
        # Validate user input
        if [[ "$user_input" == "true" || "$user_input" == "false" ]]; then
            # Replace `deploy_example_services` value in `single.inventory.yml`
            echo "Replacing deploy_example_services value with $user_input in single.inventory.yml..."
            if sed -i "s/deploy_example_services: [^ ]*/deploy_example_services: $user_input/" single.inventory.yml; then
                print_green "Replacement completed."
                break
            else
                echo "Failed to replace deploy_example_services value in single.inventory.yml."
                exit 1
            fi
        else
            echo "Invalid input. Please enter 'true' or 'false'."
            (( attempt++ ))
            if (( attempt > max_attempts )); then
                echo "Too many invalid attempts. Exiting."
                exit 1
            fi
        fi
    done
    # Run the installer with parameters
    echo "Running the installer with single.inventory.yml..."
    if ./install.sh single.inventory.yml -e "accept_eula=yes default_admin_password=yes"; then
        print_green "Installer completed successfully."
    else
        echo "Installer failed."
        exit 1
    fi
else
    echo "No archives found in the directory."
    exit 1
fi

# Check the status of systemd services
check_services_status
