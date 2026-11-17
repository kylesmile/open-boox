# Auto-freeze

Checked on a Note Air 4C, firmware 4.2-rel_04282.

Boox freezes background apps to save power (`EACAutoFreezeImpl` in `services.jar`). It freezes the Magisk app too, which breaks root until the app runs again.

- Turn it off for one app in Boox's app settings, or globally.
- The global setting is `settings global auto_freeze_delay`. `-1` turns it off. It is absent by default.

```bash
adb shell settings get global auto_freeze_delay
adb shell settings put global auto_freeze_delay -1
adb shell settings delete global auto_freeze_delay   # back to default
```
