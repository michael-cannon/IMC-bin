#!/bin/sh

# Function to filter out lines that contain Markdown image syntax or inline base64 images
filter_images() {
    # Filter out lines that match: ![...](...) or [imageX]: <data:image...>
    grep -vE '!\[.*\]\(.*\)|^\[.*\]:\s*<data:image.*>'
}

# Directories to search for Markdown files
DIRECTORIES=("Articles" "Handbook" "Marketing" "Processes" "Products" "Resources" "Sales")

# Loop through each directory
for dir in "${DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        # Output file for this specific directory
        OUTPUT_FILE="000-${dir}.md.txt"
        
        # Clear the output file or create a new one
        > $OUTPUT_FILE

        # Find all Markdown files in the directory and its subdirectories
        find "$dir" -name "*.md" ! -name "$OUTPUT_FILE" -print0 | sort -zV | while IFS= read -r -d '' file; do
            echo "Processing file: $file"
            # Add the file name as a header in the output file (optional)
            echo "**File: $file**\n\n" >> $OUTPUT_FILE
            # Append the content of the file to the output file while filtering out image lines
            filter_images < "$file" >> $OUTPUT_FILE
            # Add a blank line to separate the content of different files
            echo "\n\n***\n\n" >> $OUTPUT_FILE
        done

        # Remove the file if it is empty
        if [ ! -s "$OUTPUT_FILE" ]; then
            echo "$OUTPUT_FILE is empty and will be removed."
            rm "$OUTPUT_FILE"
		else
	        echo "Markdown files in $dir have been merged into $OUTPUT_FILE."
        fi

    else
        echo "Directory $dir does not exist."
    fi
done