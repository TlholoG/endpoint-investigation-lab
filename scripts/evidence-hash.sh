#!/bin/bash
# evidence-hash.sh
# Run from the Linux Mint live session. Hashes likely infection locations on the
# Windows drive (read-only) and saves the results to ~/evidence.
#
# Usage:
#   bash evidence-hash.sh                       # uses /media/mint/Windows8_OS
#   bash evidence-hash.sh /path/to/backup/dir   # also copies results to that folder

W="/media/mint/Windows8_OS"
DEST="$1"
OUT="$HOME/evidence"
mkdir -p "$OUT"

echo "== Step 0: make sure the Windows drive is mounted READ-ONLY =="
if findmnt -n "$W" >/dev/null 2>&1; then
    OPTS=$(findmnt -n -o OPTIONS "$W")
    case ",$OPTS," in
        *,ro,*) echo "Already read-only. Good." ;;
        *) echo "Mounted read-write. Remounting read-only..."
           sudo mount -o remount,ro "$W" || { echo "Could not remount read-only. Stopping."; exit 1; } ;;
    esac
else
    echo "Not mounted. Mounting read-only by label Windows8_OS..."
    sudo mkdir -p "$W"
    sudo mount -o ro -L Windows8_OS "$W" || { echo "Mount failed. Check lsblk -f. Stopping."; exit 1; }
fi
findmnt -n -o TARGET,FSTYPE,OPTIONS "$W"


echo; echo "== 1/6 Drive root: autorun files and executables =="
sudo find "$W" -maxdepth 1 -type f \( -iname 'autorun.inf' -o -iname '*.exe' -o -iname '*.scr' -o -iname '*.bat' -o -iname '*.vbs' \) -exec sha256sum {} + 2>/dev/null | tee "$OUT/01-root.txt"

echo; echo "== 2/6 AppData Roaming and Temp: executables =="
sudo find "$W/Users" -type f \( -iname '*.exe' -o -iname '*.scr' -o -iname '*.bat' -o -iname '*.vbs' -o -iname '*.dll' \) \( -ipath '*/AppData/Roaming/*' -o -ipath '*/AppData/Local/Temp/*' \) -exec sha256sum {} + 2>/dev/null | tee "$OUT/02-appdata.txt"

echo; echo "== 3/6 Executables inside user data folders =="
sudo find "$W/Users" -type f \( -iname '*.exe' -o -iname '*.scr' -o -iname '*.bat' -o -iname '*.vbs' \) \( -ipath '*/Documents/*' -o -ipath '*/Desktop/*' -o -ipath '*/Downloads/*' -o -ipath '*/Music/*' -o -ipath '*/Videos/*' -o -ipath '*/Pictures/*' \) -exec sha256sum {} + 2>/dev/null | tee "$OUT/03-userdata.txt"

echo; echo "== 4/6 Startup folders =="
: > "$OUT/04-startup.txt"
sudo sh -c "sha256sum \"$W\"/ProgramData/Microsoft/Windows/'Start Menu'/Programs/StartUp/* 2>/dev/null" | tee -a "$OUT/04-startup.txt"
sudo sh -c "sha256sum \"$W\"/Users/*/AppData/Roaming/Microsoft/Windows/'Start Menu'/Programs/Startup/* 2>/dev/null" | tee -a "$OUT/04-startup.txt"

echo; echo "== 5/6 Double extensions (for example photo.jpg.exe) =="
sudo find "$W" -type f -iregex '.*\.\(jpg\|jpeg\|png\|gif\|doc\|docx\|xls\|xlsx\|pdf\|mp3\|mp4\|avi\|txt\)\.\(exe\|scr\|bat\|vbs\)' -exec sha256sum {} + 2>/dev/null | tee "$OUT/05-double-extension.txt"

echo; echo "== 6/6 Scheduled task names (not hashed) =="
sudo ls -la "$W/Windows/System32/Tasks" 2>/dev/null | tee "$OUT/06-scheduled-tasks.txt"

echo; echo "== Summary =="
cat "$OUT"/0[1-5]*.txt 2>/dev/null | grep -E '^[0-9a-f]{64} ' > "$OUT/all-hashes.txt"
echo "Total hashes recorded: $(wc -l < "$OUT/all-hashes.txt")"
echo "Hashes that appear more than once (possible self-copying files):"
awk '{print $1}' "$OUT/all-hashes.txt" | sort | uniq -c | sort -rn | awk '$1>1' | head -20 | tee "$OUT/duplicates.txt"

echo
echo "Results saved in: $OUT"
if [ -n "$DEST" ] && [ -d "$DEST" ]; then
    cp -r "$OUT" "$DEST"/ && echo "Copied results to: $DEST/evidence"
else
    echo "Copy $OUT to your external drive before shutting down, or it will be lost."
fi
echo "Next: search the hashes in all-hashes.txt on virustotal.com (Search tab, hash only; do not upload private files)."