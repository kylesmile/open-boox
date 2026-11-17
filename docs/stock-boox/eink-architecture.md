# E-ink stack architecture

Traced on a rooted Note Air 4C, firmware 4.2-rel_04282.

## Summary

Boox's e-ink logic lives in its **modified SurfaceFlinger** (`/system/bin/surfaceflinger`) on the system partition, not in a vendor HAL. SurfaceFlinger is the only process that opens `/dev/ebc`, and it also reads the Wacom pen device directly. Apps and the framework reach it through custom Binder transaction codes on the `SurfaceFlinger` service.

```
app / framework (android.onyx.ViewUpdateHelper in framework.jar)
   │  Binder: ISurfaceComposer, codes 0xff00xx / 0x1000xx
   ▼
surfaceflinger (Boox build)
   ├─ EpdcManager (HW/SW): collects dirty regions, merges by mode
   ├─ GPU shaders: dither (blue noise, table, random), color/CFA, gamma
   ├─ pen fast path: reads the onyx_emp Wacom input device, draws strokes
   └─ ioctl(/dev/ebc, 0x700c SET_EBC_SEND_UPDATE, &mxcfb_update_data)
   ▼
kernel: ebc misc device (10:59) + onyxdsi + Qualcomm MDSS/DSI
```

`system_server` holds a FIFO at `/dev/onyx/listener` (`libonyx_epd_listener.so`) and also opens the pen device.

## Two layers

1. **Kernel:** the `ebc`/`onyxdsi` panel path, waveform handling and the Wacom digitizer. Closed source and built in.
2. **System partition:** Boox's SurfaceFlinger (refresh policy, `/dev/ebc` updates, dithering and color shaders, fast pen ink) and `framework.jar` (`android.onyx.ViewUpdateHelper`, the app-facing API).

No vendor HAL takes part. `/vendor` is a stock-looking Qualcomm Android 11 vendor.

## What this means for a generic system image

A generic system image (GSI) or AOSP build ships AOSP SurfaceFlinger, which never talks to `/dev/ebc`. Expect the panel not to update at all, or to stick on one frame, unless something else drives `/dev/ebc`. The kernel and vendor layers can stay as they are.

## Details

- Binder codes and the mode word: [surfaceflinger-binder.md](surfaceflinger-binder.md)
- `/dev/ebc` ioctls and the update struct: [ebc-driver.md](ebc-driver.md)
- Pen fast path: [pen-and-touch.md](pen-and-touch.md)
- How to repeat the tracing: [../reverse-engineering.md](../reverse-engineering.md)
