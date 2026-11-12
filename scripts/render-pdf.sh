#!/usr/bin/env bash
# Render an editor brief HTML file to PDF with Chrome or Chromium headless.
# Usage: scripts/render-pdf.sh <brief.html> <brief.pdf>
# Binary lookup: CHROME in the environment, CHROME in ./.env, the standard macOS app paths,
# then google-chrome, google-chrome-stable, chromium, chromium-browser, chrome on PATH.
# Chrome accepts single-dash switches, so the flags below are written that way.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <input.html> <output.pdf>" >&2
  exit 1
fi

IN="$1"
OUT="$2"
CHROME="${CHROME:-}"

if [ -z "$CHROME" ] && [ -f ".env" ]; then
  CHROME="$(grep -E '^CHROME=' .env | head -1 | cut -d= -f2- | tr -d '"' || true)"
fi
if [ -z "$CHROME" ]; then
  for cand in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    [ -x "$cand" ] && { CHROME="$cand"; break; }
  done
fi
if [ -z "$CHROME" ]; then
  for name in google-chrome google-chrome-stable chromium chromium-browser chrome; do
    command -v "$name" >/dev/null 2>&1 && { CHROME="$(command -v "$name")"; break; }
  done
fi

if [ -z "$CHROME" ] || [ ! -x "$CHROME" ]; then
  echo "No Chrome or Chromium found. Set CHROME=<path to the binary> in .env or the environment, or install Chrome." >&2
  echo "Until then, ship the HTML and say in the QA list that the PDF was not rendered." >&2
  exit 2
fi

if [ ! -f "$IN" ]; then
  echo "input not found: $IN" >&2
  exit 3
fi

# Chrome needs an absolute file URL.
ABS_IN="$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"
ABS_OUT="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd || pwd)/$(basename "$OUT")"

"$CHROME" -headless -disable-gpu -no-pdf-header-footer -print-to-pdf="$ABS_OUT" "file://$ABS_IN" 2>/dev/null

if [ ! -s "$ABS_OUT" ]; then
  echo "render failed: no PDF written" >&2
  exit 4
fi

# Page count: Spotlight metadata on macOS when indexed, otherwise count page objects in the file.
PAGES="$(mdls -name kMDItemNumberOfPages -raw "$ABS_OUT" 2>/dev/null || true)"
if [ -z "$PAGES" ] || [ "$PAGES" = "(null)" ]; then
  PAGES="$(strings "$ABS_OUT" | grep -c '/Type /Page$' || true)"
  [ "$PAGES" = "0" ] && PAGES="unknown, open the PDF to check"
fi
echo "wrote $ABS_OUT ($PAGES pages)"
