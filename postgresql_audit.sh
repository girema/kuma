#!/bin/bash
# enable_postgres_audit_auto_silent_siem.sh
# Fully automated PostgreSQL audit setup (pgAudit + syslog + SIEM forwarding)
# PostgreSQL 16.x — silent package installation
# ------------------------------------------------------------

set -euo pipefail
set +H

RED=$(tput setaf 1) || RED=""
GREEN=$(tput setaf 2) || GREEN=""
YELLOW=$(tput setaf 3) || YELLOW=""
RESET=$(tput sgr0) || RESET=""

info() { echo "${GREEN}==>${RESET} $1"; }
warn() { echo "${YELLOW}!!${RESET} $1"; }
error_exit() { echo "${RED}❌ $1${RESET}"; exit 1; }

echo "---------------------------------------------"
echo " PostgreSQL pgAudit + SIEM Auto-Setup (silent)"
echo "---------------------------------------------"

# Check PostgreSQL client
if ! command -v psql >/dev/null 2>&1; then
  error_exit "PostgreSQL client (psql) not found. Please install postgresql-client first."
fi

# Detect version
PG_VERSION_FULL=$(psql -V | awk '{print $3}')
PG_MAJOR=$(echo "$PG_VERSION_FULL" | cut -d. -f1)
info "Detected PostgreSQL version: $PG_VERSION_FULL (major: $PG_MAJOR)"

# Ensure PostgreSQL is running
if ! sudo systemctl is-active --quiet postgresql; then
  warn "PostgreSQL is not running — starting..."
  sudo systemctl start postgresql >/dev/null 2>&1 || error_exit "Failed to start PostgreSQL."
fi

# Detect OS family
if grep -qiE "(debian|ubuntu)" /etc/os-release; then
  OS_FAMILY="debian"
elif grep -qiE "(centos|rhel|oracle|rocky|alma)" /etc/os-release; then
  OS_FAMILY="rhel"
else
  OS_FAMILY="unknown"
fi
info "Detected OS: $OS_FAMILY"

# Ensure PGDG repo exists
if [ "$OS_FAMILY" = "debian" ]; then
  if ! apt-cache search "postgresql-$PG_MAJOR-pgaudit" | grep -q "pgaudit" >/dev/null 2>&1; then
    warn "PGDG repository not found — adding..."
    sudo apt install -qq -y curl ca-certificates gnupg lsb-release >/dev/null 2>&1
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
      sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg >/dev/null 2>&1
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
    http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
      sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null 2>&1
    sudo apt update -qq >/dev/null 2>&1
  fi
fi

if [ "$OS_FAMILY" = "rhel" ]; then
  if ! sudo dnf list | grep -q "postgresql${PG_MAJOR}-pgaudit" >/dev/null 2>&1; then
    warn "PGDG repository not found — adding..."
    sudo dnf install -y -q \
      https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm >/dev/null 2>&1
    sudo dnf -qy module disable postgresql >/dev/null 2>&1 || true
  fi
fi

# Install pgAudit silently
info "Installing pgAudit for PostgreSQL $PG_MAJOR..."
if [ "$OS_FAMILY" = "debian" ]; then
  sudo apt install -qq -y "postgresql-$PG_MAJOR-pgaudit" >/dev/null 2>&1 || error_exit "Failed to install postgresql-$PG_MAJOR-pgaudit"
elif [ "$OS_FAMILY" = "rhel" ]; then
  sudo dnf install -y -q "postgresql${PG_MAJOR}-pgaudit" >/dev/null 2>&1 || error_exit "Failed to install postgresql${PG_MAJOR}-pgaudit"
else
  error_exit "Unsupported OS family."
fi
info "pgAudit successfully installed."

# Verify pgaudit.so
if ! sudo find /usr -name "pgaudit.so" | grep -q "postgresql"; then
  error_exit "pgaudit.so not found. Please verify installation of postgresql-${PG_MAJOR}-pgaudit."
fi

# Get postgresql.conf
PG_CONF=$(sudo -u postgres psql -t -P format=unaligned -c "SHOW config_file;" 2>/dev/null)
[ -z "$PG_CONF" ] && error_exit "Unable to locate postgresql.conf"
info "postgresql.conf path: $PG_CONF"

