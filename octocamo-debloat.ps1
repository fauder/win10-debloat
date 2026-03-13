#Requires -RunAsAdministrator
#Requires -Version 5.1

$Global:Failed = $false
$SophiaRoot = "C:\Sys\Bin\Sophia_Script_for_Windows_10_v6.1.4"

Get-ChildItem function: | Where-Object {$_.ScriptBlock.File -match "Sophia_Script_for_Windows"} | Remove-Item -Force
Remove-Module -Name SophiaScript -Force -ErrorAction Ignore
Import-Module -Name "$SophiaRoot\Manifest\SophiaScript.psd1" -PassThru -Force
Get-ChildItem -Path "$SophiaRoot\Module\private" | ForEach-Object { . $_.FullName }

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