# Reports from other Boox models

Collected from forums and other people's guides before working on the Note Air 4C. Where the Note Air 4C behaved differently, the note says so.

| Item | Report | Note Air 4C (4.2-rel_04282) | Source |
|---|---|---|---|
| SoC | Qualcomm "bitra" family (HWID `0013f0e1`), same chip as the Palma 2. Fairphone 4 (SM7225) ABL runs on the Note Air 5C. | `ro.soc.model=SM6350`, platform `lito`, board `lagoon` | MobileRead, Palma 2 guide |
| Bootloader | Locked on the Note Air 5C: `fastboot getvar unlocked` → `no`, `fastboot flashing unlock` hangs. | Shipped unlocked | MobileRead (5C thread) |
| EDL | Works with `adb reboot edl`, bkerler `edl` and the Lenovo/Motorola firehose loader. Full read and write. | Same | Palma 2 guide, 5C thread |
| A/B slots | Yes | Yes | Palma 2 guide |
| AVB | A Magisk-patched boot written over EDL failed to boot on a locked 5C. | Boots fine (unlocked) | 5C thread |
| Firmware decrypt | `decryptBooxUpdateUpx` has keys for many models | `NoteAir4C` key works | decryptBooxUpdateUpx |
| Root | `services.jar` NPE crashes Magisk's root daemon; patch your own `services.jar` and ship it as a module. Redo after every OTA. | Same bug ([services-jar-npe.md](services-jar-npe.md)) | boox-ams-fix, Palma 2 guide |
| Bluetooth audio | Broke for one rooted 5C user | Not tested | MobileRead (5C thread) |
| Kernel source | Not published by Onyx. No known custom ROM or GSI boot report for any Boox. | Same | MobileRead (LineageOS thread) |

Links are in the References section of the top-level README.
