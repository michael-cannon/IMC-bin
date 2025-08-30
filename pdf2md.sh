#!/bin/bash

# macOS: brew install poppler
# Debian/Ubuntu: sudo apt-get install poppler-utils

mkdir -p md
for f in *.pdf; do
  [ -e "$f" ] || continue
  b="${f%.pdf}"
  pdftotext -layout -enc UTF-8 "$f" "md/${b}.md"
done