# AGENTS.md

Notes for AI agents and people working in this repository.

## Do not commit device-specific details

This repo is public and meant for any Boox owner. Never commit anything that identifies one person's tablet or setup:

- serial numbers (`ro.serialno`, `ro.boot.serialno`, chip serial from `edl`), IMEIs, MAC addresses, Wi-Fi or account names
- `edl_config.json` (holds the chip serial and local paths)
- paths on your own machine, or where you keep backups (cloud folders, disk names)
- timestamped backup folder names (`backups/20260101-120000-edl`); write `backups/<timestamp>-edl` instead
- storage use, installed user apps, or anything else read from `/sdcard` or `/data`
- logs of what you ran and when (`edl` output, logcat, dmesg, session notes); summarize the finding instead
- dumped partitions, pulled Boox binaries, patched images or built modules (`backups/`, `firmware/`, `tools/` are gitignored; keep it that way)

**Fine to commit:** model names, firmware versions and build IDs, SoC and kernel versions, partition names, `/sys` and `/dev` paths, offsets and hashes of stock firmware files, and anything else that is the same on every unit running that build. Use these to say what a script or note was tested on.

Before committing, search the diff for serials and dates: `git diff --cached | grep -iE 'serial|[0-9]{8}-[0-9]{6}|/Users/|/home/'`.

## Writing docs

- `docs/stock-boox/` holds facts about Boox's stock software, firmware and drivers, one topic per file. Start each page with the model and firmware it was checked on. List new pages in `docs/stock-boox/README.md`.
- `docs/*.md` are step-by-step guides. Keep them in sync with the scripts.
- Mark anything not verified on a tablet as untested.
- Add new outside sources to the References section of `README.md`.

## Scripts

- Shell scripts start with `set -euo pipefail` and find the repo root with `ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. Write output under `backups/`, `firmware/` or `tools/`.
- macOS ships bash 3.2: no associative arrays, and expand possibly-empty arrays as `${arr[@]+"${arr[@]}"}`.
- Run Python with the venv and isolated mode: `tools/venv/bin/python -I scripts/<name>.py`.
- Copy files off the tablet with `adb exec-out cat`, not `adb pull`, and compare `sha256sum`.
- Anything that writes to the tablet must read back and compare (see `edl-flash.sh`).

## Running commands

- `adb`, `fastboot` and `edl` need USB access. In a sandboxed agent session, run them outside the sandbox.
- Never run a script that writes to the tablet (`edl-flash.sh`, `magisk --install-module`, anything through `root.sh` that changes files) without the user's go-ahead for that specific command.
