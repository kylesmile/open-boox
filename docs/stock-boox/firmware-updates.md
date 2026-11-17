# Firmware updates

## Update file format

Boox ships updates as an encrypted `update.upx`. [decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx) has a key for `NoteAir4C` (and many other models; see its `BooxKeys.csv`). Decrypted, it is an ordinary Android OTA zip containing `payload.bin`; `payload-dumper-go` turns that into partition images.

```bash
scripts/firmware-extract.sh path/to/update.upx [model]   # model defaults to NoteAir4C
```

Compare the extracted `boot.img` hash with the `boot` partition in your EDL dump to confirm you have the right build.

### Getting the file

Boox does not publish direct links. Options:

- Watch `adb logcat | grep -i upx` while the tablet checks for updates; the download URL shows up in the log.
- Ask on MobileRead; owners often share links for each build.

## Updates and root

- A full update replaces `boot` and `system`, so it removes root and the `services.jar` fix. Re-root afterwards and rebuild the fix module for the new build (`scripts/build-ams-module.sh`); the module refuses to install on any build other than the one it was built for.
- Forum reports say incremental updates fail on a rooted device.
- Recovery can sideload a full update: boot to recovery, then `adb sideload update.upx`. Worst case, write the dumped partitions back over EDL.
