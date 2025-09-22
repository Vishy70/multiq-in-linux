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
  if [[ "$src_filepath" != *".txt" ]]; then
    continue
  fi

  echo "Parsing file: $src_filepath"

  # Cut root directory from the path
  relative_path="${src_filepath#"$SRC_DIR"/}"
  # 2. Construct full destination path
  dest_filepath="$DEST_DIR/${relative_path%.*}.csv"

  # Make the file
  mkdir -p "$(dirname "$dest_filepath")"
  
  python3 ./csv-tools/parse-ping.py "$src_filepath" "$dest_filepath"
  
  
done

echo "Conversion complete."
