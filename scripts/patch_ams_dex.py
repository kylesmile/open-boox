"""Patch Boox's AMS.addPackageDependency NPE in a classes.dex.

Boox appends UpdateWebViewUsedPkgsAction after the ProcessRecord null check,
so `if-eqz v1` jumps into code that dereferences v1. We retarget that branch to
the method's final return-void, then fix the dex SHA-1 and Adler-32 fields.

Usage: python -I patch_ams_dex.py <in.dex> <out.dex>
"""
import hashlib
import struct
import sys
import zlib

CLASS = "Lcom/android/server/am/ActivityManagerService;"
METHOD = "addPackageDependency"


def uleb(buf, pos):
    result = shift = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if b < 0x80:
            return result, pos
        shift += 7


def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]


def string_at(buf, string_ids_off, idx):
    data_off = u32(buf, string_ids_off + 4 * idx)
    _, pos = uleb(buf, data_off)
    end = buf.index(0, pos)
    return buf[pos:end].decode("utf-8", "replace")


def find_code_off(buf):
    string_ids_off = u32(buf, 0x3C)
    type_ids_off = u32(buf, 0x44)
    method_ids_off = u32(buf, 0x5C)
    class_defs_size, class_defs_off = u32(buf, 0x60), u32(buf, 0x64)

    def type_name(tidx):
        return string_at(buf, string_ids_off, u32(buf, type_ids_off + 4 * tidx))

    for i in range(class_defs_size):
        cd = class_defs_off + 32 * i
        if type_name(u32(buf, cd)) != CLASS:
            continue
        class_data_off = u32(buf, cd + 24)
        pos = class_data_off
        sf, pos = uleb(buf, pos)
        inf, pos = uleb(buf, pos)
        dm, pos = uleb(buf, pos)
        vm, pos = uleb(buf, pos)
        for _ in range(sf + inf):
            _, pos = uleb(buf, pos)
            _, pos = uleb(buf, pos)
        midx = 0
        for j in range(dm + vm):
            if j == dm:
                midx = 0  # virtual methods restart index counting
            diff, pos = uleb(buf, pos)
            _, pos = uleb(buf, pos)  # access flags
            code_off, pos = uleb(buf, pos)
            midx += diff
            name_idx = u32(buf, method_ids_off + 8 * midx + 4)
            if string_at(buf, string_ids_off, name_idx) == METHOD and code_off:
                return code_off
    raise SystemExit(f"{CLASS}->{METHOD} not found")


def main(src, dst):
    buf = bytearray(open(src, "rb").read())
    code_off = find_code_off(buf)
    insns_size = u32(buf, code_off + 12)
    insns = code_off + 16
    units = struct.unpack_from(f"<{insns_size}H", buf, insns)

    # Locate the last return-void (0x000e) and the if-eqz v1 (op 0x38, AA=1).
    ret_pc = max(i for i, u in enumerate(units) if u == 0x000E)
    candidates = [i for i, u in enumerate(units) if u == 0x0138]
    if len(candidates) != 1:
        raise SystemExit(f"expected one 'if-eqz v1', found {len(candidates)}")
    pc = candidates[0]
    old = struct.unpack_from("<h", buf, insns + 2 * pc + 2)[0]
    new = ret_pc - pc
    print(f"code_off=0x{code_off:x} if-eqz@pc={pc} offset {old:+d} -> {new:+d} (return-void@pc={ret_pc})")
    if old == new:
        raise SystemExit("already patched")
    # Sanity: the old target must start with new-instance (0x22) of the Onyx action.
    if units[pc + old] & 0xFF != 0x22:
        raise SystemExit("old branch target is not new-instance; refusing to patch")
    struct.pack_into("<h", buf, insns + 2 * pc + 2, new)
    print(f"patched file offset 0x{insns + 2 * pc:x}")

    buf[12:32] = hashlib.sha1(buf[32:]).digest()
    struct.pack_into("<I", buf, 8, zlib.adler32(bytes(buf[12:])) & 0xFFFFFFFF)
    open(dst, "wb").write(buf)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
