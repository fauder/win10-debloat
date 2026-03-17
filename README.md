# Windows 10 Debloat

Targeted Windows 10 debloat using [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) as a function library. Removes telemetry, ads, Xbox, Edge, OneDrive, Cortana, and the news/weather widget. Does not touch UI preferences or system configuration.

---

## Setup

### 1. Install Sophia Script (Win10 version)

winget only ships the Win11 version, so download manually:

- Go to https://github.com/farag2/Sophia-Script-for-Windows/releases
- Download `Sophia.Script.for.Windows.10.vX.X.X.zip`
- Extract to `C:\Sys\Bin\Sophia_Script_for_Windows_10_vX.X.X\`

### 2. Allow PowerShell to run local scripts

Open PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Place the debloat script

Save `octocamo-debloat.ps1` (see below) to `C:\Sys\Bin\`.

Update the `$SophiaRoot` variable at the top to match your exact Sophia version folder name.

---

## The Script

`C:\Sys\Bin\octocamo-debloat.ps1`

```powershell
#Requires -RunAsAdministrator
#Requires -Version 5.1

$Global:Failed = $false
$SophiaRoot = "C:\Sys\Bin\Sophia_Script_for_Windows_10_v6.1.4"

Get-ChildItem function: | Where-Object {$_.ScriptBlock.File -match "Sophia_Script_for_Windows"} | Remove-Item -Force
Remove-Module -Name SophiaScript -Force -ErrorAction Ignore
Import-Module -Name "$SophiaRoot\Manifest\SophiaScript.psd1" -PassThru -Force
Get-ChildItem -Path "$SophiaRoot\Module\private" | ForEach-Object { . $_.FullName }

InitialActions -NoWarning

if ($Global:Failed) { exit }

# Confirmation prompt
$title   = "Octocamo Debloat"
$message = "Run weekly debloat? This will remove Xbox, Edge, OneDrive bloat and disable telemetry."
$yes     = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Run the script"
$no      = New-Object System.Management.Automation.Host.ChoiceDescription "&No",  "Skip and exit"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result  = $host.UI.PromptForChoice($title, $message, $options, 1)
if ($result -ne 0) { exit }

Write-Host "`n[Sophia] Running debloat functions..." -ForegroundColor Cyan

# --- Telemetry & Tracking ---
DiagTrackService -Disable
DiagnosticDataLevel -Minimal
ErrorReporting -Disable
FeedbackFrequency -Never
ScheduledTasks -Disable
AdvertisingID -Disable
TailoredExperiences -Disable
BingSearch -Disable

# --- Bloat Apps & UI ---
AppsSilentInstalling -Disable
AppSuggestions -Hide
NewsInterests -Disable

# Force news/weather widget off via Group Policy (survives Explorer restarts)
$feedsPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
If (!(Test-Path $feedsPolicy)) { New-Item -Path $feedsPolicy -Force | Out-Null }
Set-ItemProperty -Path $feedsPolicy -Name "EnableFeeds" -Value 0 -Type DWord

CortanaButton -Hide
CortanaAutostart -Disable
BackgroundUWPApps -Disable
Uninstall-PCHealthCheck
PreventEdgeShortcutCreation -Channels Stable, Beta, Dev, Canary

# --- Xbox ---
XboxGameBar -Disable
XboxGameTips -Disable

# --- OneDrive ---
OneDrive -Uninstall

Write-Host "`n[Edge] Removing Microsoft Edge..." -ForegroundColor Cyan

# Use Edge's own uninstaller — cleanest method, no leftovers
$EdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application"
$versions = Get-ChildItem -Path $EdgePath -Directory -ErrorAction SilentlyContinue
foreach ($version in $versions) {
    $installer = Join-Path $version.FullName "Installer\setup.exe"
    if (Test-Path $installer) {
        Start-Process -FilePath $installer -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall"
        Start-Sleep 20
        Stop-Process -Name setup -Force -ErrorAction SilentlyContinue
    }
}

# Block Edge from reinstalling via registry
$edgeUpdateKey = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
If (!(Test-Path $edgeUpdateKey)) { New-Item -Path $edgeUpdateKey -Force | Out-Null }
Set-ItemProperty -Path $edgeUpdateKey -Name "InstallDefault"    -Value 0 -Type DWord
Set-ItemProperty -Path $edgeUpdateKey -Name "UpdateDefault"     -Value 0 -Type DWord
Set-ItemProperty -Path $edgeUpdateKey -Name "DoNotUpdateToEdge" -Value 1 -Type DWord

Write-Host "`nAll done. Reboot recommended." -ForegroundColor Green
```

---

## Scheduled Task

Runs every Monday at noon. If the machine was off at noon, it runs at next login that day (`-StartWhenAvailable`). Can also be run manually at any time.

Run the following in Admin PowerShell to register it:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoExit -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& 'C:\Sys\Bin\octocamo-debloat.ps1'`""

$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday -At "12:00"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName    "RunOctocamoDebloatWeekly" `
    -TaskPath    "\" `
    -Action      $action `
    -Trigger     $trigger `
    -Settings    $settings `
    -RunLevel    Highest `
    -Description "Weekly debloat — removes Xbox, Edge, telemetry bloat" `
    -Force
```

---

## What Gets Removed / Disabled

| Category | Items |
|----------|-------|
| Telemetry | DiagTrack service, diagnostic data level, error reporting, feedback, scheduled telemetry tasks |
| Ads & tracking | Advertising ID, tailored experiences, Bing in Start, app suggestions, silent app installs |
| Bloat apps | Cortana, PC Health Check, OneDrive |
| Xbox | Game Bar, Game Tips |
| Edge | Uninstalled via its own setup.exe, registry policy blocks reinstall |
| News widget | Disabled via Sophia + enforced via Group Policy key |

## What Is Deliberately Not Touched

- UI preferences (taskbar layout, dark mode, file explorer settings, etc.)
- Gaming infrastructure (DirectX, GPU drivers, Xbox services if used for achievements)
- Windows Store (kept functional for winget)
- Any app you installed yourself