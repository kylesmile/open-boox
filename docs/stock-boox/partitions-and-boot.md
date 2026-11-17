# Partitions, bootloader and flashing

Checked on a Note Air 4C, firmware 4.2-rel_04282.

## Layout

- A/B slots (`boot_a`/`boot_b`, and so on). `ro.boot.slot_suffix` gives the active slot.
- Dynamic partitions in `super`.
- Separate `recovery_a`/`recovery_b`.
- **No `vendor_boot` or `init_boot`.** The ramdisk is in `boot` (boot header v2), so Magisk patches `boot`.
- Onyx-specific partitions: `onyxconfig`, `splash`.
- Storage is UFS with 6 LUNs. The partition list and LUN for each is in the EDL `printgpt` output (`scripts/edl-dump.sh` saves it as `gpt.txt`).

`boot_a` and `boot_b` can differ (the inactive slot likely holds the previous firmware). Always patch and flash the **active** slot's image.

## Bootloader and AVB

Our unit shipped with the bootloader **unlocked**:

```
ro.boot.flash.locked=0
ro.boot.verifiedbootstate=orange
ro.boot.vbmeta.device_state=unlocked
```

A Magisk-patched `boot` written over EDL boots without touching `vbmeta`. Other owners report locked bootloaders on other models (see [other-models.md](other-models.md)); check yours with the command below before anything else.

```bash
adb shell getprop | grep -E 'flash.locked|verifiedbootstate|vbmeta.device_state'
```

Untested ideas for a locked unit, gathered from forums and general Qualcomm practice:

- Look for "OEM unlocking" in Developer options. If present, enable it, then `fastboot flashing unlock` (wipes userdata).
- Set the "OEM unlock allowed" byte in `frp`, and/or the unlock flags in `devinfo`, over EDL, then unlock in fastboot. Diff EDL dumps before and after.
- A patched boot will not boot with AVB enforcing, so there is no "stay locked and root" path.

## Fastboot does not write

`fastboot boot` and `fastboot flash` both return `unknown command`. Use EDL for every write. Forum warning: `fastboot reboot fastboot` can leave the device stuck in fastbootd; use `fastboot reboot`.

## EDL (Qualcomm 9008)

- Enter with `adb reboot edl`. The screen goes nearly black and USB shows Qualcomm `05c6:9008`.
- [bkerler/edl](https://github.com/bkerler/edl) with the Lenovo/Motorola firehose loader `0000000000000000_bdaf51b59ba21d8a_fhprg.bin` from [bkerler/Loaders](https://github.com/bkerler/Loaders) gives full read and write of every partition.
- `edl` writes `edl_config.json` (local path and chip serial) into the working directory. It is gitignored here.
- `edl reset` reboots the tablet. If that fails, hold power.

`scripts/edl-dump.sh` and `scripts/edl-flash.sh` wrap these steps. As long as EDL works and you hold a full dump, a bad flash can be undone.
