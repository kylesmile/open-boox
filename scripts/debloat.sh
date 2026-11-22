#!/usr/bin/env bash
# Remove built-in apps, or put them back. Uses `pm uninstall --user 0`: the APK
# stays on /system, so `revert` or a factory reset brings the app back. Its data
# is gone after the next reboot, even with -k. Needs no root.
#
# Usage: scripts/debloat.sh [status]          the list, your picks, and the tablet
#        scripts/debloat.sh pick [package ...] choose keep or remove for each app
#        scripts/debloat.sh apply [-n]        remove what you chose, BATCH (5) at a
#                                             time, rebooting after each batch, and
#                                             put back apps you switched to keep;
#                                             -n only prints what it would do
#        scripts/debloat.sh revert [package ...]
#                                             put back removed apps (default: every
#                                             app in the list or your picks)
#
# Defaults: debloat/packages.txt. Your picks: debloat/choices.txt (not
# committed), same format, and they win. Packages in neither are not touched.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$ROOT/debloat/packages.txt"
CHOICES="$ROOT/debloat/choices.txt"
BATCH="${BATCH:-5}"
# Never removed, whatever the lists say. The launcher and keyboard in use are
# added at run time.
PROTECT="android com.android.systemui com.android.settings com.android.shell com.android.packageinstaller com.android.permissioncontroller com.android.providers.settings"

lines() { [ -f "$1" ] && grep -vE '^[[:space:]]*(#|$)' "$1" || true; }
default_of() { lines "$LIST" | awk -v p="$1" '$2 == p { print $1 }'; }
choice_of() { lines "$CHOICES" | awk -v p="$1" '$2 == p { a = $1 } END { print a }'; }
desc_of() { lines "$LIST" | awk -v p="$1" '$2 == p { $1 = $2 = ""; sub(/^ +/, ""); print }'; }
want_of() { local c; c="$(choice_of "$1")"; [ -n "$c" ] && echo "$c" || { c="$(default_of "$1")"; echo "${c:-keep}"; }; }
# Every package in the list, then any extra ones in your picks.
targets() { { lines "$LIST"; lines "$CHOICES"; } | awk '!seen[$2]++ { print $2 }'; }

# What the tablet has: ALL = every system package, ON = installed for user 0.
load_state() {
  adb wait-for-device
  ALL="$(adb shell pm list packages -s -u </dev/null | tr -d '\r' | sed 's/^package://')"
  ON="$(adb shell pm list packages -s </dev/null | tr -d '\r' | sed 's/^package://')"
  local home ime
  home="$(adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME </dev/null | tr -d '\r' | tail -1 | cut -d/ -f1)"
  ime="$(adb shell settings get secure default_input_method </dev/null | tr -d '\r' | cut -d/ -f1)"
  IN_USE="$home $ime"
}
has() { case $'\n'"$1"$'\n' in *$'\n'"$2"$'\n'*) return 0 ;; esac; return 1; }
state_of() {
  if has "$ON" "$1"; then echo installed
  elif has "$ALL" "$1"; then echo removed
  else echo absent; fi
}
protected() { case " $PROTECT $IN_USE " in *" $1 "*) return 0 ;; esac; return 1; }

set_choice() { # $1 action, $2 package
  local tmp; tmp="$(mktemp)"
  { [ -f "$CHOICES" ] && awk -v p="$2" '$2 != p' "$CHOICES"; echo "$1 $2"; } > "$tmp"
  mv "$tmp" "$CHOICES"
}

boot_id() { adb shell cat /proc/sys/kernel/random/boot_id </dev/null 2>/dev/null | tr -d '\r' || true; }

# Android saves who has which app about 10 s after a change, and `adb reboot`
# can cut the system off before it does, which undoes the removals. So wait
# for that save, reboot through the power manager, and wait for a new boot.
reboot_wait() {
  sleep 15
  local old t n=0 b="" id; old="$(boot_id)"
  adb shell svc power reboot </dev/null >/dev/null 2>&1 || true
  t="$(command -v timeout || command -v gtimeout || true)"
  while [ $n -lt 120 ]; do
    sleep 2; n=$((n + 1))
    ${t:+$t 10} adb wait-for-device 2>/dev/null || continue
    id="$(boot_id)"
    [ -n "$id" ] && [ "$id" != "$old" ] || continue
    b="$(adb shell getprop sys.boot_completed </dev/null 2>/dev/null | tr -d '\r' || true)"
    [ "$b" = 1 ] && return 0
  done
  return 1
}

status() {
  load_state
  printf '%-7s %-7s %-10s %-40s %s\n' WANT DEFAULT TABLET PACKAGE DESCRIPTION
  for p in $(targets); do
    local w d s note=""
    w="$(want_of "$p")"; d="$(default_of "$p")"; s="$(state_of "$p")"
    protected "$p" && note=" [in use, never removed]"
    printf '%-7s %-7s %-10s %-40s %s%s\n' "$w" "${d:--}" "$s" "$p" "$(desc_of "$p")" "$note"
  done
}

