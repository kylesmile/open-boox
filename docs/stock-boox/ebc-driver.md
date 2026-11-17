# `/dev/ebc` kernel interface

Checked on a Note Air 4C, firmware 4.2-rel_04282, kernel 4.19.157.

`/dev/ebc` is a misc device, `crw------- root root 10,59`. Only SurfaceFlinger opens it. The driver is built into the kernel and Boox has not published its source.

## Ioctls

Found by disassembling SurfaceFlinger with `scripts/find_ioctls.py`, then matching each call to nearby log strings with `scripts/ioctl_context.py`.

- **`0x700c` = `SET_EBC_SEND_UPDATE`.** Argument: pointer to an `mxcfb_update_data`-style struct (below).
- Setup calls, next to the log strings "Going to open /dev/ebc" and "Error mapping the framebuffer": `0x701d`, `0x700b`, `0x7008`, `0x700f`, `0x7009`, `0x7029`, `0x700a`, `0x700e`, `0x7010`, `0x7006`, `0x7016`, `0x701e`, `0x701f`, `0x7021`, `0x7022`, `0x7024`–`0x7026`, `0x720f`–`0x7212`, `0x7310`.

All are `_IO('p'|'r'|'s', nr)` with no size encoded. The `'p'` numbering matches Rockchip's EBC driver interface. What each setup call does is **not yet mapped**.

SurfaceFlinger also maps a framebuffer from `/dev/ebc` (mmap). The image most likely goes there, and `0x700c` says which region to show and how.

## Update struct (`0x700c`)

| Offset | Field | Notes |
|---|---|---|
| 0x00 | top | |
| 0x04 | left | |
| 0x08 | width | clamped to panel |
| 0x0c | height | clamped to panel |
| 0x10 | waveform_mode | see the mode table in [surfaceflinger-binder.md](surfaceflinger-binder.md) |
| 0x14 | update_mode | |
| 0x18 | update_marker | increments per update |
| 0x1c | temp | 0x1000 (TEMP_USE_AMBIENT) or 0x28 |
| 0x20 | flags | 0x8000, 0x10000, 0x20000, 0x80000, 0x200000; 0x500000 = shutdown |

Fields past 0x20 (dither mode, quant bits, alt buffer) are not confirmed.

## Raw `find_ioctls.py` output (SurfaceFlinger, 4.2-rel_04282)

Addresses are specific to this build. The first four calls are on the pen input device (`EVIOCGNAME`, `EVIOCGABS`), not `/dev/ebc`.

```
0x52c0f0: req=0x804f4506 _IOC(R, 'E', 0x6, size=79)
0x52c194: req=0x80184540 _IOC(R, 'E', 0x40, size=24)
0x52c1b4: ioctl request not a constant nearby
0x52c1d4: ioctl request not a constant nearby
0x55a210: req=0x0000701d _IOC(NONE, 'p', 0x1d, size=0)
0x55a290: req=0x0000700b _IOC(NONE, 'p', 0xb, size=0)
0x55a2d0: req=0x00007008 _IOC(NONE, 'p', 0x8, size=0)
0x55a340: req=0x0000700f _IOC(NONE, 'p', 0xf, size=0)
0x55a3b0: req=0x00007009 _IOC(NONE, 'p', 0x9, size=0)
0x55a420: req=0x00007029 _IOC(NONE, 'p', 0x29, size=0)
0x55a490: req=0x0000700a _IOC(NONE, 'p', 0xa, size=0)
0x55a520: req=0x0000700e _IOC(NONE, 'p', 0xe, size=0)
0x55a7ac: req=0x0000700c _IOC(NONE, 'p', 0xc, size=0)
0x55a8cc: req=0x0000701d _IOC(NONE, 'p', 0x1d, size=0)
0x55a938: req=0x00007010 _IOC(NONE, 'p', 0x10, size=0)
0x55a9b4: req=0x00007006 _IOC(NONE, 'p', 0x6, size=0)
0x55aa4c: req=0x00007016 _IOC(NONE, 'p', 0x16, size=0)
0x55aad0: req=0x0000701e _IOC(NONE, 'p', 0x1e, size=0)
0x55ab54: req=0x0000701f _IOC(NONE, 'p', 0x1f, size=0)
0x55abd8: req=0x00007021 _IOC(NONE, 'p', 0x21, size=0)
0x55ac48: req=0x00007024 _IOC(NONE, 'p', 0x24, size=0)
0x55accc: req=0x00007025 _IOC(NONE, 'p', 0x25, size=0)
0x55ad38: req=0x00007022 _IOC(NONE, 'p', 0x22, size=0)
0x55ada8: req=0x00007026 _IOC(NONE, 'p', 0x26, size=0)
0x55ae2c: req=0x00007210 _IOC(NONE, 'r', 0x10, size=0)
0x55aeb0: req=0x00007310 _IOC(NONE, 's', 0x10, size=0)
0x55af20: req=0x00007211 _IOC(NONE, 'r', 0x11, size=0)
0x55afa4: req=0x0000720f _IOC(NONE, 'r', 0xf, size=0)
0x55b028: req=0x00007212 _IOC(NONE, 'r', 0x12, size=0)
0x55b234: req=0x0000700c _IOC(NONE, 'p', 0xc, size=0)

26 distinct requests
```

## Open questions

- What each setup ioctl (`0x70xx`, `0x72xx`, `0x7310`) does, and the mmap layout.
- The struct values SurfaceFlinger sends per waveform. A live trace (ftrace on `sys_enter_ioctl`, filtered to SurfaceFlinger) during a pen stroke and a page turn would confirm them.
- When `EpdcManager` picks each waveform. Needs SurfaceFlinger decompiled.
