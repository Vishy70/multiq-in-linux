#!/bin/bash
SRC_DIR="./tests"
DEST_DIR="./tests-csv"

if [ ! -d  $SRC_DIR ];
then
  echo "No tests to convert to csv. Please ensure the tests directory exists."
  exit 1
fi
if [ ! -d  $DEST_DIR ];
then
  mkdir $DEST_DIR  
fi

files_with_path=("$SRC_DIR"/*)
files=()

for file in "${files_with_path[@]}"; do
  files+=("${file##*/}")
done

for file in "${files[@]}"; 
do
  
  if [[ "$file" == *"quic"* ]]; 
  then
    continue
  fi

  echo "Parsing file: $file"
  src_filename="$SRC_DIR/$file"
  filename="$DEST_DIR/$file"
  touch $filename

  # Write CSV header
  echo "start,end,duration,transfer_MB,megabits_per_second" > $filename

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
  ' "$src_filename" >> "$filename"
done
