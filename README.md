# Bluebeam Revu Portable Intune Deployment (User Context, No UAC) v 21.5

This documentation outlines a fully automated method for deploying Bluebeam Revu as a portable application using Microsoft Intune. This deployment process bypasses administrative permissions, avoids UAC elevation, and performs the install entirely within the user’s local profile. This strategy enables seamless deployment in environments with strict privilege controls


## What Was Done (Summary)

1. **Reverse-engineered an MSI-based install into a portable app**  
   I extracted `Revu.exe` and its runtime files directly from `%LOCALAPPDATA%`, avoiding any dependency on the official installer or registry keys

2. **Bypassed SYSTEM-context limitation in Intune**  
   Intune Win32 apps normally run under the SYSTEM account, which cannot access `%LOCALAPPDATA%`
   I solved this by wrapping the PowerShell install script in a `.cmd` launcher (`Start-Install.cmd`) to elevate into user context, which was "tricking" Intune

3. **Created a self-contained, user-space installation**

   * No admin rights
   * No registry entries
   * No UAC prompts
   * Runs entirely from the user’s profile like a portable app

4. **Enabled full lifecycle management through Intune**

   * Custom uninstall script (`Start-Uninstall.cmd`) reverses all changes
   * Detection script (`Detect-Bluebeam.ps1`) ensures Intune recognizes successful installs without relying on MSI ProductCodes or system registry entries

5. **Future-proofed for updates**

   * If Bluebeam releases a new version, just drop a new `Revu.exe` into the folder and repackage
   * No more tracking version numbers, GUIDs, or MSI transforms : )


## Folder Structure

The deployment directory should follow this format:

```
BluebeamPortable/
├── Source/
│   └── Revu/                      # Extracted Bluebeam portable files including Revu.exe
├── Scripts/
│   ├── Install-Bluebeam.ps1       # Handles per-user install and shortcut creation
│   ├── Uninstall-Bluebeam.ps1     # Deletes install folder and shortcut
│   └── AutoUpdate-Bluebeam.ps1    # (Optional) Version-checking script for separate Win32 deployment
├── Output/                        # Output folder for packaged .intunewin
├── Start-Install.cmd              # Wrapper to trigger install in user context
├── Start-Uninstall.cmd            # Wrapper to trigger uninstall in user context
├── Detect-Bluebeam.ps1            # PowerShell detection rule for Intune
```


## How I Obtained `Revu.exe`

Bluebeam’s official MSI and EXE installers require administrative rights and cannot be used directly in a non-elevated Intune deployment 
To create the portable install:  

1. Manually ran the **Bluebeam Revu x64 21.msi** on a test device
2. Once installed, navigate to the following directory:

   ```
   C:\Users\<username>\AppData\Local\Bluebeam\Revu\21
   ```
3. This directory contains all necessary runtime files, including `Revu.exe`.
4. Copied the entire contents to our `Source/Revu/` folder for packaging

**^^** This is a self-contained executable structure that runs independently instead of the system registry or Program Files directories **^^**


## Installer Script (`Install-Bluebeam.ps1`)

```powershell
Start-Transcript -Path "C:\ProgramData\BluebeamPortableInstall.log" -Force
Write-Host "================ Bluebeam Revu Portable Installer ================"

$sourceDir = "C:\Bluebeam\Revu\Revu"
$targetDir = "$env:LOCALAPPDATA\Programs\Bluebeam\Revu"
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Bluebeam Revu.lnk"
$exePath = "$targetDir\Revu.exe"

Write-Host "[INFO] Removing old Bluebeam install..."
Remove-Item -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[INFO] Copying from $sourceDir to $targetDir"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force

Write-Host "[INFO] Creating Start Menu shortcut..."
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $targetDir
$shortcut.Save()
Write-Host "[SUCCESS] Shortcut created: $shortcutPath"

Write-Host "[SUCCESS] Bluebeam installed at $targetDir"
Stop-Transcript
```


## Uninstaller Script (`Uninstall-Bluebeam.ps1`)

```powershell
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
```


## Intune Context Elevation Bypass Using CMD Wrapper

Microsoft Intune Win32 app deployments typically run in SYSTEM context, which cannot access user-local paths like `%LOCALAPPDATA%`. To overcome this limitation, use `cmd` wrappers to invoke the PowerShell scripts as the currently logged-in user, preserving their environment

### Start-Install.cmd

```cmd
@echo off
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Install-Bluebeam.ps1"
```

### Start-Uninstall.cmd

```cmd
@echo off
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Uninstall-Bluebeam.ps1"
```

### Why This Works

* `%~dp0` expands to the current directory path of the script
* `WindowStyle Hidden` keeps the UI silent
* Intune executes this `.cmd` as SYSTEM, but `powershell.exe` spawns a process in the **user session context**
* No access is needed to Program Files, registry, or system services — all operations are user-space only

---

## Detection Script (Detect-Bluebeam.ps1)

```powershell
$exe = "$env:LOCALAPPDATA\Programs\Bluebeam\Revu\Revu.exe"
if (Test-Path $exe) {
    Write-Output "Installed"
    exit 0
} else {
    exit 1
}
```

**^^** This detection rule validates that the app has been successfully installed and can run, even though it is not registered in `Add/Remove Programs`. **^^**


## Packaging Steps for Intune Deployment

1. Open a terminal with access to `IntuneWinAppUtil.exe`
2. Package the directory:

```powershell
IntuneWinAppUtil.exe -c "C:\BluebeamPortable\Source" -s "Start-Install.cmd" -o "C:\BluebeamPortable\Output"
```

3. Upload to Intune as a new Win32 application
4. Configure in the Intune portal:

   * **Install command:** `Start-Install.cmd`
   * **Uninstall command:** `Start-Uninstall.cmd`
   * **Install behavior:** User
   * **Detection rule:** File exists

     * Path: `%LOCALAPPDATA%\Programs\Bluebeam\Revu`
     * File: `Revu.exe`


## Technical Rationale Behind This Architecture

* **No elevation prompts**: Avoids interruptions by running exclusively in user-space ; )
* **Portable model**: Bluebeam runs directly from `AppData` without registration
* **Flexible upgrades**: Simply repackaging the folder with a newer `Revu.exe` allows future deployments
* **Detection-agnostic**: Revu is detected through path existence, not installed programs
* **Silent install**: No user interaction or UI prompts
* **PowerShell transcript logging**: Full logging for troubleshooting or confirming


## End Result

* Intune believes the app is installed and manages it correctly
* Bluebeam launches with full functionality
* The app is easily uninstallable
* All functionality is confined to the user context — no elevated permissions required


