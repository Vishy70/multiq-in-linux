#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_json_file>"
  exit 1
fi

INPUT="$1"
OUTPUT="${INPUT%.*}.csv"

# Write CSV header
echo "start,end,seconds,bytes,bits_per_second,rtt,omitted,sender" > "$OUTPUT"

# Extract interval data and append to CSV
jq -r '
  .intervals[]? as $i |
  $i.sum as $s |
  $i.streams[0] as $stream |
  [
    $s.start, $s.end, $s.seconds, $s.bytes, $s.bits_per_second, $stream.rtt, $s.omitted, $s.sender
  ] | @csv
' "$INPUT" >> "$OUTPUT"

echo "CSV written to $OUTPUT"