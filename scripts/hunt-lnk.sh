#!/bin/bash
# hunt-lnk.sh
# Run from the Linux Mint live session. READ-ONLY: nothing on the Windows drive is
# executed or modified. Hunts for shortcut (.lnk) malware and the places it
# survives a restart: Startup folders, scheduled tasks, random-named AppData
# folders, registry strings, and the boot sector.
#
# Usage:
#   bash hunt-lnk.sh                       # results go to ~/evidence4
#   bash hunt-lnk.sh /path/to/backup/dir   # also copies the results there
#   SINCE=2026-11-01 bash hunt-lnk.sh      # change the "changed since" date (default 2026-11-13)

# Re-run as root so every file on the Windows drive can be read
if [ "$EUID" -ne 0 ]; then exec sudo -E bash "$0" "$@"; fi

W="${W:-/media/mint/Windows8_OS}"
SINCE="${SINCE:-2026-11-13}"
DEST="$1"
REALUSER="${SUDO_USER:-mint}"
REALHOME=$(getent passwd "$REALUSER" | cut -d: -f6)
REALHOME="${REALHOME:-/root}"
OUT="$REALHOME/evidence4"
mkdir -p "$OUT"
REPORT="$OUT/lnk-hunt-report.txt"
HASHES="$OUT/hit-hashes.txt"
: > "$REPORT"
: > "$HASHES"

say() { echo "$@" | tee -a "$REPORT"; }
section() { say; say "== $* =="; }

# Text patterns
STRONG='(/[ck] |-enc|-nop|-w hidden|https?://|\.vbs|\.vbe|\.jse?([^a-z0-9]|$)|\.wsf|\.hta|mshta|wscript|cscript|regsvr32)'
BROAD='(cmd\.exe|powershell|wscript|cscript|mshta|rundll32|regsvr32|\.vbs|\.vbe|\.jse?([^a-z0-9]|$)|\.wsf|\.hta|\.bat|\.ps1|https?://|AppData|ProgramData|Temp)'
IOCS='figgewt|vtfto|xyqaj|ahygoyu|savemax'

# A shortcut stores its target and arguments as text, so reading the text is enough.
# Nothing is ever executed.
lnk_strings() { { strings -a -e l -n 4 "$1"; strings -a -n 6 "$1"; } 2>/dev/null; }

section "Step 0: make sure the Windows drive is mounted READ-ONLY"
if [ -n "$SKIP_MOUNT_CHECK" ]; then
    say "Mount check skipped (test mode)."
elif findmnt -n "$W" >/dev/null 2>&1; then
    OPTS=$(findmnt -n -o OPTIONS "$W")
    case ",$OPTS," in
        *,ro,*) say "Already read-only. Good." ;;
        *) say "Mounted read-write. Remounting read-only..."
           mount -o remount,ro "$W" || { say "Could not remount read-only. Stopping."; exit 1; } ;;
    esac
    findmnt -n -o TARGET,FSTYPE,OPTIONS "$W" | tee -a "$REPORT"
else
    say "Not mounted. Mounting read-only by label Windows8_OS..."
    mkdir -p "$W"
    mount -o ro -L Windows8_OS "$W" || { say "Mount failed. Check lsblk -f. Stopping."; exit 1; }
    findmnt -n -o TARGET,FSTYPE,OPTIONS "$W" | tee -a "$REPORT"
fi
say "Only changes since $SINCE are listed in step 7."

section "1/9 Top level of the Windows drive"
ls -la "$W" 2>/dev/null | tee -a "$REPORT"

section "2/9 Startup folders (every user, and all users)"
find "$W/Users" "$W/ProgramData" -xdev -type d -ipath '*/Start Menu/Programs/Startup' 2>/dev/null | while IFS= read -r d; do
    say "### $d"
    find "$d" -maxdepth 1 -type f ! -iname 'desktop.ini' 2>/dev/null | while IFS= read -r f; do
        say "--- $f"
        stat -c '    size=%s bytes  modified=%y' "$f" | tee -a "$REPORT"
        h=$(sha256sum "$f" | cut -d' ' -f1)
        say "    sha256=$h"
        echo "$h  $f" >> "$HASHES"
        case "${f,,}" in
            *.lnk) lnk_strings "$f" | grep -iE "$BROAD" | sort -u | sed 's/^/    > /' | tee -a "$REPORT" ;;
        esac
    done
done

section "3/9 Shortcuts with embedded commands, scripts or web addresses (anywhere under Users and ProgramData)"
LIST="$OUT/.lnk-list.txt"
HITS3="$OUT/.hits3.txt"
{ find "$W/Users" "$W/ProgramData" -xdev -type f -iname '*.lnk' 2>/dev/null
  find "$W" -maxdepth 1 -type f -iname '*.lnk' 2>/dev/null; } > "$LIST"