# Enable shared_preload_libraries
if grep -q "^shared_preload_libraries" "$PG_CONF"; then
  sudo sed -i "s/^shared_preload_libraries.*/shared_preload_libraries = 'pgaudit'/" "$PG_CONF"
else
  echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PG_CONF" >/dev/null
fi
info "shared_preload_libraries set to 'pgaudit'"

# Add pgAudit + syslog block
if ! grep -q "PG AUDIT + SYSLOG CONFIGURATION" "$PG_CONF"; then
sudo tee -a "$PG_CONF" >/dev/null <<'EOF'

#########################################
##  PG AUDIT + SYSLOG CONFIGURATION
#########################################
log_destination = 'syslog'
syslog_facility = 'LOCAL0'
syslog_ident = 'Postgres'
lc_messages = 'en_US.UTF-8'
client_min_messages = warning
log_min_error_statement = warning
log_connections = on
log_disconnections = on
log_statement = 'none'
log_line_prefix = '%m|%a|%d|%p|%r|%i|%u| %e '
log_hostname = off

#########################################
##  PGAUDIT SETTINGS
#########################################
pgaudit.log_parameter = on
pgaudit.log = 'READ, WRITE, ROLE, DDL, FUNCTION, MISC'
EOF
fi
info "pgAudit and syslog configuration applied."

# Configure rsyslog for local audit log
RSYSLOG_CONF="/etc/rsyslog.d/30-postgres.conf"
AUDIT_LOG_DIR="/var/log/postgresql"
AUDIT_LOG_FILE="$AUDIT_LOG_DIR/audit.log"
sudo mkdir -p "$AUDIT_LOG_DIR" >/dev/null 2>&1
sudo chown postgres:postgres "$AUDIT_LOG_DIR" >/dev/null 2>&1
echo "local0.*    $AUDIT_LOG_FILE" | sudo tee "$RSYSLOG_CONF" >/dev/null
sudo systemctl restart rsyslog >/dev/null 2>&1 || warn "Could not restart rsyslog"
info "Local syslog configured at: $AUDIT_LOG_FILE"

# === SIEM CONFIGURATION ===
echo ""
info "SIEM integration setup"
read -rp "Enter SIEM address or hostname: " SIEM_ADDR
read -rp "Enter SIEM port (e.g., 514): " SIEM_PORT
read -rp "Choose protocol (1 - UDP, 2 - TCP): " SIEM_PROTO

if [ "$SIEM_PROTO" = "1" ]; then
  FORWARD_SYNTAX="*.* @$SIEM_ADDR:$SIEM_PORT"
  PROTO_NAME="UDP"
else
  FORWARD_SYNTAX="*.* @@$SIEM_ADDR:$SIEM_PORT"
  PROTO_NAME="TCP"
fi

SIEM_CONF="/etc/rsyslog.d/31-siem.conf"
echo "$FORWARD_SYNTAX" | sudo tee "$SIEM_CONF" >/dev/null
sudo systemctl restart rsyslog >/dev/null 2>&1 || warn "Could not restart rsyslog after SIEM config"
info "SIEM forwarding enabled ($PROTO_NAME → $SIEM_ADDR:$SIEM_PORT)"

# Restart PostgreSQL safely
info "Restarting PostgreSQL..."
if ! sudo systemctl restart postgresql >/dev/null 2>&1; then
  error_exit "PostgreSQL failed to restart — check configuration."
fi
info "PostgreSQL restarted successfully."

# Create pgAudit extension
info "Creating pgAudit extension..."
if ! sudo -u postgres psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS pgaudit;" >/dev/null 2>&1; then
  error_exit "Failed to create pgAudit extension. Check PostgreSQL logs."
fi
info "pgAudit extension created successfully."

# Summary
echo "---------------------------------------------"
echo "${GREEN}✅ PostgreSQL audit successfully enabled!${RESET}"
echo "Local audit log: ${YELLOW}$AUDIT_LOG_FILE${RESET}"
echo "Forwarding to SIEM: ${YELLOW}$PROTO_NAME → $SIEM_ADDR:$SIEM_PORT${RESET}"
echo "Test with: ${YELLOW}logger 'test message from PostgreSQL audit'${RESET}"
echo "Check with: ${YELLOW}sudo tail -f $AUDIT_LOG_FILE${RESET}"
echo "---------------------------------------------"
