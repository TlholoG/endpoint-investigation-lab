# 🛡️ Endpoint Investigation Lab

## Project Status

🚧 **In Progress: Phase 1 complete, Phases 2 to 4 under way**

The lab network is built and working. The legacy Windows 8 laptop sits in an isolated network segment and is administered remotely from a Windows 11 workstation. Its drive has been examined read-only from a Linux Mint live USB. Windows booted by mistake once or twice before the boot menu was reached, so the drive was not perfectly untouched. Hashing and triage of likely hiding places turned up two suspicious Startup shortcuts, and Microsoft Defender later flagged shortcut files with embedded commands on the live USB itself. All of this is under investigation.

**Next:** rebuild the contaminated live USB, analyse what those shortcuts launch, back up the laptop's data, then plan remediation.

The project started as an idea for investigating a suspected malware infection on a legacy Windows laptop. It has grown into a broader **home networking, Windows administration, and cybersecurity laboratory**.

---

## 📌 Overview

The original idea came from a real issue: an older Windows laptop showing abnormal behaviour, including unusual USB file handling (files hidden inside a folder on a memory stick when it is plugged in) and instability during large file transfers. The laptop holds personal data from 2010 onward, so the goal is to investigate it and preserve that data rather than immediately formatting the machine.

### Key results so far

- Built an isolated double-NAT lab network and verified it with ping tests.
- Collected evidence from a Linux Mint live USB with the Windows drive mounted read-only.
- Microsoft Defender flagged shortcut files with embedded commands on my live USB (`Trojan:Win32/LNKRunner.HNAE!MTB`). They were created after the stick was formatted, which shows the infection spreads to removable media.
- Exported and reviewed Windows 11's Defender log: 222 events, all the same detection on a removable drive (`D:`), on five dates from 26 February to 16 November 2026, and none on the system drive `C:`. The same document-named shortcuts recur across the dates, so it was most likely the same stick each time.
- Hashed and triaged 290 files (248 unique hashes) from likely hiding places, and explained the repeated hashes as benign.
- Found two suspicious Startup shortcuts: one launches a randomly named program and script from `AppData\Local`, and was modified on 14 November 2026.
- Mapped the behaviour to MITRE ATT&CK techniques, marked Observed or Suspected.
- Audited my own network shares, found an unexpected exposed share, and removed it.

---

## 🎯 Project Objectives

- Design and document a home network environment.
- Investigate the behaviour of a legacy Windows endpoint.
- Practice Windows administration and troubleshooting.
- Implement secure remote administration.
- Apply networking concepts in a practical environment.
- Safely preserve and back up important data.
- Investigate potential malware or persistence mechanisms.
- Collect and analyse Windows security and system logs.
- Practice PowerShell administration and automation.
- Document findings and remediation procedures.

---

## 🗺️ Network Topology

![Network topology](images/network-topology.svg)

The D-Link router is connected behind the Huawei router, which creates a double NAT. Lab devices can reach the internet, but household devices cannot reach the lab.

### Addressing

| Device                                  | Address     | Notes                              |
| --------------------------------------- | ----------- | ---------------------------------- |
| Huawei WS7100 (household gateway)       | 192.168.3.1 | Household subnet 192.168.3.x       |
| D-Link DWR-957M, WAN side               | 192.168.3.x | Assigned by the Huawei via DHCP    |
| D-Link DWR-957M, LAN side (lab gateway) | 10.0.0.2    | Lab subnet 10.0.0.x                |
| Windows 8 laptop (`idea-pc`)          | 10.0.0.x    | Reserve this address in the D-Link |

The two subnets do not overlap, so no change to the D-Link's LAN address was needed.

---

## 🧰 Hardware Register

| Item                          | Details                                                                  | Role                                           | Status                          |
| ----------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------- | ------------------------------- |
| Fibre wall terminal and modem | ISP supplied                                                             | ISP connection                                 | In use                          |
| Huawei WS7100                 | Household router                                                         | Household router and Wi-Fi                     | In use                          |
| D-Link DWR-957M               | LTE-capable router, WAN port used                                        | Lab router                                     | In use                          |
| Windows 11 computer           | Lenovo, Intel Core i5-10210U, 8 GB RAM, 477 GB storage                   | Admin workstation, builds the live USB         | In use                          |
| Windows 8 laptop              | Lenovo, Intel Celeron B830 1.80 GHz, 2 GB RAM, 500 GB Hitachi hard drive | Suspected-infected lab target, data since 2010 | In use                          |
| 32 GB USB flash drive         | Linux Mint 22.3 MATE live USB                                            | Boots the laptop without starting Windows      | Contaminated, to be rebuilt     |
| External hard drive           | Transcend 1 TB (TS1TSJ25D3), about 931 GB usable, made 2015              | Backup destination (lab-only)                  | Available, health check pending |
| Ethernet cables               |                                                                          | Router link and lab connections                | In use                          |

