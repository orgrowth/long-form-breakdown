#!/usr/bin/env bash
# Download the first two minutes of a reference video for screenshots, at 1080p or lower.
# Usage: scripts/fetch-reference.sh <url> <out-dir>
# Writes <out-dir>/<video id>.mp4 and a contact sheet <out-dir>/<video id>-sheet.jpg (one frame every two seconds).
# yt-dlp's long options have no single-dash form; this is the one place they are written out.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <url> <out-dir>" >&2
  exit 1
fi

URL="$1"
OUT="$2"
mkdir -p "$OUT"

yt-dlp -q \
  --extractor-args "youtube:player_client=android,web_safari" \
  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
  --download-sections "*0-120" \
  --force-keyframes-at-cuts \
  --merge-output-format mp4 \
  -o "$OUT/%(id)s.%(ext)s" \
  "$URL"

for f in "$OUT"/*.mp4; do
  [ -f "$f" ] || continue
  base="${f%.mp4}"
  [ -f "$base-sheet.jpg" ] && continue
  ffmpeg -v error -y -i "$f" -vf "fps=1/2,scale=320:-1,tile=8x8" -frames:v 1 "$base-sheet.jpg"
  echo "sheet: $base-sheet.jpg"
done
