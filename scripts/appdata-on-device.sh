#!/system/bin/sh
# Runs ON THE TABLET as root. backup-app-data.sh and restore-app-data.sh push
# it to /data/local/tmp and call it through scripts/root.sh.
#
# Usage: appdata-on-device.sh backup  <package> <dir>
#        appdata-on-device.sh restore <package> <dir>
#
# backup writes, for one package, into <dir>:
#   <pkg>.tar     /data/data, /data/user_de and /data/media Android/data and
#                 obb folders, without the cache and code_cache folders
#   <pkg>.files   owner, group, mode, SELinux label and path of every entry
#   <pkg>.sha256  hash of every file
#   <pkg>.info    uid and versionCode when backed up
# restore unpacks <pkg>.tar and sets owner, group, mode and label of every
# entry from <pkg>.files, moving ids and labels to the app's current uid if it
# was reinstalled. It then checks the result against .files and .sha256.
#
# Toybox tar's --selinux segfaults on 4.2-rel_04282, so labels are kept in
# .files instead of in the tar. Paths with newlines are not supported.
set -eu
cmd="$1"; p="$2"; d="$3"
cd /

ALL="data/data/$p data/user_de/0/$p data/media/0/Android/data/$p data/media/0/Android/obb/$p"
CACHES="data/data/$p/cache data/data/$p/code_cache data/user_de/0/$p/cache data/user_de/0/$p/code_cache"

existing() { for x in $ALL; do [ -e "$x" ] && echo "$x"; done; return 0; }

# Every path except the cache folders, NUL separated. Extra find tests go in $@.
listing() {
  find $(existing) \( -path "data/data/$p/cache" -o -path "data/data/$p/code_cache" \
    -o -path "data/user_de/0/$p/cache" -o -path "data/user_de/0/$p/code_cache" \) \
    -prune -o "$@" -print0
}

snapshot() { # $1: .files output, $2: .sha256 output
  listing | xargs -0 -r -n 200 stat -c '%u %g %a %C %n' | sort > "$1"
  listing -type f | xargs -0 -r -n 200 sha256sum | sort > "$2"
}

case "$cmd" in
backup)
  [ -d "data/data/$p" ] || { echo "$p: no /data/data folder, skipped"; exit 3; }
  am force-stop "$p"
  {
    echo "uid=$(stat -c %u "data/data/$p")"
    dumpsys package "$p" 2>/dev/null | grep -m1 -oE 'versionCode=[0-9]+' || true
  } > "$d/$p.info"
  snapshot "$d/$p.files" "$d/$p.sha256"
  ex=""; for c in $CACHES; do ex="$ex --exclude $c"; done
  tar --numeric-owner $ex -cf "$d/$p.tar" $(existing)
  ;;

restore)
  [ -f "$d/$p.tar" ] || { echo "$p: no $p.tar"; exit 3; }
  [ -d "data/data/$p" ] || { echo "$p: not installed; install the app first"; exit 4; }
  old="$(sed -n 's/^uid=//p' "$d/$p.info")"
  new="$(stat -c %u "data/data/$p")"
  oa=$((old - 10000)); na=$((new - 10000))
  # Android app ids: uid 10000+a, cache gid 20000+a, ext gid 30000+a,
  # ext cache gid 40000+a, shared gid 50000+a. Labels carry categories
  # c<a&255>,c<256+a>>8>.
  mapid() {
    case "$1" in
      "$old"|$((20000 + oa))|$((30000 + oa))|$((40000 + oa))|$((50000 + oa))) echo $(($1 - oa + na)) ;;
      *) echo "$1" ;;
    esac
  }
  ocat=":c$((oa & 255)),c$((256 + (oa >> 8 & 255))),"
  ncat=":c$((na & 255)),c$((256 + (na >> 8 & 255))),"

  am force-stop "$p"
  for x in $ALL; do
    if [ -d "$x" ]; then
      find "$x" -mindepth 1 -maxdepth 1 ! -name cache ! -name code_cache -exec rm -rf {} +
    fi
  done
  tar --numeric-owner -xf "$d/$p.tar"

  # Set every entry from the record, and write what we expect to find.
  : > "$d/$p.expected"
  while read -r u g m c n; do
    u2="$(mapid "$u")"; g2="$(mapid "$g")"; c2="$(echo "$c" | sed "s/$ocat/$ncat/")"
    chown -h "$u2:$g2" "$n"
    [ -L "$n" ] || chmod "$m" "$n"
    chcon -h "$c2" "$n"
    echo "$u2 $g2 $m $c2 $n" >> "$d/$p.expected"
  done < "$d/$p.files"
  sort -o "$d/$p.expected" "$d/$p.expected"

  snapshot "$d/$p.after.files" "$d/$p.after.sha256"
  ok=1
  cmp -s "$d/$p.expected" "$d/$p.after.files" || { echo "$p: owners, modes or labels differ:"; diff "$d/$p.expected" "$d/$p.after.files" | head -20; ok=0; }
  cmp -s "$d/$p.sha256" "$d/$p.after.sha256" || { echo "$p: file contents differ:"; diff "$d/$p.sha256" "$d/$p.after.sha256" | head -20; ok=0; }
  [ "$ok" = 1 ] || exit 5
  echo "$p: restored $(wc -l < "$d/$p.files") entries, uid $old -> $new"
  ;;

*) echo "usage: $0 backup|restore <package> <dir>"; exit 2 ;;
esac
