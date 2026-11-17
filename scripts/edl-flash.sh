#!/usr/bin/env bash
# Write one partition over EDL, read it back, compare, reboot.
# Usage: scripts/edl-flash.sh <partition> <image>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDL="$ROOT/tools/venv/bin/edl"
LD="--loader=$ROOT/tools/loaders/0000000000000000_bdaf51b59ba21d8a_fhprg.bin"
PART="$1"; IMG="$2"
RB="$(mktemp -t readback).bin"

if adb get-state >/dev/null 2>&1; then adb reboot edl; sleep 8; fi
"$EDL" w "$PART" "$IMG" "$LD" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'Wrote|rror' || true
"$EDL" r "$PART" "$RB" "$LD" >/dev/null 2>&1
if [ "$(shasum -a 256 < "$IMG")" = "$(shasum -a 256 < "$RB")" ]; then
  echo "READBACK MATCH"; rm -f "$RB"
else
  echo "READBACK MISMATCH — device left in EDL. Readback: $RB"; exit 1
fi
"$EDL" reset "$LD" >/dev/null 2>&1 || true
T="$(command -v timeout || command -v gtimeout || true)"
${T:+$T 240} adb wait-for-device
adb shell 'n=0; while [ "$(getprop sys.boot_completed)" != 1 ] && [ $n -lt 90 ]; do sleep 2; n=$((n+1)); done; echo boot_completed=$(getprop sys.boot_completed)'
