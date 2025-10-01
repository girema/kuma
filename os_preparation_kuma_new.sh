#!/bin/bash

# Define colors
green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

# Function to display a progress bar with green color for "Done!"
show_progress() {
    local duration=$1
    local bar_length=50
    local interval=$((duration / bar_length))
    
    echo -n "["
    for ((i=0; i<bar_length; i++)); do
        sleep $interval
        echo -n "="
    done
    echo -n "]"
    echo -e "${green} Done!${reset}"
}

# Function to install compat-openssl11 for Oracle Linux 9.2 and newer
install_compat_openssl() {
    sudo yum install -y compat-openssl11 > /dev/null 2>&1
}

# Function to check OS and version
check_os_and_version() {
    # Load OS information
    . /etc/os-release

    if [[ "$NAME" == "Oracle Linux Server" || "$NAME" == "Oracle Linux" ]]; then
        version="$VERSION_ID"
        major_version=$(echo "$version" | awk -F. '{print $1}')
        minor_version=$(echo "$version" | awk -F. '{print $2}')

        if [[ "$major_version" -lt 8 || ( "$major_version" -eq 8 && "$minor_version" -lt 6 ) ]]; then
            echo "Error: This script requires Oracle Linux version 8.6 or higher."
            exit 1
        fi

        if [[ "$major_version" -eq 9 ]]; then
            if [[ "$minor_version" -lt 2 ]]; then
                echo "Error: Oracle Linux 9 versions lower than 9.2 are not supported."
                exit 1
            fi
            install_compat_openssl
        elif [[ "$major_version" -gt 9 ]]; then
            echo "Error: Oracle Linux versions higher than 9.* are not supported."
            exit 1
        fi

        os="oracle"

    elif [[ "$NAME" == "Ubuntu" ]]; then
        version="$VERSION_ID"
        major_version=$(echo "$version" | awk -F. '{print $1}')
        minor_version=$(echo "$version" | awk -F. '{print $2}')

        if [[ "$major_version" -lt 8 || ( "$major_version" -eq 8 && "$minor_version" -lt 6 ) ]]; then
            echo "Error: This script requires Oracle Linux version 8.6 or higher."
            exit 1
        fi

        # Ubuntu 22.* vs 24.* package sets
        if [[ "$major_version" -eq 22 ]]; then
            echo "Detected Ubuntu $version (22.* series)"
            extra_pkgs="libatk1.0-0 libgtk2.0-0 libatk-bridge2.0-0 libcups2 \
                        libxcomposite-dev libxdamage1 libxrandr2 libgbm-dev \
                        libxkbcommon-x11-0 libpangocairo-1.0-0 libasound2"
        elif [[ "$major_version" -eq 24 ]]; then
            echo "Detected Ubuntu $version (24.* series)"
            extra_pkgs="libatk1.0-0 libgtk2.0-0 libatk-bridge2.0-0 libcups2 \
                        libxcomposite-dev libxdamage1 libxrandr2 libgbm-dev \
                        libxkbcommon-x11-0 libpangocairo-1.0-0 libasound2t64"
        else
            echo "Warning: Ubuntu version $version is not supported."
            extra_pkgs=""
            exit 1
        fi

        os="ubuntu"

    else
        echo "Error: This script is intended for Oracle Linux or Ubuntu only."
        exit 1
    fi
}

# Function to check and disable IPv6
check_disable_ipv6() {
    if sysctl net.ipv6.conf.all.disable_ipv6 | grep -q "0"; then
        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
        sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1
        if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
            echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        fi
        if ! grep -q "net.ipv6.conf.default.disable_ipv6 = 1" /etc/sysctl.conf; then
            echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        fi
    fi
    sudo sed -i '/:[0-9a-fA-F]\{1,4\}/d' /etc/hosts > /dev/null 2>&1
}

# Function to install required packages for Oracle Linux and Ubuntu
install_packages() {
    if [ "$os" == "ubuntu" ]; then
        sudo apt update > /dev/null 2>&1
        sudo apt install -y python3 python3-pip acl $extra_pkgs > /dev/null 2>&1
        sudo pip3 install netaddr > /dev/null 2>&1
    else
        sudo yum update -y > /dev/null 2>&1
        sudo yum install -y python3 nss gtk2 atk libnss3.so libatk-1.0.so.0 \
            libxkbcommon libdrm at-spi2-atk mesa-libgbm alsa-lib cups-libs \
            libXcomposite libXdamage libXrandr > /dev/null 2>&1
        sudo pip3 install netaddr > /dev/null 2>&1
    fi
}

# Function to update SSH configuration (ask before enabling root login)
update_ssh_config() {
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak > /dev/null 2>&1
    while true; do
        read -p "Do you want to allow root login via SSH? (yes/no): " allow_root
        case "$allow_root" in
            [Yy][Ee][Ss]|[Yy])
                sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config > /dev/null 2>&1
                echo "Root SSH login enabled."
                break
                ;;
            [Nn][Oo]|[Nn])
                sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config > /dev/null 2>&1
                echo "Root SSH login disabled."
                break
                ;;
            *)
                echo "Invalid input. Please enter yes or no."
                ;;
        esac
    done
    sudo systemctl restart sshd > /dev/null 2>&1
}

