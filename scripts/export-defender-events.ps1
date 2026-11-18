<#
.SYNOPSIS
  Exports Microsoft Defender detection events from this Windows machine and prints a summary.

.DESCRIPTION
  READ-ONLY. It only reads the Defender Operational event log (IDs 1116 to 1119).
  It does not open, scan, restore or delete any flagged file.
    1116 = threat detected
    1117 = action taken
    1118 = action failed (critical)
    1119 = action failed

  Run it in PowerShell. The CSV is written OUTSIDE the Git repository by default,
  because the messages contain file names and paths from your own machine.

.EXAMPLE
  .\export-defender-events.ps1
  .\export-defender-events.ps1 -OutDir "D:\Evidence\03-defender"
#>
param(
    [string]$OutDir = "C:\LabShare\Evidence\03-defender"
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$events = Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-Windows Defender/Operational'
    Id      = 1116, 1117, 1118, 1119
} -ErrorAction Stop

$csv = Join-Path $OutDir "defender-events.csv"
$events | Select-Object TimeCreated, Id, Message | Export-Csv -Path $csv -NoTypeInformation
Write-Host "Exported $($events.Count) events to $csv"

# Parse the fields that matter from each message
$rows = foreach ($e in $events) {
    $m = $e.Message
    [pscustomobject]@{
        Day    = $e.TimeCreated.ToString('yyyy-MM-dd')
        Time   = $e.TimeCreated
        Id     = $e.Id
        Threat = if ($m -match '(?m)^\s*Name:\s*(.+?)\s*$') { $Matches[1] } else { '' }
        Path   = if ($m -match '(?m)^\s*Path:\s*(.+?)\s*$') { $Matches[1] } else { '' }
    }
}

Write-Host ""
Write-Host "== Events per day (times are local to this PC) =="
$rows | Group-Object Day | Sort-Object Name | ForEach-Object {
    $times = $_.Group | Sort-Object Time
    [pscustomobject]@{
        Day        = $_.Name
        Events     = $_.Count
        Detections = ($_.Group | Where-Object Id -eq 1116).Count
        Failed     = ($_.Group | Where-Object { $_.Id -in 1118, 1119 }).Count
        First      = $times[0].Time.ToString('HH:mm:ss')
        Last       = $times[-1].Time.ToString('HH:mm:ss')
    }
} | Format-Table -AutoSize

Write-Host "== Threat names =="
$rows | Group-Object Threat | Sort-Object Count -Descending | Format-Table Count, Name -AutoSize

Write-Host "== Drive letters seen in the flagged paths =="
$rows | ForEach-Object { [regex]::Matches($_.Path, '_([A-Za-z]):') | ForEach-Object { $_.Groups[1].Value.ToUpper() } } |
    Group-Object | Sort-Object Name | Format-Table Count, Name -AutoSize

$onC = ($rows | Where-Object { $_.Path -match '_C:' }).Count
Write-Host "Events with a path on the system drive C: $onC"

Write-Host ""
Write-Host "== Fingerprint of the exported file (note it in your log) =="
Get-FileHash -Path $csv -Algorithm SHA256 | Format-List Algorithm, Hash, Path

Write-Host "Keep the CSV private. Mask your username before sharing any part of it."