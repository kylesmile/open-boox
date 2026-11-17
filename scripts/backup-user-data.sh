#!/usr/bin/env bash
# Copy shared storage and installed app APKs. Read-only on the device.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/backups/$(date +%Y%m%d-%H%M%S)-userdata"
mkdir -p "$OUT/sdcard" "$OUT/apks"
adb wait-for-device

echo "== /sdcard (notes, books, screenshots, downloads)"
adb pull -a /sdcard/. "$OUT/sdcard/"

echo "== APKs for user-installed apps"
adb shell pm list packages -3 | sed 's/^package://' | tr -d '\r' > "$OUT/packages-user.txt"
while read -r pkg; do
  mkdir -p "$OUT/apks/$pkg"
  adb shell -n pm path "$pkg" | sed 's/^package://' | tr -d '\r' | while read -r apk; do
    adb pull "$apk" "$OUT/apks/$pkg/" </dev/null >/dev/null
  done
done < "$OUT/packages-user.txt"

echo "Saved to $OUT ($(du -sh "$OUT" | cut -f1))"
echo "App private data (/data/data) needs root; export notes from the Notes app before wiping."