# Function to enable and start chronyd (Oracle Linux) or ntp/timesyncd (Ubuntu)
enable_time_service() {
    if [ "$os" == "ubuntu" ]; then
        if systemctl list-unit-files | grep -q ntp.service; then
            sudo systemctl enable --now ntp > /dev/null 2>&1
        else
            sudo systemctl enable --now systemd-timesyncd > /dev/null 2>&1
        fi
    else
        sudo systemctl enable --now chronyd > /dev/null 2>&1
    fi
}

# Function to set hostname with confirmation if it contains dots
set_hostname() {
    current_hostname=$(hostname -f)
    if [[ "$current_hostname" != *.* ]]; then
        while true; do
            read -p "Current hostname '$current_hostname' does not contain any dots. Enter the new hostname (must contain at least one dot): " new_hostname
            if [[ "$new_hostname" == *.* ]]; then
                sudo hostnamectl set-hostname "$new_hostname" > /dev/null 2>&1
                add_hostname_to_hosts "$new_hostname"
                break
            else
                echo "Error: The hostname must contain at least one dot."
            fi
        done
    else
        while true; do
            read -p "Current hostname is '$current_hostname'. Do you want to proceed with this hostname? (yes/no): " confirmation
            case "$confirmation" in
                [Yy][Ee][Ss]|[Yy])
                    echo -e "${green}Proceeding with the current hostname '$current_hostname'.${reset}"
                    break
                    ;;
                [Nn][Oo]|[Nn])
                    while true; do
                        read -p "Enter a new hostname (must contain at least one dot): " new_hostname
                        if [[ "$new_hostname" == *.* ]]; then
                            sudo hostnamectl set-hostname "$new_hostname" > /dev/null 2>&1
                            add_hostname_to_hosts "$new_hostname"
                            break
                        else
                            echo "Error: The hostname must contain at least one dot."
                        fi
                    done
                    break
                    ;;
                *)
                    echo "Invalid input. Please enter 'yes' or 'no'."
                    ;;
            esac
        done
    fi
}

# Function to add the new hostname to /etc/hosts
add_hostname_to_hosts() {
    new_hostname=$1
    ip_address=$(hostname -I | awk '{print $1}') # Get the first IP address assigned to the host
    if ! grep -q "$new_hostname" /etc/hosts; then
        echo "$ip_address $new_hostname" | sudo tee -a /etc/hosts > /dev/null 2>&1
    fi
}

# Function to check SELinux status and disable it if necessary (Oracle Linux)
check_selinux() {
    if [ "$os" == "oracle" ] && sestatus | grep -q "enabled"; then
        sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config > /dev/null 2>&1
        echo "SELinux is enabled. It has been disabled in the configuration file."
    elif [ "$os" == "oracle" ]; then
        echo "SELinux is already disabled."
    fi
}

# Function to disable firewalld (Oracle Linux) or ufw (Ubuntu)
disable_firewall() {
    if [ "$os" == "ubuntu" ]; then
        sudo systemctl stop ufw > /dev/null 2>&1
        sudo systemctl disable ufw > /dev/null 2>&1
    else
        sudo systemctl stop firewalld > /dev/null 2>&1
        sudo systemctl disable firewalld > /dev/null 2>&1
    fi
}

# Function to check for CPU instructions and display result
validate_cpu_instructions() {
    echo "Checking CPU instructions:"

    # Check for AVX
    if grep -q 'avx' /proc/cpuinfo; then
        echo -e "${green}AVX support detected.${reset}"
    else
        echo -e "${red}AVX support not detected.${reset}"
    fi

    # Check for SSE4
    if grep -q 'sse4' /proc/cpuinfo; then
        echo -e "${green}SSE4 support detected.${reset}"
    else
        echo -e "${red}SSE4 support not detected.${reset}"
    fi

    # Check for BMI2
    if grep -q 'bmi2' /proc/cpuinfo; then
        echo -e "${green}BMI2 support detected.${reset}"
    else
        echo -e "${red}BMI2 support not detected.${reset}"
    fi
}

# Check OS and version
check_os_and_version

# Check for internet access by pinging google.com
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${red}No internet access. Unable to reach google.com.${reset}"
    exit 1
fi

# Check and disable IPv6 if enabled
check_disable_ipv6

# Set hostname if needed
set_hostname

# Validate CPU instructions
validate_cpu_instructions

# Show progress for remaining installation steps
echo "Executing remaining setup steps..."

# Install required packages
echo "Installing required packages..."
install_packages
show_progress 10 # Display progress for 10 seconds

# Update SSH configuration
echo "Updating SSH configuration..."
update_ssh_config
show_progress 10 # Display progress for 10 seconds

# Enable and start time service
echo "Enabling and starting time service..."
enable_time_service
show_progress 10 # Display progress for 10 seconds

# Disable firewalld or ufw
echo "Disabling firewall..."
disable_firewall
show_progress 10 # Display progress for 10 seconds

# Check if SELinux is disabled
check_selinux

# If all checks pass
echo -e "${green}Setup completed successfully!${reset}"