say "Shortcuts scanned: $(wc -l < "$LIST")"
: > "$HITS3"
while IFS= read -r f; do
    hits=$(lnk_strings "$f" | grep -iE "$STRONG" | sort -u)
    if [ -n "$hits" ]; then
        h=$(sha256sum "$f" | cut -d' ' -f1)
        echo "$h  $f" >> "$HASHES"
        { echo "--- $f"
          stat -c '    size=%s bytes  modified=%y' "$f"
          echo "    sha256=$h"
          echo "$hits" | sed 's/^/    > /'; } >> "$HITS3"
    fi
done < "$LIST"
say "Shortcuts with suspicious content: $(grep -c '^--- ' "$HITS3")"
cat "$HITS3" >> "$REPORT"
head -300 "$HITS3"
say "(Legitimate shortcuts can match too, for example a Command Prompt shortcut. Judge each by its target.)"

section "4/9 Document-named shortcuts (name.pdf.lnk, name.jpg.lnk ...) outside Recent folders"
DOCS="$OUT/.docs-lnk.txt"
EXTRE='.*\.(pdf|jpe?g|png|gif|bmp|docx?|xlsx?|pptx?|txt|mp3|mp4|avi|mkv|zip|rar)\.lnk'
{ find "$W/Users" "$W/ProgramData" -xdev -type f -regextype posix-extended -iregex "$EXTRE" \
      ! -ipath '*/Recent/*' ! -ipath '*/AutomaticDestinations/*' ! -ipath '*/CustomDestinations/*' -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null
  find "$W" -maxdepth 1 -type f -regextype posix-extended -iregex "$EXTRE" -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null; } > "$DOCS"
say "Count: $(wc -l < "$DOCS")  (this is the pattern left by the 'originals hidden, shortcuts shown' behaviour)"
say "Folders holding them:"
sed 's#^[^ ]* [^ ]*  ##; s#/[^/]*$##' "$DOCS" | sort | uniq -c | sort -rn | head -20 | tee -a "$REPORT"
say "First 40 (date, path):"
head -40 "$DOCS" | tee -a "$REPORT"

section "5/9 Scheduled tasks outside Microsoft\\Windows (command lines)"
find "$W/Windows/System32/Tasks" "$W/Windows/Tasks" -type f ! -ipath '*/Tasks/Microsoft/*' 2>/dev/null | while IFS= read -r f; do
    cmds=$(iconv -f UTF-16 -t UTF-8 "$f" 2>/dev/null | grep -iE '<Command>|<Arguments>' | sed 's/^[ \t]*//')
    [ -z "$cmds" ] && cmds=$(strings -a -e l -n 5 "$f" 2>/dev/null | grep -iE '\.exe|\.js|\.vbs|\.bat' | head -3)
    say "--- $f  (modified $(stat -c %y "$f" | cut -d. -f1))"
    [ -n "$cmds" ] && echo "$cmds" | sed 's/^/    > /' | tee -a "$REPORT"
done

