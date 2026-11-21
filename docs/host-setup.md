# Host and tablet setup

Tested only on macOS (Apple Silicon). `setup-tools.sh` uses Homebrew; on Linux, install the same tools by hand. The other scripts need `bash`, `adb`, `shasum`, `unzip` and `zip`.

## Host

Needs Homebrew, `git` and `curl`. Then:

```bash
scripts/setup-tools.sh
```

It installs, into `tools/` (gitignored) where possible:

- Homebrew: `libusb`, `payload-dumper-go`, `openjdk`, `apktool`, `uv`, `android-platform-tools` (`adb`, `fastboot`)
- A Python 3.13 venv in `tools/venv` with [`edl`](https://github.com/bkerler/edl), `pycryptodome`, `capstone`, `pyelftools`
- The Lenovo/Motorola firehose loader into `tools/loaders/`
- [decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx) into `tools/decryptBooxUpdateUpx`
- Magisk v30.6 release and debug APKs into `tools/magisk/v30.6`, unpacked

Safe to re-run. Run the Python scripts with the venv: `tools/venv/bin/python -I scripts/<name>.py`.

## Tablet

1. Turn on USB debugging: Settings → More Settings → USB Debug.
2. Connect over USB and accept the "Allow USB debugging" prompt. Tick "Always allow".
3. Check: `adb devices` lists the tablet as `device`.

After any reboot, **unlock the lock screen** before using `run-as` (which `scripts/root.sh` and `scripts/magisk-patch-boot.sh` rely on). App data stays encrypted until then; `adb shell dumpsys user` shows `RUNNING_LOCKED`.

## Known problems

- **`adb pull` silently does nothing** for some `/system` files (for example `services.jar`). Use `adb exec-out cat <file> > out` and compare `sha256sum`.
- **`edl` writes `edl_config.json`** (local path and chip serial) into the working directory. It is gitignored.
