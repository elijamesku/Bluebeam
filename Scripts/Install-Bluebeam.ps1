Start-Transcript -Path "C:\ProgramData\BluebeamPortableInstall.log" -Force

Write-Host "================ Bluebeam Revu Portable Installer ================"

# Define paths
$sourceDir = "C:\Bluebeam\Revu\Revu"
$targetDir = "$env:LOCALAPPDATA\Programs\Bluebeam\Revu"
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Bluebeam Revu.lnk"
$exePath = "$targetDir\Revu.exe"

# Remove old version
Write-Host "[INFO] Removing old Bluebeam install..."
Remove-Item -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue

# Copy files
Write-Host "[INFO] Copying from $sourceDir to $targetDir"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force

# Create shortcut
Write-Host "[INFO] Creating Start Menu shortcut..."
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $targetDir
$shortcut.Save()
Write-Host "[SUCCESS] Shortcut created: $shortcutPath"

Write-Host "[SUCCESS] Bluebeam installed at $targetDir"
Stop-Transcript