section "6/9 Random-looking folders in AppData that hold programs or scripts"
find "$W/Users" -mindepth 4 -maxdepth 4 -type d \( -ipath '*/AppData/Local/*' -o -ipath '*/AppData/Roaming/*' \) \
     -regextype posix-extended -regex '.*/[a-z]{5,10}' 2>/dev/null | while IFS= read -r d; do
    files=$(find "$d" -maxdepth 2 -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.js' -o -iname '*.jse' -o -iname '*.vbs' \
            -o -iname '*.vbe' -o -iname '*.bat' -o -iname '*.cmd' -o -iname '*.ps1' -o -iname '*.hta' -o -iname '*.wsf' \) 2>/dev/null | head -15)
    if [ -n "$files" ]; then
        say "--- $d"
        echo "$files" | while IFS= read -r f; do
            h=$(sha256sum "$f" | cut -d' ' -f1)
            echo "$h  $f" >> "$HASHES"
            printf '    %s  %s  sha256=%s\n' "$(stat -c %y "$f" | cut -d. -f1)" "$f" "$h" | tee -a "$REPORT"
        done
    fi
done

section "7/9 Scripts, programs and shortcuts changed since $SINCE (cache and browser noise removed)"
find "$W/Users" "$W/ProgramData" "$W/Windows/Temp" -xdev -type f \( -iname '*.js' -o -iname '*.jse' -o -iname '*.vbs' -o -iname '*.vbe' \
     -o -iname '*.wsf' -o -iname '*.hta' -o -iname '*.ps1' -o -iname '*.bat' -o -iname '*.cmd' -o -iname '*.exe' -o -iname '*.scr' -o -iname '*.lnk' \) \
     -newermt "$SINCE" -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null \
  | grep -viE 'node_modules|/Google/|/Mozilla/|/Packages/|/Recent/|/Chrome|Firefox|extensions|Cache|/Microsoft/(Windows/(Explorer|INetCache|WebCache)|Edge|Teams)' \
  | sort | head -300 | tee -a "$REPORT"

section "8/9 Known indicators and registry strings"
say "-- File or folder names matching: $IOCS"
find "$W/Users" "$W/ProgramData" "$W/Windows/Temp" "$W/Windows/Tasks" "$W/Windows/System32/Tasks" -xdev \
     -regextype posix-extended -iregex ".*($IOCS).*" 2>/dev/null | head -50 | tee -a "$REPORT"
say "-- Registry hives (rough text search; a real parser such as Autoruns or reglookup is better)"
for hive in "$W"/Users/*/NTUSER.DAT "$W/Windows/System32/config/SOFTWARE"; do
    [ -f "$hive" ] || continue
    say "--- $hive"
    strings -a -e l -n 5 "$hive" 2>/dev/null | grep -iE "$IOCS|AppData\\\\Local\\\\[a-z]{5,10}\\\\[a-z]{3,8}\.(exe|js|vbs)" | sort -u | head -30 | sed 's/^/    > /' | tee -a "$REPORT"
    if command -v reglookup >/dev/null 2>&1; then
        case "$hive" in
            *NTUSER.DAT) PREFIX="/Software/Microsoft/Windows/CurrentVersion" ;;
            *) PREFIX="/Microsoft/Windows/CurrentVersion" ;;
        esac
        for key in Run RunOnce; do
            say "    Run key: $PREFIX/$key"
            reglookup -p "$PREFIX/$key" "$hive" 2>/dev/null | sed 's/^/    > /' | tee -a "$REPORT"
        done
    fi
done
command -v reglookup >/dev/null 2>&1 || say "(reglookup is not installed, so Run keys were not listed. 'sudo apt install reglookup' works if the network is up.)"

section "9/9 Boot area: partition table and sector 0 (read-only copy)"
SRC=$(findmnt -n -o SOURCE "$W" 2>/dev/null)
DISKNAME=$(lsblk -no pkname "$SRC" 2>/dev/null | head -1)
DISKDEV="/dev/$DISKNAME"
if [ -n "$DISKNAME" ] && [ -b "$DISKDEV" ]; then
    fdisk -l "$DISKDEV" 2>/dev/null | tee -a "$REPORT"
    dd if="$DISKDEV" of="$OUT/mbr-sector0.bin" bs=512 count=1 2>/dev/null
    say "Sector 0 saved to: $OUT/mbr-sector0.bin"
    say "SHA-256 of the whole sector:            $(sha256sum "$OUT/mbr-sector0.bin" | cut -d' ' -f1)"
    say "SHA-256 of the boot code (440 bytes):   $(head -c 440 "$OUT/mbr-sector0.bin" | sha256sum | cut -d' ' -f1)"
    say "Boot signature (expect 55aa):           $(tail -c 2 "$OUT/mbr-sector0.bin" | xxd -p)"
    say "Readable text inside the boot code (a standard Windows MBR shows messages such as 'Invalid partition table'):"
    head -c 440 "$OUT/mbr-sector0.bin" | strings -n 6 | sed 's/^/    > /' | tee -a "$REPORT"
    say "(There is no baseline here. Compare with a known-clean Windows 8 laptop before drawing conclusions.)"
else
    say "Could not identify the physical disk; boot area skipped."
fi

section "Summary"
sort -u "$HASHES" -o "$HASHES"
say "Hashes recorded for lookup: $(wc -l < "$HASHES")  (file: $HASHES)"
say "Shortcuts with suspicious content: $(grep -c '^--- ' "$HITS3")"
say "Document-named shortcuts outside Recent: $(wc -l < "$DOCS")"
rm -f "$LIST" "$HITS3" "$DOCS"
chown -R "$REALUSER" "$OUT" 2>/dev/null

say
say "Report saved: $REPORT"
if [ -n "$DEST" ] && [ -d "$DEST" ]; then
    cp -r "$OUT" "$DEST"/ && chown -R "$REALUSER" "$DEST/evidence4" 2>/dev/null && say "Copied results to: $DEST/evidence4"
else
    say "Copy $OUT to your external drive before shutting down, or it will be lost."
fi
say "Next: search the hashes in hit-hashes.txt on virustotal.com (Search tab, hash only). Never run or upload personal files."
