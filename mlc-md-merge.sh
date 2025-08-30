#!/usr/bin/env zsh
# zsh: avoid -e to prevent benign non-zero statuses from aborting
set -uo pipefail
IFS=$'\n\t'
export LC_ALL=C

# ---------- Exclusions ----------
EXCLUDES=(.git node_modules .venv)
PREFIX_EXCLUDES=(xxx yyy zzz)

# ---------- Counters ----------
total_md=0
total_txt=0
total_pdf=0
converted_pdf=0
skipped_pdf=0
bundles_created=0
bundles_removed_empty=0

# ---------- Helpers ----------
have_cmd() { command -v "$1" >/dev/null 2>&1 }

filter_images() {
  awk '!/!\[.*\]\(.*\)/ && !/^\[.*\]:[[:space:]]*<data:image.*/ { print }'
}

render_file() {
  local f="$1"
  local ext="${f##*.}"; ext="${ext:l}"
  case "$ext" in
    md|txt)
      if [[ "$ext" == md ]]; then (( total_md++ )); else (( total_txt++ )); fi
      filter_images < "$f" || true
      ;;
    pdf)
      (( total_pdf++ ))
      if have_cmd pdftotext; then
        if pdftotext -nopgbrk "$f" - 2>/dev/null; then
          (( converted_pdf++ ))
        else
          print -r -- "[pdftotext error reading $f]"
          (( skipped_pdf++ ))
        fi
      else
        print -r -- "[Skipping PDF, pdftotext not found: $f]"
        (( skipped_pdf++ ))
      fi
      ;;
    *)
      print -r -- "[Skipping unsupported file type: $f]"
      ;;
  esac
  return 0
}

safe_flat_name() {
  local name="$1"
  [[ -z "$name" ]] && { print -r -- "[warn] empty name passed to safe_flat_name, skipping"; print -r -- ""; return 0; }
  print -r -- "$name" \
    | sed 's|^\./||' \
    | sed 's|/|__|g' \
    | tr ' ' '_'
}

write_bundle() {
  # $1 = output; $@[2..] = files
  local out="$1"; shift
  : > "$out"
  for f in "$@"; do
    # Skip empty or non-regular paths defensively
    if [[ -z "$f" || ! -f "$f" ]]; then
      print -r -- "[warn] skipping invalid path: $f"
      continue
    fi
    print -r -- "Processing file: $f"
    printf "**File: %s**\n\n" "$f" >> "$out" || print -r -- "[warn] header write failed: $f"
    render_file "$f" >> "$out" || print -r -- "[warn] render failed: $f"
    printf "\n\n***\n\n" >> "$out" || print -r -- "[warn] separator write failed: $f"
  done
  if [[ ! -s "$out" ]]; then
    print -r -- "$out is empty and will be removed."
    rm -f -- "$out"
    (( bundles_removed_empty++ ))
  else
    print -r -- "Created bundle: $out"
    (( bundles_created++ ))
  fi
}

# ---------- Sorting: numbers-first natural order ----------
# Usage: sort_paths_array ARRAY_NAME
# Groups basenames starting with digits first, sorted by numeric prefix,
# then by the rest of the name (case-insensitive). Others follow A→Z (case-insensitive).
sort_paths_array() {
  local __name="$1"
  local -a in out lines sorted_lines
  local delim=$'\x1F'
  in=("${(@P)__name}")

  lines=()
  local f bn lower num rest rest_lower class numkey key3
  for f in "${in[@]}"; do
    [[ -z "$f" ]] && continue
    bn="${f:t}"                # basename
    lower="${bn:l}"
    num="${bn%%[^0-9]*}"       # leading digits; empty if none
    if [[ -n "$num" ]]; then
      class=0
      numkey="$num"            # numeric key for sort -n
      rest="${bn#$num}"        # remainder after numeric prefix
      rest_lower="${rest:l}"
      key3="$rest_lower"
    else
      class=1
      numkey=0                 # irrelevant for non-numeric group
      key3="$lower"
    fi
    lines+=("${class}${delim}${numkey}${delim}${key3}${delim}${f}")
  done

  sorted_lines=()
  while IFS= read -r line; do
    sorted_lines+=("$line")
  done < <(printf '%s\n' "${lines[@]}" | LC_ALL=C sort -t "$delim" -k1,1n -k2,2n -k3,3 -k4,4)

  out=()
  local fp
  for line in "${sorted_lines[@]}"; do
    fp="${line##*${delim}}"    # extract field 4 = full path
    [[ -n "$fp" ]] && out+=("$fp")
  done

  eval "$__name=(\"\${out[@]}\")"
}