## 💾 Software Register

| Software                  | Version              | Installed on                               | Purpose                                                                            | Source                       |
| ------------------------- | -------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------- | ---------------------------- |
| TightVNC Server           | 4.0.2 (free edition) | Windows 8 laptop                           | Remote screen access                                                               | Official TightVNC website    |
| TightVNC Viewer           | To be recorded       | Windows 11 computer                        | Remote control client                                                              | Official TightVNC website    |
| Linux Mint (MATE, 64-bit) | 22.3                 | Downloaded on Windows 11, for the live USB | Live environment for investigating the laptop without running the infected Windows | NTT DATA South Africa mirror |
| Rufus                     | 4.15                 | Windows 11 computer                        | Writes the ISO to the USB                                                          | Official Rufus website       |

### Tools used

Git and GitHub, VS Code, Git Bash, PowerShell, `certutil`, `net share`, `icacls`, `net user`, `Get-WinEvent`, `Get-MpThreatDetection`, and on Linux `lsblk`, `findmnt`, `mount`, `sha256sum`, `find`, `strings` and `stat`.

### Download integrity

| File                          | SHA-256                                                              | Result                                                                                            |
| ----------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| linuxmint-22.3-mate-64bit.iso | `7609294da613b75eea89bb918292125e9f06418a368136fb190466e15bf8c373` | Matches the `sha256sum.txt` on the Harvard Linux Mint mirror. GPG signature check not yet done. |

Checksum command used on Windows 11: `certutil -hashfile <filename> SHA256`

### Planned software

- VirusTotal (hash lookups only, no files uploaded)
- Sysinternals Autoruns and Process Explorer
- Wireshark
- VirtualBox or VMware with a Kali Linux VM
- Nmap and OpenVAS
- ClamAV or Malwarebytes (scanning backed-up data from a clean environment)

---

## 🔧 Configuration Summary

1. Connected a Huawei LAN port to the D-Link WAN port.
2. Left the D-Link's existing carrier profile (Service Type `TR069_INTERNET_VOIP`) unchanged.
3. Created a new WAN connection with Service Type `INTERNET`, IPv4, NAT on, firewall on, VLAN off, static DNS off, MAC override off.
4. Selected the new connection as the default route.
5. Verified connectivity with ping tests (below).
6. Installed TightVNC Server on the Windows 8 laptop and the Viewer on Windows 11, and confirmed a working remote session.

## ✅ Verification

| Test                                                                      | Result                                                  |
| ------------------------------------------------------------------------- | ------------------------------------------------------- |
| Laptop pings 10.0.0.2 (D-Link)                                            | Success                                                 |
| Laptop pings 8.8.8.8 (internet by IP)                                     | Success                                                 |
| Laptop pings google.com (DNS)                                             | Success                                                 |
| Phone on the D-Link Wi-Fi reaches the internet                            | Success                                                 |
| Laptop pings 192.168.3.1 (Huawei)                                         | Destination host unreachable, which indicates isolation |
| Windows 11 pings the laptop's 10.0.0.x address from the household network | Pending                                                 |
| Laptop opens 192.168.3.1 in a browser                                     | Pending                                                 |
| Remote session from Windows 11 to the laptop over VNC                     | Success                                                 |

---

## 🔬 Evidence Collection Method

