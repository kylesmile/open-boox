# open-boox

Scripts and notes for backing up, rooting and studying Onyx Boox e-ink tablets, with a map of how Boox's stock e-ink stack works. Everything here was worked out on one Note Air 4C; the steps are written so you can repeat them on your own tablet.

> **Warning.** These scripts write raw partitions over Qualcomm EDL. A mistake can leave the tablet unbootable. Take the full backup first, keep it somewhere safe, and read each script before you run it. Rooting voids the warranty.

## Tested on

| | |
|---|---|
| Tablet | Boox Note Air 4C (`ro.product.model=NoteAir4C`) |
| Firmware | 4.2-rel_04282 (2026-04-28), Android 13 |
| SoC | Qualcomm SM6350 (`lito`/`lagoon`) |
| Kernel | 4.19.157 |
| Bootloader | Unlocked as shipped |
| Host | macOS on Apple Silicon |
| Tools | Magisk v30.6 (debug build), bkerler `edl`, Lenovo/Motorola firehose loader `0000000000000000_bdaf51b59ba21d8a_fhprg.bin` |

Other Boox models on the same Qualcomm platform will likely need only small changes, but nothing here has been tried on them. If you run this on another model or build, note what changed (see [AGENTS.md](AGENTS.md) for what to leave out).

## What you can do with it

1. **Set up** the host tools and the tablet: [docs/host-setup.md](docs/host-setup.md)
2. **Back up** everything, including a raw dump of every partition over EDL: [docs/backup.md](docs/backup.md)
3. **Root** stock firmware with Magisk and fix the Boox bug that breaks it: [docs/root.md](docs/root.md)
4. **Study** Boox's e-ink stack and repeat the tracing: [docs/reverse-engineering.md](docs/reverse-engineering.md)

Notes on the stock software, firmware and drivers, one topic per page: [docs/stock-boox/](docs/stock-boox/README.md).

## The short version

- Boox's e-ink refresh lives in its modified **SurfaceFlinger**, which alone drives `/dev/ebc`. Apps reach it through extra Binder codes with no permission check (`adb shell service call SurfaceFlinger 16711718` does a full refresh).
- **Fastboot cannot write** on the Note Air 4C. **EDL can** read and write every partition.
- **Magisk needs two workarounds:** the v30.6 debug build (for `run-as` root and the `su` prompt), and a patched `services.jar` that fixes a Boox null-pointer bug.

## Layout

```
scripts/            everything you run (table below)
docs/               step-by-step guides
docs/stock-boox/    how Boox's stock software and drivers work
backups/            (gitignored) your device snapshots and EDL dumps
firmware/           (gitignored) patched images, the services.jar module, pulled Boox binaries
tools/              (gitignored) host tools from scripts/setup-tools.sh
```

## Scripts

| Script | What it does | Touches the tablet? |
|---|---|---|
| `setup-tools.sh` | Install host tools into `tools/` | No |
| `device-info.sh` | Snapshot props, partitions, packages, settings, input devices into `backups/<date>-info` | Reads |
| `backup-user-data.sh` | Copy `/sdcard` and user-app APKs into `backups/<date>-userdata` | Reads |
| `edl-dump.sh` | Raw dump of every partition over EDL (`SKIP_USERDATA=1` to skip userdata) | Reads (reboots to EDL) |
| `edl-flash.sh <part> <img>` | Write one partition over EDL, read back, compare, reboot | **Writes** |
| `firmware-extract.sh <update.upx> [model]` | Decrypt a Boox update and extract partition images | No |
| `magisk-patch-boot.sh [img]` | Install the Magisk debug app, stage it, patch a boot image on the tablet | Installs an app; no flashing |
| `build-ams-module.sh [jar]` | Build the `services.jar` fix module for the tablet's current build | Reads |
| `root.sh '<cmd>'` | Run a command as root through the Magisk debug app | Depends on the command |
| `pull-onyx-blobs.sh` | Copy Boox's e-ink binaries and libraries off the tablet | Reads |
| `patch_ams_dex.py`, `patch_jar_entry.py` | Used by `build-ams-module.sh` | No |
| `find_ioctls.py`, `ioctl_context.py` | List ioctl calls in an arm64 ELF, and the log strings near each | No |
| `sf_transaction_codes.py` | List Boox's SurfaceFlinger Binder codes from decompiled `framework.jar` | No |

Some scripts were written from commands first run by hand. `magisk-patch-boot.sh` runs the same commands that rooted the test tablet, but has not itself been run end to end; neither has `pull-onyx-blobs.sh`. `sf_transaction_codes.py` has been checked against 4.2-rel_04282.

## Reference checksums (4.2-rel_04282)

SHA-256, first 16 hex digits. Use these to check you have the same build before trusting offsets in the docs.

| File | Hash |
|---|---|
| Stock `boot_b` | `765d41d770c9fccc…` |
| Stock `/system/framework/services.jar` | `fd45574a43099f3e…` |
| Patched `services.jar` (from `build-ams-module.sh`) | `e541f84df0318f36…` |
| `/system/bin/surfaceflinger` | `7953cddeb01ca459…` |
| `/system/bin/charger` | `e7f3430315a77dd9…` |
| `Magisk-v30.6.apk` | `f1ffc3c9a5614c25…` |

## References

Guides, threads and tools used while working this out:

- [Note Air 5C thread (MobileRead)](https://www.mobileread.com/forums/showthread.php?t=371290&page=3): bootloader, EDL and AVB reports from another model
- [Is LineageOS possible on Boox devices? (MobileRead)](https://www.mobileread.com/forums/showthread.php?t=360698): kernel source and custom ROM status
- [BooxPalma2RootGuide](https://github.com/jdkruzr/BooxPalma2RootGuide): EDL and root steps on the Palma 2
- [boox-ams-fix](https://github.com/dynamicfire/boox-ams-fix): the original `services.jar` NPE fix module
- [decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx): decrypts Boox `update.upx` files
- [bkerler/edl](https://github.com/bkerler/edl): Qualcomm EDL/firehose client
- [bkerler/Loaders](https://github.com/bkerler/Loaders): firehose loaders, including the Lenovo/Motorola one used here
- [Magisk](https://github.com/topjohnwu/Magisk) and its [v30.6 release](https://github.com/topjohnwu/Magisk/releases/tag/v30.6)
- [payload-dumper-go](https://github.com/ssut/payload-dumper-go): extracts partition images from `payload.bin`
- [Apktool](https://apktool.org/): decompiles `framework.jar` to smali
- [Capstone](https://www.capstone-engine.org/) and [pyelftools](https://github.com/eliben/pyelftools): disassembly and ELF parsing in the ioctl scripts
- [Dalvik executable format](https://source.android.com/docs/core/runtime/dex-format): header checksums and `class_data_item` layout used by `patch_ams_dex.py`
