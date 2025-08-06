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
  
  if [[ "$file" != *"quic"* ]]; 
  then
    continue
  fi

  echo "Parsing file: $file"
  src_filename="$SRC_DIR/$file"
  filename="$DEST_DIR/$file"
  touch $filename

  # Write CSV header
  echo "second,Mbps,bytes_received" > "$filename"

  # Extract and append interval data
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
  ' "$src_filename" >> "$filename"
  
done