1. Booted the laptop from a **Linux Mint live USB**, so the collection itself ran from a clean environment. Windows booted by mistake once or twice before the boot menu key was pressed, so the drive was not perfectly untouched.
2. Mounted the Windows partition **read-only** and confirmed it with `findmnt` (`ro`). Mint had automounted it first, so it was remounted read-only before anything was read.
3. Ran read-only scripts (see below) that hash executables in likely hiding places and read Startup shortcuts. Results were written to a separate folder, never to the Windows drive.
4. Moved the scripts in, and the results out, over a temporary SMB share on the lab network, using a dedicated low-privilege account. The shares and the account were removed afterwards.
5. Kept the raw evidence **outside this repository** and excluded it with `.gitignore`. Only cleaned findings are published here.
6. Because Windows started while the stick was inserted, the live USB was contaminated. It is being rebuilt, and the BIOS boot order will be set to start from USB first.

---

## 🔎 Investigation Findings (in progress)

### Hash triage

| Location checked                                  | Hashes                     |
| ------------------------------------------------- | -------------------------- |
| Drive root (autorun files and executables)        | 0                          |
| `AppData\Roaming` and `AppData\Local\Temp`    | 129                        |
| Executables inside user data folders              | 155                        |
| Startup folders                                   | 6                          |
| Double extensions (for example `photo.jpg.exe`) | 0                          |
| **Total**                                   | **290 (248 unique)** |

Repeated hashes were traced to their paths and explained as benign: copies of an SDK's tools inside student project backups, a project build that appears in both `bin` and `obj`, Zoom installer copies, and Windows `desktop.ini` files. Identical copies of the same tools across backups made at different times also suggest those files have not been modified.

These results apply only to the locations checked. They are not proof that the drive is clean. Because Windows booted once or twice during the project, some timestamps on the laptop drive may have changed after the first Mint session.

### Startup shortcuts reviewed

| Shortcut                            | What it does                                                               | Assessment                                                                                                                                                               |
| ----------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Canon LBP2900 Status Window.lnk` | Printer driver status window                                               | Benign                                                                                                                                                                   |
| `desktop.ini` (three copies)      | Created by Windows in Startup folders                                      | Benign                                                                                                                                                                   |
| `Start Tor Browser.lnk`           | Tor Browser shortcut                                                       | Benign, installed by me in 2019                                                                                                                                          |
| `figgewt.lnk`                     | Launches `AppData\Local\ahygoyu\vtfto.exe` and passes `xyqaj.js` to it | **Suspicious.** Random names, a script argument, modified 2026-11-14 23:32 UTC, during the lab setup. Target files not yet examined.                               |
| `user.lnk`                        | Runs `cmd.exe /c explorer hxxp://www2[.]savemax[.]store/` at logon       | **Suspicious, adware-style behaviour.** Dated 2020-05-29. Shortcut metadata shows it was created on this laptop (`idea-pc`), which rules out an external origin. |

These are indicators, not confirmed malware. No VirusTotal lookups have been done yet, and the target program and script have not been analysed.

### Removable media infection

On 16 November 2026 at 00:57, Microsoft Defender on a clean machine flagged several shortcut files on my Linux Mint live USB as `Trojan:Win32/LNKRunner.HNAE!MTB` (alert level Severe, category Trojan).

| Detail             | Observation                                                                                                                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Affected items     | Shortcut files such as `autorun.ico.lnk`, `efi.img.lnk`, `ldlinux.sys.lnk`, `md5sum.txt.lnk`, `syslinux.cfg.lnk` and `md5sum.README.lnk`, each containing an embedded command |
| Timing             | The shortcuts are named after files that Rufus creates when it builds the Mint stick, so they were created **after** the stick was formatted                                        |
| Likely cause       | The laptop booted into Windows once or twice with the stick inserted, before the boot menu key was pressed. This is not proven.                                                           |
| Other locations    | None of the listed items was on the system drive `C:`                                                                                                                                   |
| Status at the time | Alert marked Active; removal and a full scan to follow                                                                                                                                    |

This is consistent with the shortcut behaviour seen on the laptop, but I have not shown that it is the same malware as `figgewt.lnk` or `user.lnk`. Microsoft's own entry for this detection says Defender detects and removes it.

### Defender detection history (Windows 11)

I exported Windows 11's Defender Operational log (event IDs 1116 to 1119) and reviewed it. Times are local (SAST, UTC+2).

