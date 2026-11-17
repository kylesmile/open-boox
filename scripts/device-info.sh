#!/usr/bin/env bash
# Read-only snapshot of device state. Needs USB debugging on.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/backups/$(date +%Y%m%d-%H%M%S)-info"
mkdir -p "$OUT"
adb wait-for-device
s() { adb shell "$@" 2>&1; }

s getprop                         > "$OUT/getprop.txt"
s cat /proc/partitions            > "$OUT/proc-partitions.txt"
s ls -l /dev/block/by-name /dev/block/bootdevice/by-name > "$OUT/by-name.txt"
s cat /proc/cmdline               > "$OUT/cmdline.txt"
s uname -a                        > "$OUT/uname.txt"
s mount                           > "$OUT/mount.txt"
s df -h                           > "$OUT/df.txt"
s pm list packages -f -U          > "$OUT/packages.txt"
s pm list packages -3             > "$OUT/packages-user.txt"
s pm list features                > "$OUT/features.txt"
for ns in system secure global; do s settings list $ns > "$OUT/settings-$ns.txt"; done
s service list                    > "$OUT/services.txt"
s getevent -lp                    > "$OUT/input-devices.txt"   # pen digitizer, touch, keys
s dumpsys input                   > "$OUT/dumpsys-input.txt"
s dumpsys SurfaceFlinger          > "$OUT/dumpsys-surfaceflinger.txt"
s dumpsys display                 > "$OUT/dumpsys-display.txt"
s lshal                           > "$OUT/lshal.txt"
s "ls -la /onyxconfig /vendor/etc /vendor/lib64/hw /vendor/bin" > "$OUT/vendor-ls.txt"
s "find /sys -maxdepth 6 \( -iname '*epd*' -o -iname '*eink*' -o -iname '*waveform*' -o -iname '*wacom*' -o -iname '*onyx*' -o -iname '*backlight*' \)" > "$OUT/sys-eink-nodes.txt"
s "ls -la /dev" > "$OUT/dev.txt"

grep -E 'ro.product.model|ro.build.(fingerprint|version.release|display.id)|ro.board.platform|ro.treble.enabled|ro.vndk.version|ro.boot.dynamic_partitions|ro.boot.slot_suffix|ro.boot.verifiedbootstate|ro.boot.flash.locked|ro.oem_unlock_supported|ro.build.ab_update' \
  "$OUT/getprop.txt" | tee "$OUT/summary.txt"
echo "Saved to $OUT"
