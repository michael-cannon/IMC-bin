#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Filter out lines that contain Markdown image syntax or inline base64 images
filter_images() {
  grep -vE '!\[.*\]\(.*\)|^\[.*\]:\s*<data:image.*>'
}

DIRECTORIES=("About" "Articles" "Resources")

for dir in "${DIRECTORIES[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "Directory $dir does not exist."
    continue
  fi

  ##############################
  # 1) Merge top-level .md files
  ##############################
  top_out="000-${dir}.md.txt"
  : > "$top_out"

  # Only files directly under $dir, not in subfolders
  find "$dir" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print0 \
  | sort -z \
  | while IFS= read -r -d '' md; do
      echo "Processing top-level file: $md"
      printf "**File: %s**\n\n" "$md" >> "$top_out"
      filter_images < "$md" >> "$top_out"
      printf "\n\n***\n\n" >> "$top_out"
    done

  if [[ ! -s "$top_out" ]]; then
    echo "$top_out is empty and will be removed."
    rm -f "$top_out"
  else
    echo "Merged top-level Markdown in $dir into $top_out."
  fi

  ############################################
  # 2) Create one merged file per subdirectory
  ############################################
  find "$dir" -type d -mindepth 1 -print0 \
  | sort -z \
  | while IFS= read -r -d '' subdir; do
      # Create a safe, flat filename: About__Guides, Articles__2025_Q1, etc.
      safe_name="$(printf "%s" "$subdir" \
        | sed 's|^\./||' \
        | sed 's|/|__|g' \
        | tr ' ' '_' )"

      sub_out="000-${safe_name}.md.txt"
      : > "$sub_out"

      find "$subdir" -type f -name '*.md' -print0 \
      | sort -z \
      | while IFS= read -r -d '' md; do
          echo "Processing subdir file: $md"
          printf "**File: %s**\n\n" "$md" >> "$sub_out"
          filter_images < "$md" >> "$sub_out"
          printf "\n\n***\n\n" >> "$sub_out"
        done

      if [[ ! -s "$sub_out" ]]; then
        echo "$sub_out is empty and will be removed."
        rm -f "$sub_out"
      else
        echo "Merged Markdown in $subdir into $sub_out."
      fi
    done
done