| Date (local) | Time window    | Detection events | Notes                                                                         |
| ------------ | -------------- | ---------------- | ----------------------------------------------------------------------------- |
| 2026-02-26   | 10:24 to 10:25 | 35               | Earliest detection on record                                                  |
| 2026-03-09   | 20:02 to 21:16 | 56               |                                                                               |
| 2026-03-12   | 14:05 to 14:06 | 69               |                                                                               |
| 2026-11-14   | 22:20 to 22:24 | 35               | Shortcuts named after my own documents and photos; one remediation failed     |
| 2026-11-16   | 00:56 to 00:57 | 13               | Shortcuts named after Linux Mint files, created after the stick was formatted |

In total there were 222 events: 208 detections (ID 1116), 12 quarantine actions (ID 1117) and 2 failed remediations (ID 1119).

**What the log shows**

- Every event names the same threat, `Trojan:Win32/LNKRunner.HNAE!MTB`, and every flagged path is a `.lnk` file on drive `D:`. None is on `C:`.
- Real-time protection raised each one when `explorer.exe` touched the drive, which means it was caught when the removable drive was opened, before anything ran.
- The same document-named shortcuts recur from February to November, so it was most likely the same infected stick plugged in repeatedly.
- The shortcuts are named after real files with `.lnk` added (for example `name.pdf.lnk`). My own observation is that the originals were moved into a hidden folder, so the shortcuts were all that remained visible.
- The failed remediations and "could not find the malware" errors fit a stick that was removed or formatted before Defender finished. That is my inference.

**What it does not show**

- Whether the laptop or the stick was infected first.
- That the laptop runs the same malware. Defender only saw the stick's shortcuts, and the laptop's own files have not been compared yet.
- That Windows 11 is clean. A full scan is still to be done and recorded.

**Timing note:** `figgewt.lnk` was modified at 2026-11-14 23:32 UTC, which is 01:32 local time on 15 November. That is about an hour and a half after Defender abandoned remediation of the stick (00:08). The timing is close, but I have not shown that the two events are related.

### MITRE ATT&CK mapping

| Technique                                                                       | Status    | Evidence                                                                                                              |
| ------------------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------- |
| T1547.001 Boot or Logon Autostart Execution: Registry Run Keys / Startup Folder | Observed  | Two shortcuts in the user's Startup folder                                                                            |
| T1059.003 Command and Scripting Interpreter: Windows Command Shell              | Observed  | `cmd.exe /c` in `user.lnk`                                                                                        |
| T1059.007 Command and Scripting Interpreter: JavaScript                         | Suspected | `xyqaj.js` passed to `vtfto.exe`                                                                                  |
| T1036 Masquerading                                                              | Suspected | `vtfto.exe` may be a renamed system utility                                                                         |
| T1091 Replication Through Removable Media                                       | Observed  | Defender detection of shortcut files with embedded commands on removable media, created after the stick was formatted |
| T1564.001 Hide Artifacts: Hidden Files and Directories                          | Observed  | Original files hidden on my stick while shortcuts were shown in their place (my own observation)                      |
| T1036.007 Masquerading: Double File Extension                                   | Observed  | `name.pdf.lnk` shortcuts named after real files (Defender log)                                                      |
| T1204.002 User Execution: Malicious File                                        | Suspected | A shortcut needs a click to run; I have not observed that step                                                        |

Reference: MITRE ATT&CK®, https://attack.mitre.org/, Enterprise matrix, version v20.1, accessed 16 November 2026. ATT&CK® is a registered trademark of The MITRE Corporation.

---

## 🛠️ Scripts

All scripts are read-only: they mount the Windows drive read-only, run nothing from it, and write results to a separate folder that is excluded from Git. I wrote them with AI assistance, then reviewed each step, ran them on my own lab, and corrected the gaps I found.

| Script                                 | Purpose                                                                                                                                    | Status                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| `scripts/evidence-hash.sh`           | Hashes executables in likely hiding places and flags repeated hashes                                                                       | Run                                                     |
| `scripts/inspect-startup-lnk.sh`     | Reads the targets, timestamps and hashes of Startup shortcuts                                                                              | Run                                                     |
| `scripts/inspect-ahygoyu.sh`         | Lists and hashes the folder launched by the suspicious shortcut, compares `vtfto.exe` with genuine script hosts, and builds a timeline   | Written, not yet run                                    |
| `scripts/export-defender-events.ps1` | Exports Windows 11's Defender detection events to a private CSV, prints a summary by day, threat and drive, and records a file fingerprint | Written, not yet run (the same export was done by hand) |

---

## 🩹 Troubleshooting Log

