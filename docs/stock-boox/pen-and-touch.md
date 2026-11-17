# Pen and touch

Checked on a Note Air 4C, firmware 4.2-rel_04282.

## Pen

- Digitizer: `onyx_emp_Wacom I2C Digitizer`, driver `wacom_ts` (I2C). On our unit it was `/dev/input/event5`; find yours with `adb shell getevent -lp`.
- Both `system_server` and SurfaceFlinger open it. SurfaceFlinger finds it by `EVIOCGNAME`, looking for `onyx_emp`, `Wacom I2C Digitizer` or `hanvon_tp`, and reads the axis ranges with `EVIOCGABS`.
- **Fast ink:** in handwriting mode SurfaceFlinger draws strokes itself (Binder codes `START_STROKE`, `ADD_STROKE_POINT`, `FINISH_STROKE`) and holds back normal refresh. It logs "do not switch epd Schema in handwriting mode". See [surfaceflinger-binder.md](surfaceflinger-binder.md).
- `libonyx_pen_touch_reader.so` is the app-side reader.

## Touch

- Touch controller driver: `pt_mt`.

## Power and filtering

- `/sys/onyx_misc/wacom_pm`: pen power.
- `/sys/onyx_misc/cytp_lo_filter`: touch filtering.

Neither has been changed or tested.
