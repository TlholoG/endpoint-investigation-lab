#!/bin/bash
# inspect-ahygoyu.sh
# Run from the Linux Mint live session. READ-ONLY. Nothing is executed or modified.
# Investigates the folder that figgewt.lnk launches (AppData\Local\ahygoyu) and
# lists recent file activity on the Windows drive.
#
# Usage:
#   bash inspect-ahygoyu.sh
#   bash inspect-ahygoyu.sh /path/to/backup/dir    # also copies results there

W="/media/mint/Windows8_OS"
DEST="$1"
OUT="$HOME/evidence3"
REPORT="$OUT/ahygoyu-report.txt"
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

say; say "== 1/6 Locate the ahygoyu folder(s) =="
DIRS=$(sudo find "$W/Users" -maxdepth 5 -type d -iname 'ahygoyu' 2>/dev/null)
say "${DIRS:-NOT FOUND under Users}"

say; say "== 2/6 Full listing, including hidden files, with sizes and dates =="
echo "$DIRS" | while IFS= read -r d; do
    [ -n "$d" ] && { say "--- $d"; sudo ls -laR --time-style=long-iso "$d" 2>&1 | tee -a "$REPORT"; }
done

say; say "== 3/6 Hashes and timestamps of every file in that folder =="
echo "$DIRS" | while IFS= read -r d; do
    [ -n "$d" ] && sudo find "$d" -type f 2>/dev/null | while IFS= read -r f; do
        sudo stat -c 'size=%s  modified=%y  %n' "$f" | tee -a "$REPORT"
        sudo sha256sum "$f" | tee -a "$REPORT"
    done
done

say; say "== 4/6 Is vtfto.exe a renamed Windows script host? Compare with the genuine files =="
say "(If vtfto.exe has the same hash as one of these, it is a renamed copy of that program.)"
sudo find "$W/Windows/System32" "$W/Windows/SysWOW64" -maxdepth 1 -type f \( -iname 'wscript.exe' -o -iname 'cscript.exe' -o -iname 'mshta.exe' \) -exec sha256sum {} + 2>/dev/null | tee -a "$REPORT"

say; say "== 5/6 Text of any .js file in that folder (first 4000 bytes). READ ONLY: do not run it =="
echo "$DIRS" | while IFS= read -r d; do
    [ -n "$d" ] && sudo find "$d" -type f -iname '*.js' 2>/dev/null | while IFS= read -r f; do
        say "##### $f  ($(sudo wc -c < "$f") bytes)"
        sudo head -c 4000 "$f" | tee -a "$REPORT"
        say; say "#####"
    done
done

say; say "== 6/6 Files changed since 2026-11-13 (timeline), cache and browser noise removed =="
sudo find "$W/Users" "$W/ProgramData" "$W/Windows/Temp" -xdev -type f -newermt '2026-11-13' -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null \
  | grep -viE 'cache|GPUCache|cookies|history|journal|Safe Browsing|Local Storage|IndexedDB|Session Storage|Crashpad|\.tmp$' \
  | sort | head -300 | tee -a "$REPORT"

say; say "Report saved: $REPORT"
if [ -n "$DEST" ] && [ -d "$DEST" ]; then
    cp -r "$OUT" "$DEST"/ && say "Copied results to: $DEST/evidence3"
else
    say "Copy $OUT to your external drive before shutting down, or it will be lost."
fi
say "Do not run or open anything found here. Record the findings, then look up the hashes on VirusTotal from Windows 11."
