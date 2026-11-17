# Hardware and platform

Read from `getprop`, `/proc`, `/sys` and `dumpsys` on a Note Air 4C, firmware 4.2-rel_04282. `scripts/device-info.sh` collects the same data from your tablet.

| Item | Value |
|---|---|
| Model | `ro.product.model=NoteAir4C` |
| Firmware | 4.2-rel_04282 (build date 2026-04-28), `ro.build.display.id` ends in `4.2-rel_04282_<hash>` |
| Android | 13 (SDK 33), system security patch 2026-04-01 |
| SoC | Qualcomm, `ro.soc.model=SM6350` (Snapdragon 690). Platform `lito`, board name `lagoon`, arm64. Same `lagoon` family as the SM7225. |
| GPU | Adreno (`ro.hardware.egl=adreno`) |
| Kernel | 4.19.157, Qualcomm tree. Boox drivers are built in, not modules. |
| Vendor | Android 11 (API 30, `ro.vndk.version=30`), Keymaster 4, vendor security patch 2025-10-01 |
| Treble | `ro.treble.enabled=true`. The Android 11 vendor runs under an Android 13 system. |
| Display | Qualcomm MDSS/DSI (`ae00000.qcom,mdss_mdp`) plus Onyx `onyxdsi`. E-ink updates go through `/dev/ebc` (misc 10:59). The panel is natively landscape, 2480×1860. See [eink-architecture.md](eink-architecture.md). |
| Front light | `/sys/class/backlight/onyx_bl_br` (brightness) and `onyx_bl_ct` (warmth). See [front-light.md](front-light.md). |
| Pen | `onyx_emp_Wacom I2C Digitizer` (`wacom_ts` I2C driver). See [pen-and-touch.md](pen-and-touch.md). |
| Touch | `pt_mt` |
| Other input | `onyx-hall` (cover sensor), `gpio-keys`. No volume keys. |

## Commands

```bash
adb shell getprop | grep -E 'ro.soc|ro.board.platform|ro.product.model|ro.build.display.id|ro.vndk.version|ro.treble'
adb shell uname -a
adb shell getevent -lp        # input devices and their axes
```
