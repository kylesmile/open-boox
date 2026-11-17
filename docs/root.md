# Root with Magisk

Tested on a Note Air 4C, firmware 4.2-rel_04282, with an unlocked bootloader. Back up first ([backup.md](backup.md)); the undo steps below need your EDL dump.

## Steps

1. Unlock the tablet's lock screen; USB debugging on.
2. Patch the stock boot image on the tablet:
   ```bash
   scripts/magisk-patch-boot.sh [stock-boot.img]
   ```
   With no argument it uses the active slot's `boot` from your newest `backups/*-edl` dump. It installs the Magisk v30.6 debug app, stages Magisk's install folder through `run-as`, patches the image on the tablet, and saves it to `firmware/magisk-v30.6-debug/`. It does not flash.
3. Flash it to the active slot (the script prints the exact line):
   ```bash
   scripts/edl-flash.sh boot_b firmware/magisk-v30.6-debug/boot_b-magisk-v30.6-debug.img
   ```
   Expect `READBACK MATCH` and `boot_completed=1`.
4. Unlock the tablet. Open Magisk once; it hangs on the splash screen, which is expected until step 6. Turn off Boox auto-freeze for Magisk, or globally ([stock-boox/auto-freeze.md](stock-boox/auto-freeze.md)).
5. Check root:
   ```bash
   scripts/root.sh id      # uid=0(root) ... context=u:r:magisk:s0
   ```
6. Build and install the `services.jar` fix:
   ```bash
   scripts/build-ams-module.sh
   ```
   Run the install line it prints, then reboot and unlock.
7. Open Magisk: it should reach the main screen.

## Undo

As root, delete Magisk's files, then restore stock `boot`:

```bash
scripts/root.sh 'rm -rf /data/adb/magisk /data/adb/magisk.db /data/adb/modules /data/adb/modules_update /data/adb/post-fs-data.d /data/adb/service.d /metadata/watchdog/magisk'
adb uninstall com.topjohnwu.magisk
adb shell settings delete global auto_freeze_delay     # only if you set it
scripts/edl-flash.sh boot_b backups/<timestamp>-edl/lun<N>/boot_b.bin
```

Use your active slot in place of `boot_b`.

## Why it works this way

- **Magisk v30.6, debug build.**
  - v31 and later removed the interactive `su` prompt; grants are set in the app, which cannot open on Boox until the fix is in. v31.1 was a dead end.
  - The release app's files cannot be reached from the shell, so a boot image patched from the shell never gets Magisk's install folder, and post-fs-data setup is incomplete.
  - The debug app allows `adb shell run-as com.topjohnwu.magisk`. That lets us stage the install folder, and run `su` as the Magisk app itself, which Magisk always grants. Patch boot with the **debug** binaries too, or the daemon won't trust the debug app (different signing key).
- **Patch flags:** `KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false`, which is what the app would pick here (system-as-root, encrypted data, separate vbmeta). Boot header v2, ramdisk in `boot`. Three "Failed to patch" dtb lines during patching are normal.
- **`su` lives in `/product/bin`**, not `/system/bin`. The adb shell has no root grant of its own; `scripts/root.sh` runs `su` through the Magisk app's `run-as`.
- **EDL, not fastboot,** because fastboot cannot write on this tablet ([stock-boox/partitions-and-boot.md](stock-boox/partitions-and-boot.md)).
- **The `services.jar` fix** is explained in [stock-boox/services-jar-npe.md](stock-boox/services-jar-npe.md).

## After a firmware update

A full update removes root and the fix. Repeat steps 2–7 with the new build's boot image (from a fresh EDL dump or the decrypted update), and rebuild the module.
