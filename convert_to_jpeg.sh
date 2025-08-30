#!/bin/bash

# Directory where the script is run
DIR="${1:-.}"

# Create an output directory
OUTPUT_DIR="$DIR/converted_jpegs"
mkdir -p "$OUTPUT_DIR"

# Loop through all images in the directory
for file in "$DIR"/*.{png,heic,tiff,bmp,gif,jpeg,jpg}; do
    # Check if the file exists (handles the case where no images match)
    [ -e "$file" ] || continue

    # Extract filename without extension
    filename=$(basename -- "$file")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # Convert to JPEG
    output_file="$OUTPUT_DIR/${filename}_converted.jpg"
    sips -s format jpeg "$file" --out "$output_file"

    echo "Converted: $file -> $output_file"
done

echo "Conversion complete! All JPEGs saved in $OUTPUT_DIR"
