#!/usr/bin/env bash
# Copy shared storage and installed app APKs, check every file's hash against
# the tablet, then write a .tar.gz of the folder. Read-only on the device.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# backup.sh sets BACKUP_OUT to collect every part in one folder and one archive.
OUT="${BACKUP_OUT:-$ROOT/backups/$(date +%Y%m%d-%H%M%S)-userdata}"
mkdir -p "$OUT/sdcard" "$OUT/apks"
adb wait-for-device

echo "== /sdcard (notes, books, screenshots, downloads)"
adb pull -a /sdcard/. "$OUT/sdcard/" | tail -1
# Hashes from the tablet, checked against the copy. Toybox find's -exec {} +
# overflows the argument list on a full /sdcard, so batch through xargs.
adb exec-out 'cd /sdcard/ && find . -type f -print0 | xargs -0 -n 200 sha256sum 2>/dev/null' > "$OUT/sdcard.sha256"

echo "== APKs for user-installed apps"
adb shell pm list packages -3 | sed 's/^package://' | tr -d '\r' > "$OUT/packages-user.txt"
: > "$OUT/apks.sha256"
while read -r pkg; do
  mkdir -p "$OUT/apks/$pkg"
  # adb pull, not exec-out cat: back-to-back exec-out calls sometimes hang
  # here. The hash check below catches a pull that silently skips a file.
  adb shell -n pm path "$pkg" | sed 's/^package://' | tr -d '\r' | while read -r apk; do
    adb pull "$apk" "$OUT/apks/$pkg/" </dev/null >/dev/null 2>&1
    sum="$(adb shell -n sha256sum "$apk" | cut -d' ' -f1)"
    echo "$sum  $pkg/$(basename "$apk")" >> "$OUT/apks.sha256"
  done
done < "$OUT/packages-user.txt"

echo "== Checking hashes"
FAIL=0
(cd "$OUT/sdcard" && shasum -a 256 -c --quiet ../sdcard.sha256) || FAIL=1
(cd "$OUT/apks" && shasum -a 256 -c --quiet ../apks.sha256) || FAIL=1
n_sd="$(wc -l < "$OUT/sdcard.sha256" | tr -d ' ')"
n_apk="$(wc -l < "$OUT/apks.sha256" | tr -d ' ')"
local_sd="$(find "$OUT/sdcard" -type f | wc -l | tr -d ' ')"
local_apk="$(find "$OUT/apks" -type f | wc -l | tr -d ' ')"
echo "Checked $n_sd of $local_sd files in /sdcard, $n_apk of $local_apk APKs."
if [ "$n_sd" != "$local_sd" ] || [ "$n_apk" != "$local_apk" ]; then
  echo "WARNING: hash list and copy have different file counts."
  FAIL=1
fi
[ "$FAIL" = 0 ] || echo "WARNING: hash mismatches above. Files that changed during the copy (app caches, logs) show up here."

echo "Saved to $OUT ($(du -sh "$OUT" | cut -f1))"
[ -n "${BACKUP_OUT:-}" ] || "$ROOT/scripts/archive-backup.sh" "$OUT"
echo "App private data (/data/data) needs root; export notes from the Notes app before wiping."
exit "$FAIL"
