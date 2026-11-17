# `services.jar` NPE that breaks Magisk

Checked on a Note Air 4C, firmware 4.2-rel_04282. Others report the same bug on other models ([other-models.md](other-models.md)).

## Symptom

With Magisk installed, the Magisk app hangs on its splash screen, and root processes crash system calls.

## Cause

Boox changed `ActivityManagerService.addPackageDependency()` in `/system/framework/services.jar`. After the stock null check on `ProcessRecord`, it runs Boox WebView tracking (`UpdateWebViewUsedPkgsAction`), which dereferences the `ProcessRecord` anyway. Root processes (uid 0) have no `ProcessRecord`, so they hit a `NullPointerException` inside `system_server`.

In smali, the null check is an `if-eqz v1` whose target is the `new-instance` of the Boox action, not the method's return.

## Fix

`scripts/patch_ams_dex.py` retargets that `if-eqz v1` to the method's final `return-void`, then fixes the dex SHA-1 and Adler-32 header fields. It refuses to patch unless there is exactly one `if-eqz v1` and the old target is a `new-instance`.

On 4.2-rel_04282 the branch is at file offset `0x2b2fee` in `classes.dex`, and the offset changes from `+51` to `+63`.

`classes.dex` is stored uncompressed in the jar, and the patched dex is the same size, so `scripts/patch_jar_entry.py` writes it back in place. Offsets and alignment stay put; only the CRC-32 changes.

This is the same fix as [boox-ams-fix](https://github.com/dynamicfire/boox-ams-fix), found by method lookup instead of a fixed offset so it works on other builds.

## Shipping it

`scripts/build-ams-module.sh` builds a Magisk module that:

- replaces `/system/framework/services.jar`;
- hides `oat/arm64/services.{odex,vdex,art}`, which no longer match the jar;
- aborts install on any build other than the one it was built for;
- disables itself after a boot that does not finish. Boox has no volume keys, so Magisk's safe mode is out of reach; this boot guard takes its place.

Rebuild it after every firmware update.

## Pulling `services.jar`

`adb pull` silently skips this file. Use `adb exec-out cat /system/framework/services.jar > services.jar` and compare `sha256sum` on both sides. The build script does this.
