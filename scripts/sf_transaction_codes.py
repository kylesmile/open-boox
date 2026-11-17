"""List the SurfaceFlinger Binder transaction codes Boox defines in framework.jar.

The codes are static int fields on android.onyx.ViewUpdateHelper, set in its
static initializer. Decompile framework.jar with apktool first:

  apktool d -f -r -o framework framework.jar
  python -I sf_transaction_codes.py \
      "$(grep -rl 'APPLY_GC_ONCE' framework | head -1)" > sf-transaction-codes.txt

Usage: python -I sf_transaction_codes.py <ViewUpdateHelper.smali>
"""
import re
import sys

CONST = re.compile(r"^\s*const(?:/\d+|/high16)?\s+(v\d+),\s*(-?0x[0-9a-f]+|-?\d+)")
SPUT = re.compile(r"^\s*sput\s+(v\d+),\s*L[^;]+;->(\w+):I")

regs = {}
in_clinit = False
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith(".method") and "<clinit>" in line:
        in_clinit = True
    elif line.startswith(".end method"):
        in_clinit = False
    if not in_clinit:
        continue
    if m := CONST.match(line):
        regs[m.group(1)] = int(m.group(2), 0)
    elif (m := SPUT.match(line)) and m.group(1) in regs:
        print(f"0x{regs[m.group(1)]:<8x}{m.group(2)}")
