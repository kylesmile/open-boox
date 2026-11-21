#!/usr/bin/env bash
# Full backup in one go: device snapshot, user data, then the EDL dump, all in
# backups/<timestamp>/, packed into one backups/<timestamp>.tar.gz with one
# backups/<timestamp>.tar.gz.sha256. Reads only from the tablet.
# Usage: scripts/backup.sh                  (EDL dump includes userdata)
#        SKIP_USERDATA=1 scripts/backup.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$ROOT/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TOP"

echo "==== 1/3 Device snapshot"
BACKUP_OUT="$TOP/info" "$ROOT/scripts/device-info.sh"

# A hash mismatch here is often just a log that changed mid-copy, so keep going
# and report it at the end.
echo "==== 2/3 User data"
FAIL=0
BACKUP_OUT="$TOP/userdata" "$ROOT/scripts/backup-user-data.sh" || FAIL=1

echo "==== 3/3 EDL dump"
BACKUP_OUT="$TOP/edl" "$ROOT/scripts/edl-dump.sh"

"$ROOT/scripts/archive-backup.sh" "$TOP"
echo "Copy these two files to another drive:"
echo "  $TOP.tar.gz"
echo "  $TOP.tar.gz.sha256"
[ "$FAIL" = 0 ] || echo "WARNING: user data had hash mismatches; see step 2/3 above."
exit "$FAIL"
