$exe = "$env:LOCALAPPDATA\Programs\Bluebeam\Revu\Revu.exe"
if (Test-Path $exe) {
    Write-Output "Installed"
    exit 0
} else {
    exit 1
}
