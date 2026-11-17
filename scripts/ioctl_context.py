"""For each ioctl call site, print log strings referenced in the same function window.

Usage: python -I ioctl_context.py <elf> <ioctls.txt>
  ioctls.txt is the output of find_ioctls.py for the same ELF.
"""
import re
import sys
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM
from elftools.elf.elffile import ELFFile

e = ELFFile(open(sys.argv[1], "rb"))
text = e.get_section_by_name(".text")
ro = e.get_section_by_name(".rodata")
rodata, rbase = ro.data(), ro["sh_addr"]


def cstr(addr):
    if not (rbase <= addr < rbase + len(rodata)):
        return None
    o = addr - rbase
    end = rodata.find(b"\0", o)
    s = rodata[o:end]
    return s.decode("utf-8", "replace") if 4 <= len(s) < 200 and s.isascii() else None


md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
insns = list(md.disasm(text.data(), text["sh_addr"]))
regs = {}
strings_at = []  # (index, string)
for i, ins in enumerate(insns):
    if ins.mnemonic == "adrp":
        r, imm = ins.op_str.split(", #")
        regs[r] = int(imm, 16)
    elif ins.mnemonic == "add" and "#" in ins.op_str:
        parts = [p.strip() for p in ins.op_str.split(",")]
        if len(parts) == 3 and parts[1] in regs:
            s = cstr(regs[parts[1]] + int(parts[2].lstrip("#"), 16))
            if s:
                strings_at.append((i, s))
    elif ins.mnemonic == "ret":
        regs.clear()

calls = [l.split(":")[0] for l in open(sys.argv[2]).read().splitlines() if l.startswith("0x")]
addr_index = {ins.address: i for i, ins in enumerate(insns)}
for c in calls:
    i = addr_index[int(c, 16)]
    near = [s for j, s in strings_at if i - 120 <= j <= i + 40]
    print(c, "|", " || ".join(dict.fromkeys(near))[:300])
