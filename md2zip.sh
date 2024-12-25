#!/bin/zsh

# Specify the directory to start searching (current directory by default)
start_dir="."

# Name of the resulting zip file
output_zip="markdown_files.zip"

# Find all Markdown files and compress them into a zip
find "$start_dir" -type f \( -name "*.md" -o -name "*.markdown" \) | zip "$output_zip" -@

echo "All Markdown files have been compressed into $output_zip"