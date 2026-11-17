"""List ioctl call sites in an arm64 ELF with the request number loaded into w1/x1.

Usage: python -I find_ioctls.py <elf> > ioctls.txt
Prints each `bl ioctl` call, its function context address, the request value,
and decodes it as _IOC(dir, type, nr, size).
"""
import re
import sys
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

path = sys.argv[1]
f = open(path, "rb")
elf = ELFFile(f)
text = elf.get_section_by_name(".text")
code, base = text.data(), text["sh_addr"]

# Find the PLT stub address for ioctl via .rela.plt + .plt layout.
dynsym = elf.get_section_by_name(".dynsym")
plt = elf.get_section_by_name(".plt")
relplt = elf.get_section_by_name(".rela.plt")
ioctl_got = None
for rel in relplt.iter_relocations():
    if dynsym.get_symbol(rel["r_info_sym"]).name == "ioctl":
        ioctl_got = rel["r_offset"]
# Each PLT stub: adrp x16, page; ldr x17, [x16, #off]; add x16, ...; br x17
ioctl_plt = None
pmd = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
pins = list(pmd.disasm(plt.data(), plt["sh_addr"]))
for a, b in zip(pins, pins[1:]):
    if a.mnemonic == "adrp" and b.mnemonic == "ldr":
        page = int(a.op_str.split("#")[-1], 16)
        m = re.search(r"#(0x[0-9a-f]+)\]", b.op_str)
        off = int(m.group(1), 16) if m else 0
        if page + off == ioctl_got:
            ioctl_plt = a.address
if ioctl_plt is None:
    sys.exit("no ioctl import")

md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
insns = list(md.disasm(code, base))
DIRS = {0: "NONE", 1: "W", 2: "R", 3: "RW"}
seen = {}
for idx, ins in enumerate(insns):
    if ins.mnemonic == "bl" and ins.op_str == f"#0x{ioctl_plt:x}":
        val = None
        for back in insns[max(0, idx - 12):idx][::-1]:
            ops = back.op_str.replace(" ", "")
            if back.mnemonic == "movk" and ops.startswith(("w1,", "x1,")):
                parts = ops.split(",")
                imm = int(parts[1].lstrip("#"), 16)
                sh = int(parts[2].split("#")[1]) if len(parts) > 2 else 0
                val = (val or 0) | (imm << sh)
            elif back.mnemonic in ("mov", "movz", "orr") and ops.startswith(("w1,", "x1,")) and "#" in ops:
                val = (val or 0) | int(ops.split("#")[-1], 16)
                break
        if val is None:
            print(f"0x{ins.address:x}: ioctl request not a constant nearby")
            continue
        d, size, typ, nr = val >> 30, (val >> 16) & 0x3FFF, (val >> 8) & 0xFF, val & 0xFF
        t = chr(typ) if 32 < typ < 127 else hex(typ)
        seen.setdefault(val, []).append(ins.address)
        print(f"0x{ins.address:x}: req=0x{val:08x} _IOC({DIRS[d]}, '{t}', 0x{nr:x}, size={size})")
print(f"\n{len(seen)} distinct requests")
