#!/usr/bin/env bash
# Copy app private data as root: /data/data, /data/user_de and the app's
# /data/media folders, without caches, with a record of every file's owner,
# mode and SELinux label. Needs root (docs/root.md). Reads only, apart from
# stopping each app while it is copied and a temp folder in /data/local/tmp.
#
# Usage: scripts/backup-app-data.sh [package ...]
#   No packages: user-installed apps plus the Boox apps in BOOX_APPS.
# Restore with scripts/restore-app-data.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# backup.sh sets BACKUP_OUT to collect every part in one folder and one archive.
OUT="${BACKUP_OUT:-$ROOT/backups/$(date +%Y%m%d-%H%M%S)-appdata}"
R="$ROOT/scripts/root.sh"
TMP=/data/local/tmp/open-boox-appdata
# Notes, reader, launcher/library, dictionary, touch calibration, recorder, sync.
BOOX_APPS="${BOOX_APPS:-com.onyx com.onyx.android.note com.onyx.kreader com.onyx.dict com.onyx.tscalibration com.onyx.voicerecorder com.onyx.android.ksync}"

adb wait-for-device
[ "$("$R" id -u </dev/null | tr -d '\r')" = 0 ] || { echo "No root. See docs/root.md."; exit 1; }
mkdir -p "$OUT/apps"

if [ $# -gt 0 ]; then
  printf '%s\n' "$@" > "$OUT/packages.txt"
else
  { adb shell pm list packages -3 </dev/null | sed 's/^package://' | tr -d '\r' | grep -vx com.topjohnwu.magisk
    printf '%s\n' $BOOX_APPS; } > "$OUT/packages.txt"
fi

adb push "$ROOT/scripts/appdata-on-device.sh" /data/local/tmp/ >/dev/null 2>&1
# Owned by shell so adb push can write into it; root writes there too.
"$R" "rm -rf $TMP; mkdir -p $TMP; chown shell:shell $TMP" </dev/null

FAIL=0
while read -r pkg <&3; do
  echo "== $pkg"
  rc=0
  "$R" "sh /data/local/tmp/appdata-on-device.sh backup $pkg $TMP" </dev/null || rc=$?
  [ "$rc" = 3 ] && continue
  [ "$rc" = 0 ] || { echo "   backup failed ($rc)"; FAIL=1; continue; }
  mkdir -p "$OUT/apps/$pkg"
  # adb pull, not exec-out cat: exec-out stalled for hours on a large tar.
  for f in tar files sha256 info; do
    adb pull "$TMP/$pkg.$f" "$OUT/apps/$pkg/" </dev/null >/dev/null 2>&1 \
      || { echo "   pull of $pkg.$f failed"; FAIL=1; continue 2; }
  done
  want="$("$R" "sha256sum $TMP/$pkg.tar" </dev/null | cut -d' ' -f1)"
  got="$(shasum -a 256 "$OUT/apps/$pkg/$pkg.tar" | cut -d' ' -f1)"
  if [ "$want" = "$got" ]; then
    echo "$got  $pkg/$pkg.tar" >> "$OUT/SHA256SUMS"
    echo "   $(wc -l < "$OUT/apps/$pkg/$pkg.files" | tr -d ' ') entries, $(du -h "$OUT/apps/$pkg/$pkg.tar" | cut -f1)"
  else
    echo "   copy mismatch"; FAIL=1
  fi
  "$R" "rm -f $TMP/$pkg.*" </dev/null
done 3< "$OUT/packages.txt"
"$R" "rm -rf $TMP /data/local/tmp/appdata-on-device.sh" </dev/null

echo "Saved to $OUT ($(du -sh "$OUT" | cut -f1))"
[ -n "${BACKUP_OUT:-}" ] || "$ROOT/scripts/archive-backup.sh" "$OUT"
[ "$FAIL" = 0 ] || echo "WARNING: some apps failed; see above."
exit "$FAIL"
