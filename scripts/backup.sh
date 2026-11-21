#!/usr/bin/env bash
# Full backup in one go: device snapshot, user data, app private data (only
# when rooted, see docs/root.md), then the EDL dump, all in
# backups/<timestamp>/, packed into one backups/<timestamp>.tar.gz with one
# backups/<timestamp>.tar.gz.sha256. Reads only from the tablet.
# Usage: scripts/backup.sh                  (EDL dump includes userdata)
#        SKIP_USERDATA=1 scripts/backup.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$ROOT/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TOP"

echo "==== 1/4 Device snapshot"
BACKUP_OUT="$TOP/info" "$ROOT/scripts/device-info.sh"

# A hash mismatch here is often just a log that changed mid-copy, so keep going
# and report it at the end.
echo "==== 2/4 User data"
FAIL=0
BACKUP_OUT="$TOP/userdata" "$ROOT/scripts/backup-user-data.sh" || FAIL=1

echo "==== 3/4 App data"
if [ "$("$ROOT/scripts/root.sh" id -u </dev/null 2>/dev/null | tr -d '\r')" = 0 ]; then
  BACKUP_OUT="$TOP/appdata" "$ROOT/scripts/backup-app-data.sh" || FAIL=1
else
  echo "Not rooted; skipped. App private data needs root (docs/root.md)."
fi

echo "==== 4/4 EDL dump"
BACKUP_OUT="$TOP/edl" "$ROOT/scripts/edl-dump.sh"

"$ROOT/scripts/archive-backup.sh" "$TOP"
echo "Copy these two files to another drive:"
echo "  $TOP.tar.gz"
echo "  $TOP.tar.gz.sha256"
[ "$FAIL" = 0 ] || echo "WARNING: user or app data had problems; see steps 2/4 and 3/4 above."
exit "$FAIL"
