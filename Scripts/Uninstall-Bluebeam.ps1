Start-Transcript -Path "C:\ProgramData\BluebeamPortableUninstall.log" -Force
Write-Host "================ Uninstalling Bluebeam Revu ================"

$installPath = "$env:LOCALAPPDATA\Programs\Bluebeam\Revu"
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Bluebeam Revu.lnk"

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[INFO] Removed Bluebeam folder at $installPath"
}

if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "[INFO] Removed shortcut at $shortcutPath"
}

Unregister-ScheduledTask -TaskName "BluebeamAutoUpdater" -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "[SUCCESS] Uninstall complete"
Stop-Transcript
