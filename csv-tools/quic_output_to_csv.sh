#!/bin/bash

# Check for input
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <qperf_output_file>"
    exit 1
fi

input_file="$1"
output_dir="CSV"
base_name=$(basename "$input_file")
output_file="$output_dir/$base_name.csv"

mkdir -p "$output_dir"

# Write CSV header
echo "second,Mbps,bytes_received" > "$output_file"

# Process the input file
awk '
/^second [0-9]+:/ {
    gsub(":", "", $2)
    second = $2
    mbps = $3
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^\([0-9]+$/) {
            gsub("\\(", "", $i)
            bytes = $i
            break
        }
    }
    print second "," mbps "," bytes
}
' "$input_file" >> "$output_file"

echo "CSV saved to: $output_file"
