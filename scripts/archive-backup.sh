#!/usr/bin/env bash
# Pack a backup folder into <folder>.tar.gz next to it, test it, and write
# <folder>.tar.gz.sha256. The other backup scripts call this when they finish.
# Usage: scripts/archive-backup.sh backups/<timestamp>-<kind>
set -euo pipefail
DIR="$(cd "$1" && pwd)"
NAME="$(basename "$DIR")"
PARENT="$(dirname "$DIR")"
ARCHIVE="$PARENT/$NAME.tar.gz"

GZ=gzip
command -v pigz >/dev/null && GZ=pigz

echo "== Writing $NAME.tar.gz ($GZ)"
tar -C "$PARENT" -cf - "$NAME" | "$GZ" > "$ARCHIVE.part"
"$GZ" -t "$ARCHIVE.part"
mv "$ARCHIVE.part" "$ARCHIVE"
(cd "$PARENT" && shasum -a 256 "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
echo "Archive: $ARCHIVE ($(du -sh "$ARCHIVE" | cut -f1))"
