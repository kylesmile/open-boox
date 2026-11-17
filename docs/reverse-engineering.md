# Repeating the e-ink tracing

How the findings in [stock-boox/](stock-boox/) were made, so you can check them on your own model or build. Needs a rooted tablet ([root.md](root.md)) for the root-only binaries.

## 1. Pull the binaries

```bash
scripts/pull-onyx-blobs.sh
```

Copies `framework.jar`, the Onyx libraries, `libmsp.so`, and (with root) `surfaceflinger`, `charger` and `npu_launcher` into `firmware/onyx-blobs/` (gitignored; these are Boox's files and must not be committed). Each copy is checked against `sha256sum` on the tablet.

## 2. SurfaceFlinger ioctls

```bash
tools/venv/bin/python -I scripts/find_ioctls.py firmware/onyx-blobs/surfaceflinger > firmware/onyx-blobs/sf-ioctls.txt
tools/venv/bin/python -I scripts/ioctl_context.py firmware/onyx-blobs/surfaceflinger firmware/onyx-blobs/sf-ioctls.txt
```

`find_ioctls.py` finds every call to `ioctl` in an arm64 ELF, recovers the request number loaded into `w1`/`x1`, and decodes it as `_IOC(dir, type, nr, size)`. `ioctl_context.py` prints the log strings each call's function refers to, which is how we told the pen calls from the `/dev/ebc` calls and found the setup sequence.

Results: [stock-boox/ebc-driver.md](stock-boox/ebc-driver.md).

## 3. SurfaceFlinger Binder codes

```bash
apktool d -f -r -o firmware/onyx-blobs/framework firmware/onyx-blobs/framework.jar
python3 -I scripts/sf_transaction_codes.py \
  "$(grep -rl 'APPLY_GC_ONCE' firmware/onyx-blobs/framework | head -1)"
```

Results: [stock-boox/surfaceflinger-binder.md](stock-boox/surfaceflinger-binder.md). Try a code with `adb shell service call SurfaceFlinger <decimal code> [i32 ...]` and watch `adb logcat -s SurfaceFlinger`.

## 4. Strings

`strings firmware/onyx-blobs/surfaceflinger | grep -iE 'ebc|epd|waveform|regal|dither'` is a fast way to find class names (`EpdcManager`), log messages and shader names to search for in a disassembler.

## Open questions

- What each `/dev/ebc` setup ioctl does, and the mmap layout.
- The update struct values per waveform, from a live trace (ftrace on `sys_enter_ioctl` for SurfaceFlinger) during pen strokes and page turns.
- When `EpdcManager` picks each waveform.
- Where the panel waveform tables live (`onyxconfig`, a firmware file, or the kernel image).
- What the e-ink controller is: a separate timing chip fed over DSI, or something else.
