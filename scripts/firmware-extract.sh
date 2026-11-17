#!/usr/bin/env bash
# Decrypt a Boox update.upx and extract partition images.
# Usage: scripts/firmware-extract.sh path/to/update.upx [model]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPX="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
MODEL="${2:-NoteAir4C}"
OUT="$ROOT/firmware/$(shasum -a 256 "$UPX" | cut -c1-12)"
mkdir -p "$OUT/images"

"$ROOT/tools/venv/bin/python" -I "$ROOT/tools/decryptBooxUpdateUpx/DeBooxUpx.py" "$MODEL" "$UPX" "$OUT/update.zip"
unzip -o "$OUT/update.zip" -d "$OUT/zip"
payload-dumper-go -o "$OUT/images" "$OUT/zip/payload.bin"
(cd "$OUT/images" && shasum -a 256 ./*.img > SHA256SUMS)
ls -lh "$OUT/images"
