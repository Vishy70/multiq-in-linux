#!/bin/bash

echo "Enter the destination IP address:"
read DEST_IP

if ! command -v iperf3 >/dev/null 2>&1; then
  echo "iperf3 is not installed. Please install it and try again."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed. Please install it (e.g., sudo apt install jq) and try again."
  exit 1
fi

echo "Running iperf3 test to $DEST_IP..."

JSON_FILE="iperf3_result.json"
CSV_FILE="iperf3_result.csv"

# Run iperf3 and save as JSON
iperf3 -c "$DEST_IP" --json > "$JSON_FILE"

if [ $? -ne 0 ]; then
  echo "iperf3 test failed."
  exit 1
fi

# Write CSV header
echo "start,end,duration,transfer_MB,megabits_per_second" > "$CSV_FILE"

# Extract and append interval data
jq -r '
  .intervals[] |
  [
    .sum.start,
    .sum.end,
    (.sum.end - .sum.start),
    (.sum.bytes / (1024*1024)),           # bytes -> MB
    (.sum.bits_per_second / 1000000)      # bps -> Mbps
  ] | @csv
' "$JSON_FILE" >> "$CSV_FILE"

echo "Test complete. Results saved to:"
echo "  - JSON: $JSON_FILE"
echo "  - CSV : $CSV_FILE"
