#!/usr/bin/env bash
# Root a stock tablet: install the Magisk v30.6 debug app, stage its install
# folder, and patch a stock boot image on the device. Does NOT flash.
#
# Usage: scripts/magisk-patch-boot.sh [stock-boot.img]
#   Default image: the active slot's boot from the newest EDL dump
#   (backups/<timestamp>/edl from backup.sh, or backups/<timestamp>-edl).
# Then: scripts/edl-flash.sh boot_<slot> <output>
#
# Why debug build: the release app hangs on Boox (services.jar NPE) and the
# shell can't reach its files. The debug app allows `run-as`, and Magisk
# always grants root to its own app. v31+ removed the su prompt; use v30.6.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/tools/magisk/v30.6"
APK="$V/app-debug.apk"; L="$V/dbg/lib/arm64-v8a"; A="$V/dbg/assets"
SLOT="$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')"
if [ $# -ge 1 ]; then
  IMG="$1"
else
  # Both layouts start with the timestamp, so a plain sort puts the newest last.
  # ls exits 1 when one layout has no match; that must not stop the script.
  DUMP="$( (ls -d "$ROOT"/backups/*/edl "$ROOT"/backups/*-edl 2>/dev/null || true) | sort | tail -1)"
  [ -n "$DUMP" ] || { echo "No EDL dump in backups/; run scripts/backup.sh or pass an image"; exit 1; }
  IMG="$(find "$DUMP" -name "boot${SLOT}.bin" | head -1)"
  [ -n "$IMG" ] || { echo "boot${SLOT}.bin not found in $DUMP"; exit 1; }
fi
OUT="$ROOT/firmware/magisk-v30.6-debug/boot${SLOT}-magisk-v30.6-debug.img"
[ -f "$APK" ] && [ -d "$L" ] || { echo "Missing Magisk debug files; run scripts/setup-tools.sh"; exit 1; }

echo "== Install Magisk v30.6 debug app"
adb shell pm list packages | grep -q com.topjohnwu.magisk && adb uninstall com.topjohnwu.magisk >/dev/null || true
adb install "$APK"

S=/data/local/tmp/mgkdbg
adb shell "rm -rf $S; mkdir -p $S"
for f in magiskboot magiskinit magisk init-ld busybox magiskpolicy; do adb push "$L/lib$f.so" "$S/$f" >/dev/null 2>&1; done
for f in boot_patch.sh util_functions.sh stub.apk addon.d.sh app_functions.sh; do adb push "$A/$f" "$S/" >/dev/null 2>&1; done
adb shell "chmod 755 $S/*"

echo "== Stage the app's install folder (Magisk's post-fs-data copies it to /data/adb/magisk)"
echo "   The tablet must be unlocked (lock screen) or run-as fails."
adb shell "run-as com.topjohnwu.magisk sh -c 'D=/data/user_de/0/com.topjohnwu.magisk/install; rm -rf \$D; mkdir -p \$D && cp $S/* \$D/ && chmod 755 \$D/*'"

echo "== Patch $IMG"
adb push "$IMG" "$S/boot.img" >/dev/null 2>&1
adb shell "cd $S && BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false ./busybox sh boot_patch.sh boot.img 2>&1" \
  | grep -E '^- |Patch with|abort|rror'
mkdir -p "$(dirname "$OUT")"
adb exec-out cat "$S/new-boot.img" > "$OUT"
[ "$(adb shell sha256sum "$S/new-boot.img" | cut -d' ' -f1)" = \
  "$(shasum -a 256 "$OUT" | cut -d' ' -f1)" ] || { echo "copy mismatch"; exit 1; }
adb shell "rm -rf $S"
shasum -a 256 "$OUT"
echo "Next: scripts/edl-flash.sh boot$SLOT $OUT"
echo "Then: unlock the tablet, open Magisk once, turn off Boox auto-freeze for it,"
echo "      and check root with scripts/root.sh id"
