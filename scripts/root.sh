#!/usr/bin/env bash
# Run a command as root on the tablet via the Magisk debug app.
# Usage: scripts/root.sh '<shell command>'
exec adb shell "run-as com.topjohnwu.magisk su -c $(printf '%q' "$*")"
