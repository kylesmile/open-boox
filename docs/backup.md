# Back up the tablet

Do all of this before writing anything to the tablet. Every step here only reads.

Output goes to `backups/<timestamp>-<kind>/`, which is gitignored. Copy `backups/` to a second disk when you are done.

## 1. Before you start

App private data needs root to copy. On the tablet, sync notes to Boox cloud, and export anything important from the Notes app as PDF. Or live (a little) dangerously and backup app private data after rooting.

## 2. Device snapshot

```bash
scripts/device-info.sh
```

Saves props, partitions, packages, settings, input devices, services, and e-ink `/sys` nodes, and prints a summary of the props that matter (model, build, slot, lock state, Treble). Read the summary before going further: if `ro.boot.flash.locked=1`, see [stock-boox/partitions-and-boot.md](stock-boox/partitions-and-boot.md).

## 3. User data

```bash
scripts/backup-user-data.sh
```

Copies `/sdcard` and the APKs of user-installed apps.

## 4. Full partition dump over EDL

```bash
scripts/edl-dump.sh                 # includes userdata
SKIP_USERDATA=1 scripts/edl-dump.sh # skips it
```

Reboots to EDL, saves the GPT (`gpt.txt`), dumps every partition on every LUN into `lun<N>/<name>.bin` with `rawprogram*.xml`, writes `SHA256SUMS`, then reboots. On a Note Air 4C this is 83 partitions across 6 LUNs, about 57 GB with userdata.

This dump is the real safety net. It holds `persist`, `devinfo`, `frp`, modem calibration and other per-device data that no firmware download contains. `userdata` is file-based encrypted and only restores to the same tablet.

Restore one partition:

```bash
scripts/edl-flash.sh <partition> backups/<timestamp>-edl/lun<N>/<partition>.bin
```

`edl-flash.sh` writes, reads back, compares hashes, and reboots. It prints `READBACK MATCH` on success and leaves the tablet in EDL on a mismatch.

## 5. Stock firmware (optional)

If you can get the `update.upx` for your build:

```bash
scripts/firmware-extract.sh path/to/update.upx [model]
```

See [stock-boox/firmware-updates.md](stock-boox/firmware-updates.md).
