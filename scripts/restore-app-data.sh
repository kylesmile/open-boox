#!/usr/bin/env bash
# Restore app private data saved by backup-app-data.sh. Needs root. WRITES to
# the tablet: each app's current data is replaced by the backup.
#
# Usage: scripts/restore-app-data.sh <appdata-folder> [package ...]
#   <appdata-folder>: backups/<timestamp>-appdata, or backups/<timestamp>/appdata
#   No packages: every app in the backup.
# The app must be installed. If it is not, and the backup came from backup.sh,
# the APKs are installed from the userdata/apks folder next to it.
# Checks every file's hash, owner, mode and label after restoring.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(cd "${1:?usage: $0 <appdata-folder> [package ...]}" && pwd)"; shift
R="$ROOT/scripts/root.sh"
TMP=/data/local/tmp/open-boox-appdata

adb wait-for-device
[ "$("$R" id -u </dev/null | tr -d '\r')" = 0 ] || { echo "No root. See docs/root.md."; exit 1; }
if [ $# -gt 0 ]; then PKGS=("$@"); else PKGS=($(ls "$SRC/apps")); fi

adb push "$ROOT/scripts/appdata-on-device.sh" /data/local/tmp/ >/dev/null 2>&1
# Owned by shell so adb push can write into it; root writes there too.
"$R" "rm -rf $TMP; mkdir -p $TMP; chown shell:shell $TMP" </dev/null

FAIL=0
for pkg in "${PKGS[@]}"; do
  echo "== $pkg"
  D="$SRC/apps/$pkg"
  [ -f "$D/$pkg.tar" ] || { echo "   not in this backup"; FAIL=1; continue; }

  if ! adb shell pm path "$pkg" </dev/null >/dev/null 2>&1; then
    APKS="$SRC/../userdata/apks/$pkg"
    if ls "$APKS"/*.apk >/dev/null 2>&1; then
      echo "   installing from $APKS"
      adb install-multiple "$APKS"/*.apk </dev/null
    else
      echo "   not installed, and no APKs found; install it first"; FAIL=1; continue
    fi
  fi
  installed="$(adb shell dumpsys package "$pkg" </dev/null 2>/dev/null | grep -m1 -oE 'versionCode=[0-9]+' || true)"
  saved="$(grep -m1 versionCode "$D/$pkg.info" || true)"
  [ "$installed" = "$saved" ] || echo "   note: backup has $saved, tablet has $installed"

  for f in tar files sha256 info; do
    adb push "$D/$pkg.$f" "$TMP/" </dev/null >/dev/null 2>&1 || { echo "   push of $pkg.$f failed"; FAIL=1; continue 2; }
  done
  want="$(shasum -a 256 "$D/$pkg.tar" | cut -d' ' -f1)"
  got="$("$R" "sha256sum $TMP/$pkg.tar" </dev/null | cut -d' ' -f1)"
  [ "$want" = "$got" ] || { echo "   copy to tablet failed"; FAIL=1; continue; }

  "$R" "sh /data/local/tmp/appdata-on-device.sh restore $pkg $TMP" </dev/null | sed 's/^/   /' || FAIL=1
  "$R" "rm -f $TMP/$pkg.*" </dev/null
done
"$R" "rm -rf $TMP /data/local/tmp/appdata-on-device.sh" </dev/null

[ "$FAIL" = 0 ] && echo "Done. Open each app to check it." || echo "WARNING: some apps failed; see above."
exit "$FAIL"
