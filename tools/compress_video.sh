#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 input output.mp4" >&2
  exit 2
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found" >&2
  exit 1
fi

ffmpeg -y -i "$1" \
  -vf "scale='min(1280,iw)':-2" \
  -c:v libx264 -crf 28 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 96k \
  -movflags +faststart \
  "$2"

size=$(stat -c %s "$2")
echo "$2: $((size / 1024 / 1024)) MB"
if [ "$size" -gt $((60 * 1024 * 1024)) ]; then
  echo "over 60 MB limit" >&2
  exit 3
fi