| Problem                                                              | Cause                                                                            | Resolution                                                                                                  |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Unsure if the IPv4 configuration tab sets the internet connection    | That tab controls the router's own LAN side, not the upstream link               | Used the WAN settings instead                                                                               |
| Edit the existing WAN entry or create a new one                      | The existing entry was a carrier management profile                              | Left it alone and created a new `INTERNET` WAN service                                                    |
| No field to enter an IP address                                      | The Huawei assigns the address via DHCP                                          | Nothing to enter; confirmed the WAN IP on the status page                                                   |
| Dynamic Route offered RIP, OSPF and BGP                              | These are router-to-router protocols and are not needed here                     | Backed out and used Default Route                                                                           |
| Windows 8 laptop reached the admin page but not websites             | The admin page is local. The laptop's Chrome is outdated                         | Confirmed the network with ping tests and a phone on the D-Link Wi-Fi                                       |
| Ping to 192.168.3.1 showed "host unreachable" but 4 packets received | Windows counts an error from a nearby device as a received packet                | Read as correct isolation                                                                                   |
| Remote Desktop unavailable                                           | Windows 8 Single Language is a Home-level edition and cannot accept incoming RDP | Used TightVNC instead                                                                                       |
| Firefox extremely slow in the live session                           | The laptop has 2 GB RAM and a live session keeps its files in memory             | Ran scripts in the terminal and did lookups from Windows 11                                                 |
| Windows drive auto-mounted when Mint started                         | Mint mounts drives automatically, possibly read-write                            | Remounted read-only and confirmed `ro` with `findmnt`                                                   |
| Share not visible from Mint ("Could not display smb://...")          | `net share` showed the folder was never shared                                 | Created the share from the command line                                                                     |
| `net share` returned "System error 5, Access is denied"            | The Command Prompt was not running as administrator                              | Reopened it as administrator                                                                                |
| Unexpected `Users` share with Everyone: Full on Windows 11         | Left by an earlier sharing attempt                                               | Found with `net share` and deleted it                                                                     |
| `icacls` hung while removing a lab account's permission            | The account still had an open session from the laptop                            | Closed the session and deleted the account; the orphaned entry grants no access                             |
| Evidence folder was staged by Git and `.gitignore` had no effect   | The file was saved as `gitignore`, without the leading dot                     | Unstaged the files and renamed the file                                                                     |
| Laptop booted into Windows before the boot menu key was pressed      | A slow key press against the boot timer, and no BIOS boot order set              | Planned fix: set USB first in the BIOS boot order and use a full shutdown                                   |
| Defender flagged shortcut files on the Mint live USB                 | Windows started with the stick inserted, and the infection wrote shortcuts to it | Treat the stick as contaminated; remove the files, then rebuild it with Rufus and re-check the ISO checksum |

---

## 🔐 Security Measures

- The suspected-infected laptop stays off the household network and sits only behind the D-Link.
- NAT and the firewall are enabled on the lab WAN connection.
- Evidence is collected from a live USB with the Windows drive mounted read-only. The BIOS boot order should put the USB first, because a missed boot key let Windows start once or twice.
- Any USB drive that has been in the laptop while Windows was running is treated as contaminated, and is scanned with Defender before further use, because the behaviour observed suggests the infection spreads through removable media.
- The Windows 8 laptop receives no security patches, so it is treated as compromised and not used for real logins.
- VNC is unencrypted, so it is used only inside the lab network, never forwarded to the internet, and with a strong password.
- File transfer and clipboard sharing are disabled in the remote session, so nothing moves from the laptop to Windows 11.
- Temporary network shares used a dedicated low-privilege account, were audited with `net share` and `icacls`, and were deleted after use.
- Raw evidence stays outside the repository, and indicators such as web addresses are written in defanged form.
- Download checksums are verified before use.

---

## 🗺️ Roadmap

### Phase 1: Lab & Network Preparation ✅

- [X] Document available hardware
- [X] Document the existing network
- [X] Create a network topology diagram
- [X] Configure the administrative workstation
- [X] Establish controlled connectivity between devices
- [X] Document IP addressing and network configuration

### Phase 2: Data Preservation 🔄

