#!/bin/bash
# inspect-startup-lnk.sh
# Run from the Linux Mint live session. Read-only inspection of the startup
# shortcuts figgewt.lnk and user.lnk. Nothing is executed or modified.
#
# Usage:
#   bash inspect-startup-lnk.sh
#   bash inspect-startup-lnk.sh /path/to/backup/dir    # also copies results there

W="/media/mint/Windows8_OS"
DEST="$1"
OUT="$HOME/evidence2"
REPORT="$OUT/startup-lnk-report.txt"
mkdir -p "$OUT"
: > "$REPORT"

say() { echo "$@" | tee -a "$REPORT"; }

say "== Step 0: make sure the Windows drive is mounted READ-ONLY =="
if findmnt -n "$W" >/dev/null 2>&1; then
    OPTS=$(findmnt -n -o OPTIONS "$W")
    case ",$OPTS," in
        *,ro,*) say "Already read-only. Good." ;;
        *) say "Mounted read-write. Remounting read-only..."
           sudo mount -o remount,ro "$W" || { say "Could not remount read-only. Stopping."; exit 1; } ;;
    esac
else
    say "Not mounted. Mounting read-only by label Windows8_OS..."
    sudo mkdir -p "$W"
    sudo mount -o ro -L Windows8_OS "$W" || { say "Mount failed. Check lsblk -f. Stopping."; exit 1; }
fi
findmnt -n -o TARGET,FSTYPE,OPTIONS "$W" | tee -a "$REPORT"

STARTUP=$(sudo find "$W/Users" -maxdepth 8 -type d -ipath '*/Start Menu/Programs/Startup' 2>/dev/null)

say; say "== 1/5 Shortcuts in all user Startup folders: timestamps and hashes =="
sudo find "$W/Users" "$W/ProgramData" -type f -iname '*.lnk' -ipath '*/Programs/Start*' 2>/dev/null | while IFS= read -r f; do
    say "--- $f"
    sudo stat -c 'size=%s bytes  modified=%y  changed=%z' "$f" 2>&1 | tee -a "$REPORT"
    sudo sha256sum "$f" 2>&1 | tee -a "$REPORT"
done

say; say "== 2/5 What do figgewt.lnk and user.lnk point to? (text inside the shortcut) =="
for name in figgewt.lnk user.lnk; do
    sudo find "$W/Users" -type f -iname "$name" -ipath '*/Programs/Start*' 2>/dev/null | while IFS= read -r f; do
        say; say "##### $f"
        say "-- ASCII strings:"
        sudo strings -a -n 4 "$f" | tee -a "$REPORT"
        say "-- UTF-16 strings (usually the real target path and arguments):"
        sudo strings -a -e l -n 4 "$f" | tee -a "$REPORT"
    done
done

say; say "== 3/5 Files on the drive named like the suspicious shortcut =="
sudo find "$W" -xdev -iname '*figgewt*' 2>/dev/null | tee -a "$REPORT"

say; say "== 4/5 Execution evidence in Windows Prefetch (names containing figgewt) =="
sudo ls -la "$W/Windows/Prefetch" 2>/dev/null | grep -i 'figgewt' | tee -a "$REPORT"
say "(Nothing listed above means no matching Prefetch entry was found.)"

say; say "== 5/5 Other scripts or shortcuts sitting directly in the user's Startup folders =="
echo "$STARTUP" | while IFS= read -r d; do
    [ -n "$d" ] && { say "--- $d"; sudo ls -la "$d" 2>/dev/null | tee -a "$REPORT"; }
done

say; say "Report saved: $REPORT"
if [ -n "$DEST" ] && [ -d "$DEST" ]; then
    cp -r "$OUT" "$DEST"/ && say "Copied results to: $DEST/evidence2"
else
    say "Copy $OUT to your external drive or the lab share before shutting down, or it will be lost."
fi
say "Do not run or double-click anything found here. Record the target path, then hash that file."
