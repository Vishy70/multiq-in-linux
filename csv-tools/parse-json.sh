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
  echo "start,end,seconds,bytes,bits_per_second,rtt,omitted,sender" > "$filename"

  # Extract and append interval data
  jq -r '
    .intervals[]? as $i |
    $i.sum as $s |
    $i.streams[0] as $stream |
    [
      $s.start, $s.end, $s.seconds, $s.bytes, $s.bits_per_second, $stream.rtt, $s.omitted, $s.sender
    ] | @csv
  ' "$src_filename" >> "$filename"
  
done