- [X] Download and verify the Linux Mint 22.3 MATE ISO
- [X] Create the bootable live USB
- [X] Mount the laptop's drive read-only from the live USB
- [ ] Rebuild the contaminated live USB and set the BIOS boot order to start from USB first
- [ ] Identify important data
- [ ] Create backups (read-only copy of the original, then a working copy)
- [ ] Verify backup integrity
- [ ] Document the backup process

### Phase 3: Windows Administration 🔄

- [ ] Configure administrative access
- [X] Practice PowerShell administration
- [ ] Review Windows services
- [ ] Review scheduled tasks
- [X] Review startup applications
- [X] Audit exposed network shares and permissions on Windows 11
- [ ] Configure appropriate security controls

### Phase 4: Endpoint Investigation 🔄

- [ ] Review Windows Event Logs (Windows 11 Defender log reviewed; the laptop's logs are still to do)
- [ ] Investigate suspicious processes
- [ ] Examine network connections
- [ ] Investigate USB-related behaviour (initial evidence: Defender detection on removable media)
- [X] Triage file hashes from likely hiding places
- [X] Identify possible persistence mechanisms
- [ ] Analyse the targets of the suspicious shortcuts
- [ ] Look up suspicious hashes on VirusTotal
- [ ] Document findings (in progress)

### Phase 5: Remediation

- [ ] Develop a remediation strategy
- [ ] Remove identified threats where appropriate
- [ ] Verify system integrity
- [ ] Verify network behaviour
- [ ] Test system stability
- [ ] Document the remediation process

### Phase 6: Documentation & Portfolio 🔄

- [ ] Document the final network topology
- [ ] Document investigation findings
- [ ] Document remediation steps
- [ ] Record lessons learned (in progress)
- [ ] Add screenshots and technical evidence
- [ ] Update the README with completed work

---

## ⏭️ Next Steps

1. Let Defender remove the flagged shortcuts, then rebuild the live USB with Rufus, re-check the ISO checksum, and set the BIOS boot order to start from USB first.
2. Run `inspect-ahygoyu.sh` to examine what the suspicious shortcut launches, and compare `vtfto.exe` with the genuine Windows script host.
3. Look up the hashes on VirusTotal and read the script as text, without running it.
4. Back up the laptop's data to the external drive, after checking the drive's health.
5. Review scheduled tasks, services and the registry Run keys for further persistence.
6. Copy the laptop's event logs (`.evtx` files) in a Mint session and open them in Event Viewer on Windows 11.
7. Plan remediation only after the evidence is documented.

---

## 🧠 Skills Being Developed

Windows administration, networking, PowerShell, endpoint investigation, incident response, troubleshooting, backup and recovery, access control, security monitoring, root cause analysis and technical documentation.

---

## 📝 Lessons Learned So Far

- Router firmware menus differ by model, so identify whether a tab controls the LAN side or the WAN side before changing it.
- Leave carrier-provisioned profiles alone and create a new profile instead of editing them.
- Windows ping output can mislead, so read the address that replied, not just the statistics.
- Check the Windows edition before planning around built-in features such as Remote Desktop.
- My first hashing script only searched `AppData\Roaming`, `Temp` and a short list of file types, so it missed `AppData\Local` and `.js` files. A shortcut's target pointed me to the gap, which taught me to read results critically and widen the search.
- Auditing my own shares with `net share` found an exposed share I had not created on purpose, so check what is exposed, not just what you set up.
- A clean result in the places checked is a finding, but it is not proof of a clean system.
- Keep raw evidence out of version control, and describe findings as indicators until they are confirmed.
- Set the BIOS boot order before attaching a live USB to a suspect machine. A missed boot key let Windows start and contaminated the stick.
- Treat every removable drive that has touched a suspect machine as contaminated until it has been scanned.
- Export security logs early and read the whole history. Defender's log showed the same detection on five dates since February 2026, which I would have missed if I had only looked at the latest alert.
- Compare timestamps in one time zone. Defender shows local time, while file timestamps read from Linux are in UTC.

---

## ⚠️ Disclaimer

This laboratory is intended for **educational and defensive security purposes**. Any investigation, testing, scanning, or configuration changes are performed only on systems and networks that I own or have explicit permission to administer.

## 🚀 Future Direction

The long-term goal is a documented, practical lab rather than a collection of notes, showing how **Networking → Windows Administration → PowerShell → Endpoint Investigation → Incident Response** combine in one infrastructure and cybersecurity environment.
