#!/bin/bash
SRC_DIR="./tests"
DEST_DIR="./tests-csv"

if [ ! -d "$SRC_DIR" ]; then
  echo "Source directory '$SRC_DIR' not found. Please ensure it exists."
  exit 1
fi
# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"


# Use 'find' to get a list of all files in the source directory and its subdirectories.
# Pipe the list to a 'while read' loop
find "$SRC_DIR" -type f | while IFS= read -r src_filepath; do
  
  # Check if the filename contains "quic" and skip it; use parse-quic.sh!
  if [[ "$src_filepath" == *"quic"* || "$src_filepath" == *".txt" ]]; then
    continue
  fi


  if [[ "$src_filepath" == *".csv"* ]]; then
      # Cut root directory from the path
      relative_path="${src_filepath#"$SRC_DIR"/}"
      # 2. Construct full destination path
      dest_filepath="$DEST_DIR/${relative_path}"
      if [ ! -d "$(dirname "$dest_filepath")" ];
      then
        mkdir -p "$(dirname "$dest_filepath")"
      fi

      echo "Moving existing CSV file: $src_filepath to $dest_filepath"

  
      mv "$src_filepath" "${dest_filepath}"
    continue
  fi


  echo "Parsing file: $src_filepath"

  # Cut root directory from the path
  relative_path="${src_filepath#"$SRC_DIR"/}"
  # 2. Construct full destination path
  dest_filepath="$DEST_DIR/${relative_path}.csv"

  if [ ! -d "$(dirname "$dest_filepath")" ];
  then
    # Make the file
    mkdir -p "$(dirname "$dest_filepath")"
  fi
  
  # CSV Header
  echo "start,end,seconds,bytes,bits_per_second,rtt,omitted,sender" > "$dest_filepath"

  # Extract and append interval data using jq
  jq -r '
    .intervals[]? as $i |
    $i.sum as $s |
    $i.streams[0] as $stream |
    [
      $s.start, $s.end, $s.seconds, $s.bytes, $s.bits_per_second, $stream.rtt, $s.omitted, $s.sender
    ] | @csv
  ' "$src_filepath" >> "$dest_filepath"
  
done

echo "Conversion complete."
