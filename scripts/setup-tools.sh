#!/usr/bin/env bash
# Install everything needed for backup and flashing. Safe to re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/tools"
mkdir -p "$TOOLS/loaders"

brew install --quiet libusb payload-dumper-go openjdk apktool uv
brew install --quiet --cask android-platform-tools
# Homebrew leaves the download quarantine flag on platform-tools; macOS then
# kills adb (exit 137) on first run.
xattr -dr com.apple.quarantine "$(brew --prefix)/Caskroom/android-platform-tools" 2>/dev/null || true

# edl needs a released Python (not a 3.x alpha); 3.13 works.
if [ ! -x "$TOOLS/venv/bin/python" ]; then
  uv venv --python 3.13 "$TOOLS/venv"
fi
CFLAGS=-Wno-int-conversion uv pip install --python "$TOOLS/venv/bin/python" \
  "git+https://github.com/bkerler/edl" pycryptodome capstone pyelftools

# Lenovo/Motorola firehose loader. Works on the Note Air 4C; reported to work
# on the Palma 2 and Note Air 5C.
LOADER="$TOOLS/loaders/0000000000000000_bdaf51b59ba21d8a_fhprg.bin"
[ -f "$LOADER" ] || curl -fL -o "$LOADER" \
  "https://raw.githubusercontent.com/bkerler/Loaders/main/lenovo_motorola/0000000000000000_bdaf51b59ba21d8a_fhprg.bin"

[ -d "$TOOLS/decryptBooxUpdateUpx" ] || \
  git clone --depth 1 https://github.com/Hagb/decryptBooxUpdateUpx "$TOOLS/decryptBooxUpdateUpx"

# Magisk v30.6: last release with the interactive su prompt. The debug build
# allows `adb shell run-as`, which is how we get root on Boox (see docs/root.md).
MV="$TOOLS/magisk/v30.6"
mkdir -p "$MV"
for f in Magisk-v30.6.apk app-debug.apk; do
  [ -f "$MV/$f" ] || curl -fL -o "$MV/$f" "https://github.com/topjohnwu/Magisk/releases/download/v30.6/$f"
done
[ -d "$MV/apk" ] || unzip -q -o "$MV/Magisk-v30.6.apk" 'assets/*' 'lib/arm64-v8a/*' -d "$MV/apk"
[ -d "$MV/dbg" ] || unzip -q -o "$MV/app-debug.apk" 'assets/*' 'lib/arm64-v8a/*' -d "$MV/dbg"

echo "OK. edl: $TOOLS/venv/bin/edl  loader: $LOADER  magisk: $MV"