# Collect top-level directories, excluding names and prefixes
collect_top_level_dirs() {
  local __arr_name="$1"
  local -a tmp=()
  local -a negs=()
  for n in "${EXCLUDES[@]}"; do negs+=( ! -name "$n" ); done
  for p in "${PREFIX_EXCLUDES[@]}"; do negs+=( ! -name "${p}*" ); done

  while IFS= read -r -d $'\0' x; do
    x="${x#./}"
    [[ -z "$x" ]] && continue
    tmp+=("$x")
  done < <(find . -mindepth 1 -maxdepth 1 -type d "${negs[@]}" -print0)

  eval "$__arr_name=(\"\${tmp[@]}\")"
}

# Collect subdirectories under $2, pruning excluded dirs
collect_subdirs_array() {
  local __arr_name="$1"; local root="$2"
  local -a tmp=()
  while IFS= read -r -d $'\0' x; do
    [[ -z "$x" ]] && continue
    tmp+=("$x")
  done < <(find "$root" \
      \( -type d \( -name .git -o -name node_modules -o -name .venv -o -name 'xxx*' -o -name 'yyy*' -o -name 'zzz*' \) -prune -false \) \
      -o -type d -mindepth 1 -print0)
  eval "$__arr_name=(\"\${tmp[@]}\")"
}

# Collect files under $2, pruning excluded dirs
collect_files_under_array() {
  local __arr_name="$1"; local root="$2"
  local -a tmp=()
  while IFS= read -r -d $'\0' x; do
    [[ -z "$x" ]] && continue
    tmp+=("$x")
  done < <(find "$root" \
      \( -type d \( -name .git -o -name node_modules -o -name .venv -o -name 'xxx*' -o -name 'yyy*' -o -name 'zzz*' \) -prune -false \) \
      -o -type f \( -iname '*.md' -o -iname '*.txt' -o -iname '*.pdf' \) -print0)
  eval "$__arr_name=(\"\${tmp[@]}\")"
}

# ---------- Cleanup old bundles ----------
{
  local -a old=(000-*.txt(N))
  if (( ${#old} > 0 )); then
    print -r -- "Removing ${#old} old bundle(s)."
    rm -f -- "${old[@]}"
  fi
} 2>/dev/null

# ---------- Main ----------
local -a DIRECTORIES=()
collect_top_level_dirs DIRECTORIES
sort_paths_array DIRECTORIES

for dir in "${DIRECTORIES[@]}"; do
  [[ -z "$dir" ]] && { print -r -- "[warn] skipping empty dir name"; continue; }
  if [[ ! -d "$dir" ]]; then
    print -r -- "Directory $dir does not exist."
    continue
  fi

  # 1) Merge top-level files
  local -a topfiles=()
  while IFS= read -r -d $'\0' f; do
    [[ -z "$f" ]] && continue
    topfiles+=("$f")
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f \( -iname '*.md' -o -iname '*.txt' -o -iname '*.pdf' \) -print0)
  sort_paths_array topfiles

  if (( ${#topfiles} > 0 )); then
    top_out="000-${dir}.txt"
    write_bundle "$top_out" "${topfiles[@]}"
  else
    print -r -- "No top-level files to merge in $dir."
  fi

  # 2) One merged file per subdirectory
  local -a subdirs=()
  collect_subdirs_array subdirs "$dir"
  sort_paths_array subdirs

  for subdir in "${subdirs[@]}"; do
    [[ -z "$subdir" ]] && continue
    local -a subfiles=()
    collect_files_under_array subfiles "$subdir"
    sort_paths_array subfiles
    (( ${#subfiles} == 0 )) && continue

    local safe
    safe="$(safe_flat_name "$subdir")"
    [[ -z "$safe" ]] && { print -r -- "[warn] skipped bundle with empty safe name for $subdir"; continue; }

    sub_out="000-${safe}.txt"
    write_bundle "$sub_out" "${subfiles[@]}"
  done
done

# ---------- Summary ----------
print
print "========== Merge Summary =========="
printf "Markdown files processed:   %d\n" "$total_md"
printf "Text files processed:       %d\n" "$total_txt"
printf "PDF files found:            %d\n" "$total_pdf"
printf "PDFs converted:             %d\n" "$converted_pdf"
printf "PDFs skipped:               %d\n" "$skipped_pdf"
printf "Output bundles created:     %d\n" "$bundles_created"
printf "Empty bundles removed:      %d\n" "$bundles_removed_empty"
print "==================================="
