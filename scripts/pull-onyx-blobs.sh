#!/usr/bin/env bash
# Copy Boox's e-ink binaries off the tablet for study. Reads only.
# Output: firmware/onyx-blobs/ plus SHA256SUMS (checked against the device).
#
# Most files are world-readable. surfaceflinger, charger and npu_launcher are
# root-only, so they go through scripts/root.sh (needs a rooted tablet).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/firmware/onyx-blobs"
mkdir -p "$OUT"
adb wait-for-device

READABLE="/system/framework/framework.jar /system_ext/lib64/libmsp.so
$(adb shell 'ls /system/lib64/libonyx_*.so /system/lib64/libmmkv-onyx.so' | tr -d '\r')"
ROOT_ONLY="/system/bin/surfaceflinger /system/bin/charger /vendor/bin/npu_launcher"

: > "$OUT/SHA256SUMS"
fetch() {  # <device path> <device path to read from>
  local name; name="$(basename "$1")"
  # adb pull silently skips some /system files; exec-out cat does not.
  adb exec-out cat "$2" > "$OUT/$name"
  local want; want="$(adb shell sha256sum "$2" | cut -d' ' -f1)"
  local got; got="$(shasum -a 256 "$OUT/$name" | cut -d' ' -f1)"
  [ "$want" = "$got" ] || { echo "Copy mismatch: $1"; exit 1; }
  echo "$got  $1" | tee -a "$OUT/SHA256SUMS"
}

for f in $READABLE; do fetch "$f" "$f"; done

if adb shell 'run-as com.topjohnwu.magisk true' 2>/dev/null; then
  for f in $ROOT_ONLY; do
    tmp="/data/local/tmp/$(basename "$f")"
    "$ROOT/scripts/root.sh" "cp $f $tmp && chmod 644 $tmp"
    fetch "$f" "$tmp"
    adb shell rm -f "$tmp"
  done
else
  echo "Skipped root-only files ($ROOT_ONLY): root first (docs/root.md)."
fi
echo "Saved to $OUT"
