# Back up the tablet

Do all of this before writing anything to the tablet. Every backup step only reads, apart from stopping each app while its data is copied.

Read step 1, then run every backup with one command:

```bash
scripts/backup.sh                  # EDL dump includes userdata
SKIP_USERDATA=1 scripts/backup.sh  # skips it
```

It runs steps 2 to 5 in order into `backups/<timestamp>/` (`info/`, `userdata/`, `appdata/`, `edl/`), which is gitignored. Step 4 needs root, so on a stock tablet `backup.sh` skips it. It then packs that folder into `backups/<timestamp>.tar.gz`, tests the archive, and writes its hash to `backups/<timestamp>.tar.gz.sha256`. Copy those two files to another drive, and check them there with `shasum -a 256 -c <timestamp>.tar.gz.sha256`. With userdata the whole run takes about 35 minutes, and the archive comes to about 14 GB, or 17 GB with app data.

Each step's script also runs alone. Run that way, it writes `backups/<timestamp>-<kind>/` and its own `.tar.gz` and `.sha256`.

The archive step uses `pigz` (from `setup-tools.sh`) when it is installed and falls back to `gzip`, which is much slower on the EDL dump.

## 1. Before you start

App private data needs root to copy. On the tablet, sync notes to Boox cloud, and export anything important from the Notes app as PDF. Or live (a little) dangerously and backup app private data after rooting.

## 2. Device snapshot

```bash
scripts/device-info.sh
```

Saves props, partitions, packages, settings, input devices, services, and e-ink `/sys` nodes, and prints a summary of the props that matter (model, build, slot, lock state, Treble). Read the summary before going further: if `ro.boot.flash.locked=1`, see [stock-boox/partitions-and-boot.md](stock-boox/partitions-and-boot.md).

On stock firmware `/proc/cmdline` and `/proc/partitions` need root, so those two files hold only "Permission denied". The same facts are in `getprop.txt` (`ro.boot.*`), `by-name.txt` and the EDL dump's `gpt.txt`. The `/sys` search lists only the nodes the shell user can see.

## 3. User data

```bash
scripts/backup-user-data.sh
```

Copies `/sdcard` and the APKs of user-installed apps, then checks every file against a SHA-256 taken on the tablet (`sdcard.sha256`, `apks.sha256`). Files that change during the copy, such as app logs under `Android/data`, show up as mismatches. The script still finishes but exits non-zero, and `backup.sh` goes on and warns at the end.

## 4. App data (needs root)

```bash
scripts/backup-app-data.sh               # user apps and the Boox apps below
scripts/backup-app-data.sh <package> ... # only these
```

For each app, stops it and copies `/data/data/<pkg>`, `/data/user_de/0/<pkg>` and its `Android/data` and `Android/obb` folders under `/data/media/0`, without `cache` and `code_cache`. The Boox apps are listed in `BOOX_APPS`: the launcher and library (`com.onyx`), Notes, the reader, dictionary, touch calibration, voice recorder and sync. Set `BOOX_APPS` to change the list. Magisk itself is skipped.

Each app gets `apps/<pkg>/` with:

| File | Holds |
|---|---|
| `<pkg>.tar` | the data, with numeric owners |
| `<pkg>.files` | owner, group, mode and SELinux label of every file and folder |
| `<pkg>.sha256` | a hash of every file |
| `<pkg>.info` | the app's uid and `versionCode` when backed up |

The labels are kept in `.files` because toybox `tar --selinux` segfaults on this build. The script copies each tar through `/data/local/tmp` and checks its hash. Expect a minute or two and about a gigabyte for a dozen or so apps; a keyboard with downloaded language models can be most of it.

### Restore

```bash
scripts/restore-app-data.sh backups/<timestamp>/appdata <package> ...
```

**Writes to the tablet:** each app's current data is replaced. With no package names it restores every app in the backup. The app must be installed. If it is not, and the backup came from `backup.sh`, the script installs it from `userdata/apks/<pkg>`. A warning is printed when the installed `versionCode` differs from the backup's.

For each app it stops the app, deletes its data (keeping the empty cache folders), unpacks the tar, and sets every owner, mode and label from `.files`. A reinstalled app gets a new uid, so the script moves owners, groups and label categories from the old uid to the new one. It then compares every file's hash, owner, mode and label with the backup, and prints `restored N entries, uid OLD -> NEW`.

Tested on one user-installed app, both after `pm clear` and after uninstalling and reinstalling it (which gave it a new uid). Both times the app opened with its settings, with no SELinux denials. Not yet tested on the Boox apps.

Boox auto-freeze disables most user apps (`enabled=3` in `dumpsys package`). That is not a restore problem: opening the app from the launcher unfreezes it.

## 5. Full partition dump over EDL

```bash
scripts/edl-dump.sh                 # includes userdata
SKIP_USERDATA=1 scripts/edl-dump.sh # skips it
```

Reboots to EDL, saves the GPT (`gpt.txt`), dumps every partition on every LUN into `lun<N>/<name>.bin` with `rawprogram*.xml` and each LUN's `gpt_main<N>.bin` and `gpt_backup<N>.bin`, writes `SHA256SUMS`, then reboots. On a Note Air 4C this is 83 partitions across 6 LUNs, about 57 GB with userdata. Reads run at about 34 MB/s, so the dump takes about 30 minutes; packed, the dump comes to about 13 GB.

`edl reset` may print `USBError(5, 'Input/Output Error')` as the tablet drops off USB. That is harmless if the tablet boots; check with `adb get-state`.

This dump is the real safety net. It holds `persist`, `devinfo`, `frp`, modem calibration and other per-device data that no firmware download contains. `userdata` is file-based encrypted and only restores to the same tablet.

Restore one partition (from a standalone `edl-dump.sh` run, the folder is `backups/<timestamp>-edl/`):

```bash
scripts/edl-flash.sh <partition> backups/<timestamp>/edl/lun<N>/<partition>.bin
```

`edl-flash.sh` writes, reads back, compares hashes, and reboots. It prints `READBACK MATCH` on success and leaves the tablet in EDL on a mismatch.

## 6. Stock firmware (optional)

If you can get the `update.upx` for your build:

```bash
scripts/firmware-extract.sh path/to/update.upx [model]
```

See [stock-boox/firmware-updates.md](stock-boox/firmware-updates.md).
