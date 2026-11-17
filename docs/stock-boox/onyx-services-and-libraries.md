# Onyx services and libraries

Checked on a Note Air 4C, firmware 4.2-rel_04282. `scripts/pull-onyx-blobs.sh` copies these files off a tablet.

## Binder services (`adb shell service list`)

| Service | Interface |
|---|---|
| `onyx_device_service` | `android.onyx.services.IOnyxDeviceService` |
| `oec_service` | `android.onyx.optimization.IOECService` |

## Framework

- `/system/framework/framework.jar` holds `android.onyx.ViewUpdateHelper`, the app-facing e-ink API. Its static fields define the SurfaceFlinger Binder codes ([surfaceflinger-binder.md](surfaceflinger-binder.md)).
- `services.jar` holds Boox changes to `ActivityManagerService`, including the bug in [services-jar-npe.md](services-jar-npe.md), and the auto-freeze code ([auto-freeze.md](auto-freeze.md)).

## Native libraries

| File | Role |
|---|---|
| `/system/lib64/libonyx_epd_listener.so` | FIFO listener at `/dev/onyx/listener`, used by `system_server` |
| `/system/lib64/libonyx_pen_touch_reader.so` | app-side pen and touch reader |
| `/system/lib64/libonyx_cfa.so` | color filter array processing |
| `/system/lib64/libonyx_neo_dither.so` | dithering |
| `/system/lib64/libmmkv-onyx.so` | config store |
| `/system/lib64/libonyx_*.so` (others) | reader, dictionary, audio and test helpers |
| `/system_ext/lib64/libmsp.so` | references `ebc`; purpose unknown |

## Binaries that touch the panel

| File | Notes |
|---|---|
| `/system/bin/surfaceflinger` | Boox build; drives `/dev/ebc`. Root-only read. |
| `/system/bin/charger` | Charging screen; also drives `/dev/ebc`. Root-only read. |
| `/vendor/bin/npu_launcher` | Root-only read; purpose unknown. |
