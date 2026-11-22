# De-bloat

Checked on a Note Air 4C, firmware 4.2-rel_04282. Back up first ([backup.md](backup.md)). Root is not needed.

`scripts/debloat.sh` removes built-in apps with `pm uninstall --user 0`. The APK stays on `/system`, so `scripts/debloat.sh revert` or a factory reset brings any app back. The app's data does not come back: Android deletes it at the next boot, even with `pm uninstall -k`. Back up an app's data first if you want it ([backup.md](backup.md#4-app-data-needs-root)).

**Tested:** `status`, `pick`, `apply -n`, `apply` removing 10 Boox apps in two batches and putting back an app set to `keep`, and `revert` on one app. **Untested:** `revert` with no packages named.

## The lists

- [`debloat/packages.txt`](../debloat/packages.txt) sorts the built-in apps into `keep`, `remove` and `decide`. Boox's extras (store, shop, AI assistant, mail, music, gallery and so on) default to `remove`. The reader, keyboards, cloud sync, firmware updates, the browser and Google's apps default to `decide`.
- `debloat/choices.txt` holds your own picks and wins over the defaults. It is not committed. The same format works by hand: one `keep <package>` or `remove <package>` per line.

Packages in neither file are never touched. The launcher and the keyboard in use, and core Android packages such as System UI and Settings, are never removed, whatever the files say.

## Steps

1. See the list, your picks, and what the tablet has:
   ```bash
   scripts/debloat.sh
   ```
2. Choose what to keep. `pick` asks about each app in the list; Enter keeps the current answer, and `q` stops:
   ```bash
   scripts/debloat.sh pick
   ```
   To ask about only a few, name them. A package not in the list can be named too:
   ```bash
   scripts/debloat.sh pick com.onyx.kreader com.android.bips
   ```
   Apps left at `decide` are not touched.
3. See what would change:
   ```bash
   scripts/debloat.sh apply -n
   ```
4. Apply it. This removes five apps at a time and reboots after each batch, then checks that each app is still gone. If you switched an app back to `keep`, it is put back first:
   ```bash
   scripts/debloat.sh apply
   ```
   Before each reboot it waits 15 seconds. Android saves which apps are removed about 10 seconds after a change, and a reboot before then undoes the removal; the first test lost 8 of 10 removals this way. It reboots through Android (`svc power reboot`), not `adb reboot`, for the same reason.

   Set `BATCH` to change the batch size, such as `BATCH=1` to find which app breaks something. If the tablet doesn't finish booting, the script prints the `revert` line for the last batch.

## Undo

Put back one app, or every removed app in the lists:

```bash
scripts/debloat.sh revert com.onyx.calculator
```

```bash
scripts/debloat.sh revert
```

`revert` alone puts the apps back but leaves your picks as they are, so the next `apply` removes them again. To keep an app for good, pick `keep` for it, then run `apply`.

## Notes

- Removing the dictionary breaks word lookup in the reader.
- Notes keeps sync records through `com.onyx.android.ksync`; whether Notes works without it is untested.
- A firmware update may bring removed apps back. Run `apply` again after one.
