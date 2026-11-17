# Front light

Checked on a Note Air 4C, firmware 4.2-rel_04282.

Two backlight devices, range 0–32, writable by root:

| Node | Controls |
|---|---|
| `/sys/class/backlight/onyx_bl_br/brightness` | brightness |
| `/sys/class/backlight/onyx_bl_ct/brightness` | warmth (color temperature) |

Tested by reading, changing and restoring each value:

```bash
scripts/root.sh 'cat /sys/class/backlight/onyx_bl_br/brightness'
scripts/root.sh 'echo 10 > /sys/class/backlight/onyx_bl_br/brightness'
```
