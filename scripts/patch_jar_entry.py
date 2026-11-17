"""Replace one stored (uncompressed) entry in a zip/jar in place.

The new data must be the same size as the old. Offsets and alignment stay
the same; only the entry's CRC-32 changes (local header and central directory).

Usage: python -I patch_jar_entry.py <in.jar> <entry> <new-data> <out.jar>
"""
import struct
import sys
import zipfile
import zlib

src, name, new_path, dst = sys.argv[1:5]
jar = bytearray(open(src, "rb").read())
new = open(new_path, "rb").read()

info = zipfile.ZipFile(src).getinfo(name)
if info.compress_type != zipfile.ZIP_STORED:
    sys.exit(f"{name} is compressed; in-place patch needs a stored entry")
if info.file_size != len(new):
    sys.exit(f"size mismatch: {info.file_size} vs {len(new)}")

lh = info.header_offset
assert jar[lh:lh + 4] == b"PK\x03\x04"
n, m = struct.unpack_from("<HH", jar, lh + 26)
data = lh + 30 + n + m
jar[data:data + len(new)] = new
crc = zlib.crc32(new) & 0xFFFFFFFF
struct.pack_into("<I", jar, lh + 14, crc)

enc = name.encode()
i = 0
while True:
    i = jar.find(b"PK\x01\x02", i)
    if i < 0:
        sys.exit("central directory entry not found")
    nl = struct.unpack_from("<H", jar, i + 28)[0]
    if jar[i + 46:i + 46 + nl] == enc:
        struct.pack_into("<I", jar, i + 16, crc)
        break
    i += 4

open(dst, "wb").write(jar)
bad = zipfile.ZipFile(dst).testzip()
if bad:
    sys.exit(f"CRC check failed on {bad}")
print(f"{name}: data at offset {data} ({'4-byte aligned' if data % 4 == 0 else 'UNALIGNED'}), crc {crc:08x}")
