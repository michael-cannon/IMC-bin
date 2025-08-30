#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Optional: enforce a predictable sort
export LC_ALL=C

# Check for a command
have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Filter out Markdown image lines or inline base64 images
filter_images() {
  grep -vE '!\[.*\]\(.*\)|^\[.*\]:\s*<data:image.*>'
}

# Render a file to stdout:
# - .md and .txt are passed through filter_images
# - .pdf is converted with pdftotext (if available)
render_file() {
  local f="$1"
  case "${f##*.}" in
    md|MD|Md|mD)
      filter_images < "$f"
      ;;
    txt|TXT|Txt)
      filter_images < "$f"
      ;;
    pdf|PDF|Pdf)
      if have_cmd pdftotext; then
        # -nopgbrk avoids ^L page breaks; drop -layout unless you need exact positioning
        pdftotext -nopgbrk "$f" - 2>/dev/null || echo "[pdftotext error reading $f]"
      else
        echo "[Skipping PDF, pdftotext not found: $f]"
      fi
      ;;
    *)
      echo "[Skipping unsupported file type: $f]"
      ;;
  esac
}

DIRECTORIES=("About" "Articles" "Resources")

for dir in "${DIRECTORIES[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "Directory $dir does not exist."
    continue
  fi

  ##############################
  # 1) Merge top-level files
  ##############################
  top_out="000-${dir}.txt"
  : > "$top_out"

  # Direct children only, include .md .txt .pdf
  find "$dir" -mindepth 1 -maxdepth 1 -type f \( -iname '*.md' -o -iname '*.txt' -o -iname '*.pdf' \) -print0 \
  | sort -z \
  | while IFS= read -r -d '' file; do
      echo "Processing top-level file: $file"
      printf "**File: %s**\n\n" "$file" >> "$top_out"
      render_file "$file" >> "$top_out"
      printf "\n\n***\n\n" >> "$top_out"
    done

  if [[ ! -s "$top_out" ]]; then
    echo "$top_out is empty and will be removed."
    rm -f "$top_out"
  else
    echo "Merged top-level files in $dir into $top_out."
  fi

  ############################################
  # 2) One merged file per subdirectory
  ############################################
  find "$dir" -type d -mindepth 1 -print0 \
  | sort -z \
  | while IFS= read -r -d '' subdir; do
      # Flatten path to filename: About__Guides, Articles__2025_Q1, etc.
      safe_name="$(printf "%s" "$subdir" \
        | sed 's|^\./||' \
        | sed 's|/|__|g' \
        | tr ' ' '_' )"

      sub_out="000-${safe_name}.txt"
      : > "$sub_out"

      # All files under this subdir, any depth
      find "$subdir" -type f \( -iname '*.md' -o -iname '*.txt' -o -iname '*.pdf' \) -print0 \
      | sort -z \
      | while IFS= read -r -d '' file; do
          echo "Processing subdir file: $file"
          printf "**File: %s**\n\n" "$file" >> "$sub_out"
          render_file "$file" >> "$sub_out"
          printf "\n\n***\n\n" >> "$sub_out"
        done

      if [[ ! -s "$sub_out" ]]; then
        echo "$sub_out is empty and will be removed."
        rm -f "$sub_out"
      else
        echo "Merged files in $subdir into $sub_out."
      fi
    done
done