pick() {
  [ -t 0 ] || { echo "pick asks questions; run it in a terminal, or edit ${CHOICES#$ROOT/}."; exit 1; }
  local p cur ans new
  for p in $(targets); do
    [ $# -eq 0 ] || case " $* " in *" $p "*) ;; *) continue ;; esac
    cur="$(want_of "$p")"
    while :; do
      printf '%s  %s\n  now %s. [k]eep, [r]emove, Enter = %s, [q]uit: ' "$p" "$(desc_of "$p")" "$cur" "$cur"
      read -r ans || { echo; return 0; }
      case "$ans" in
        k|K) new=keep ;; r|R) new=remove ;; "") new="$cur" ;; q|Q) return 0 ;; *) continue ;;
      esac
      break
    done
    [ "$new" = decide ] || set_choice "$new" "$p"
  done
  # Packages named on the command line that are in neither file.
  local all; all="$(targets)"
  for p in "$@"; do
    has "$all" "$p" && continue
    printf '%s  (not in %s)\n  [k]eep, [r]emove, Enter = skip: ' "$p" "${LIST#$ROOT/}"
    read -r ans || { echo; return 0; }
    case "$ans" in k|K) set_choice keep "$p" ;; r|R) set_choice remove "$p" ;; esac
  done
  echo "Saved to ${CHOICES#$ROOT/}. Run scripts/debloat.sh apply -n to see what changes."
}

apply() {
  local dry=0; [ "${1:-}" = -n ] && dry=1
  load_state
  local p w s gone=() back=() open=() skip=()
  for p in $(targets); do
    w="$(want_of "$p")"; s="$(state_of "$p")"
    case "$w:$s" in
      remove:installed) if protected "$p"; then skip+=("$p"); else gone+=("$p"); fi ;;
      keep:removed) back+=("$p") ;;
      decide:installed) open+=("$p") ;;
    esac
  done
  [ ${#skip[@]} -eq 0 ] || echo "In use, not removed: ${skip[*]}"
  [ ${#open[@]} -eq 0 ] || echo "Not decided yet, left alone (scripts/debloat.sh pick): ${open[*]}"
  [ ${#back[@]} -eq 0 ] || { echo "To put back (${#back[@]}):"; printf '  %s\n' "${back[@]}"; }
  [ ${#gone[@]} -eq 0 ] || { echo "To remove (${#gone[@]}), $BATCH per reboot:"; printf '  %s\n' "${gone[@]}"; }
  [ ${#gone[@]} -gt 0 ] || [ ${#back[@]} -gt 0 ] || { echo "Nothing to change."; return 0; }
  [ "$dry" = 0 ] || return 0

  local fail=0
  [ ${#back[@]} -eq 0 ] || revert "${back[@]}" || fail=1
  local i=0 batch
  while [ $i -lt ${#gone[@]} ]; do
    batch=("${gone[@]:$i:$BATCH}")
    echo "== Batch $((i / BATCH + 1)): ${batch[*]}"
    for p in "${batch[@]}"; do
      echo "   $p: $(adb shell pm uninstall --user 0 "$p" </dev/null | tr -d '\r')"
    done
    echo "   rebooting..."
    reboot_wait || { echo "Tablet did not finish booting. Put this batch back with:"
                     echo "  scripts/debloat.sh revert ${batch[*]}"; exit 1; }
    load_state
    for p in "${batch[@]}"; do
      s="$(state_of "$p")"
      [ "$s" = removed ] || { echo "   $p: $s after reboot"; fail=1; }
    done
    i=$((i + BATCH))
  done
  [ "$fail" = 0 ] && echo "Done." || echo "WARNING: some packages did not end up as chosen; see above."
  return "$fail"
}

revert() {
  [ -n "${ON:-}" ] || load_state
  local p pkgs=() fail=0
  if [ $# -gt 0 ]; then pkgs=("$@"); else
    for p in $(targets); do [ "$(state_of "$p")" = removed ] && pkgs+=("$p"); done
  fi
  [ ${#pkgs[@]} -gt 0 ] || { echo "Nothing to put back."; return 0; }
  for p in "${pkgs[@]}"; do
    echo "   $p: $(adb shell cmd package install-existing --user 0 "$p" </dev/null 2>&1 | tr -d '\r')"
  done
  load_state
  for p in "${pkgs[@]}"; do
    [ "$(state_of "$p")" = installed ] || { echo "   $p: still $(state_of "$p")"; fail=1; }
  done
  return "$fail"
}

cmd="${1:-status}"; [ $# -gt 0 ] && shift
case "$cmd" in
  status) status ;;
  pick) pick "$@" ;;
  apply) apply "$@" ;;
  revert) revert "$@" ;;
  *) sed -n '2,16p' "$0"; exit 2 ;;
esac
