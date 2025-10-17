#!/bin/bash
#
# Simple SIEM Event Tester
# Sends a specific number of events per second for a given duration
# Supports Syslog, CEF, XML over TCP or UDP
#

echo "=== SIEM Event Tester ==="

# Step 1 — address and port
read -p "Enter SIEM address (IP or hostname): " SIEM_HOST
read -p "Enter SIEM port (e.g. 514): " SIEM_PORT

# Step 2 — choose protocol
read -p "Choose protocol (1 - UDP or 2 - TCP): " PROTO_CHOICE
case $PROTO_CHOICE in
  1) PROTOCOL="udp" ;;
  2) PROTOCOL="tcp" ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

# Step 3 — choose event format
read -p "Choose event format (1 - Syslog, 2 - CEF, 3 - XML): " FORMAT_CHOICE
case $FORMAT_CHOICE in
  1) FORMAT="syslog" ;;
  2) FORMAT="cef" ;;
  3) FORMAT="xml" ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

# Step 4 — rate and duration
read -p "How many events per second to send: " EPS
read -p "For how many seconds to send: " DURATION

# Define sample messages
SYSLOG_MSG="<134>$(date '+%b %d %H:%M:%S') $(hostname) test-app: Test syslog message from SIEM tester"
CEF_MSG="CEF:0|ExampleVendor|ExampleProduct|1.0|100|Test CEF Event|5|src=$(hostname) msg=This is a CEF test message"
XML_MSG="<?xml version=\"1.0\"?><Event><Time>$(date -u +%Y-%m-%dT%H:%M:%SZ)</Time><Host>$(hostname)</Host><Message>Test XML event from SIEM tester</Message></Event>"

case $FORMAT in
  syslog) BASE_MSG=$SYSLOG_MSG ;;
  cef) BASE_MSG=$CEF_MSG ;;
  xml) BASE_MSG=$XML_MSG ;;
esac

echo ""
echo "Starting SIEM event test..."
echo "Target:   $SIEM_HOST:$SIEM_PORT ($PROTOCOL)"
echo "Format:   $FORMAT"
echo "Rate:     $EPS events/sec"
echo "Duration: $DURATION seconds"
echo ""

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
TOTAL_SENT=0

# Loop for the specified duration
while [ $(date +%s) -lt $END_TIME ]; do
  CURRENT_TIME=$(date +%s)
  for ((i=1; i<=EPS; i++)); do
    EVENT_MSG="${BASE_MSG} [id=${TOTAL_SENT}]"
    if [ "$PROTOCOL" == "udp" ]; then
      echo -n "$EVENT_MSG" | nc -u -w0 $SIEM_HOST $SIEM_PORT &
    else
      echo -n "$EVENT_MSG" | nc -w0 $SIEM_HOST $SIEM_PORT &
    fi
    ((TOTAL_SENT++))
  done
  wait  # wait until all background sends for this second are done
  sleep 1
done

ACTUAL_DURATION=$(( $(date +%s) - START_TIME ))
EPS_REAL=$(echo "scale=2; $TOTAL_SENT / $ACTUAL_DURATION" | bc)

echo ""
echo "✅ Test completed."
echo "Total events sent: $TOTAL_SENT"
echo "Actual duration:   ${ACTUAL_DURATION}s"
echo "Average rate:      ${EPS_REAL} events/sec"
