#!/usr/bin/env bash
# Full raw dump of every partition over Qualcomm EDL, then a .tar.gz of the
# folder. Reads only.
# Usage: scripts/edl-dump.sh            (includes userdata)
#        SKIP_USERDATA=1 scripts/edl-dump.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDL="$ROOT/tools/venv/bin/edl"
LOADER="$ROOT/tools/loaders/0000000000000000_bdaf51b59ba21d8a_fhprg.bin"
# backup.sh sets BACKUP_OUT to collect every part in one folder and one archive.
OUT="${BACKUP_OUT:-$ROOT/backups/$(date +%Y%m%d-%H%M%S)-edl}"
mkdir -p "$OUT"

if adb get-state >/dev/null 2>&1; then
  echo "Rebooting to EDL (screen may go nearly black; that's normal)..."
  adb reboot edl
fi
sleep 5

"$EDL" printgpt --loader="$LOADER" | tee "$OUT/gpt.txt"

SKIP=()
[ "${SKIP_USERDATA:-0}" = 1 ] && SKIP=(--skip=userdata)
"$EDL" rl "$OUT" --loader="$LOADER" --genxml ${SKIP[@]+"${SKIP[@]}"}

(cd "$OUT" && find . -name "*.bin" -o -name "*.xml" | sort | xargs shasum -a 256 > SHA256SUMS)
echo "Dump in $OUT. Rebooting device."
"$EDL" reset --loader="$LOADER" || echo "Reset failed; hold power to reboot."
[ -n "${BACKUP_OUT:-}" ] || "$ROOT/scripts/archive-backup.sh" "$OUT"
