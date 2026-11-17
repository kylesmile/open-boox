#!/usr/bin/env bash
# Build the Magisk module that fixes Boox's AMS.addPackageDependency NPE
# (Magisk app stuck on splash). Build-specific: rebuild after every firmware update.
#
# Usage: scripts/build-ams-module.sh [services.jar]
#   No argument: pull /system/framework/services.jar from the connected tablet.
# Output: firmware/services-fix/boox-ams-fix-<model>-<build>.zip
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/tools/venv/bin/python"
W="$ROOT/firmware/services-fix"
mkdir -p "$W/orig" "$W/work"

if [ $# -ge 1 ]; then
  cp "$1" "$W/orig/services.jar"
  BUILD="${BUILD:?set BUILD=<ro.build.display.id> when passing a jar}"
  MODEL="${MODEL:?set MODEL=<ro.product.model> when passing a jar}"
else
  # adb pull silently skips this file; exec-out cat works.
  adb exec-out cat /system/framework/services.jar > "$W/orig/services.jar"
  [ "$(adb shell sha256sum /system/framework/services.jar | cut -d' ' -f1)" = \
    "$(shasum -a 256 "$W/orig/services.jar" | cut -d' ' -f1)" ] || { echo "copy mismatch"; exit 1; }
  BUILD="$(adb shell getprop ro.build.display.id | tr -d '\r')"
  MODEL="$(adb shell getprop ro.product.model | tr -d '\r')"
fi
echo "Model: $MODEL  Build: $BUILD"

rm -f "$W/work/classes.dex" "$W/work/classes.patched.dex"
unzip -q -o "$W/orig/services.jar" classes.dex -d "$W/work"
"$PY" -I "$ROOT/scripts/patch_ams_dex.py" "$W/work/classes.dex" "$W/work/classes.patched.dex"
"$PY" -I "$ROOT/scripts/patch_jar_entry.py" "$W/orig/services.jar" classes.dex \
  "$W/work/classes.patched.dex" "$W/work/services.jar"

M="$W/module"
rm -rf "$M" && mkdir -p "$M/system/framework" "$M/META-INF/com/google/android"
cp "$W/work/services.jar" "$M/system/framework/services.jar"
TAG="$(echo "$BUILD" | sed -E 's/.*(rel_[0-9]+).*/\1/')"
SLUG="$(echo "$MODEL" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"

cat > "$M/module.prop" <<EOF
id=boox-ams-fix-$SLUG
name=Boox AMS NPE fix ($MODEL $TAG)
version=v1-$TAG
versionCode=1
author=open-boox
description=Skips Boox WebView tracking in AMS.addPackageDependency when ProcessRecord is null, so Magisk's root process no longer crashes system calls.
EOF

cat > "$M/customize.sh" <<EOF
BUILD=\$(getprop ro.build.display.id)
case "\$BUILD" in
  $BUILD) ui_print "- Build \$BUILD matches" ;;
  *) abort "! Built for $BUILD, this device runs \$BUILD" ;;
esac
REMOVE="
/system/framework/oat/arm64/services.odex
/system/framework/oat/arm64/services.vdex
/system/framework/oat/arm64/services.art
"
EOF

cat > "$M/post-fs-data.sh" <<'EOF'
MODDIR=${0%/*}
# Boot guard: if the last boot never finished, disable this module.
if [ -f "$MODDIR/boot_pending" ]; then
  rm -f "$MODDIR/boot_pending"; touch "$MODDIR/disable"
else
  touch "$MODDIR/boot_pending"
fi
rm -f /data/dalvik-cache/arm64/system@framework@services.jar@classes.* 2>/dev/null
EOF

cat > "$M/service.sh" <<'EOF'
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
rm -f "$MODDIR/boot_pending"
EOF

INSTALLER="$ROOT/tools/magisk/v30.6/apk/assets/module_installer.sh"
[ -f "$INSTALLER" ] || { echo "Missing $INSTALLER; run scripts/setup-tools.sh"; exit 1; }
cp "$INSTALLER" "$M/META-INF/com/google/android/update-binary"
echo "#MAGISK" > "$M/META-INF/com/google/android/updater-script"

OUT="$W/boox-ams-fix-$SLUG-$TAG.zip"
rm -f "$OUT" && (cd "$M" && zip -qr -0 "$OUT" .)
shasum -a 256 "$W/work/services.jar" "$OUT"
echo "Install: adb push $OUT /data/local/tmp/ && scripts/root.sh 'magisk --install-module /data/local/tmp/$(basename "$OUT")' && adb reboot"
