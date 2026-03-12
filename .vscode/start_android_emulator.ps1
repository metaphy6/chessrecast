# .vscode helper to start a named Android AVD only if not already running
# Usage: .vscode\start_android_emulator.ps1 <avd-name>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$AvdName
)

$ErrorActionPreference = "Stop"

$SdkDir = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\sdk" }
$EmuBin = Join-Path $SdkDir "emulator\emulator.exe"

if (-not (Test-Path $EmuBin)) {
    Write-Error "emulator binary not found at $EmuBin. Check ANDROID_SDK_ROOT or install the emulator."
    exit 1
}

# Check if an emulator process for this AVD is already running
$running = Get-Process -Name "qemu-system*" -ErrorAction SilentlyContinue
if ($running) {
    $emuProcs = Get-CimInstance Win32_Process -Filter "Name LIKE 'qemu-system%'" -ErrorAction SilentlyContinue
    foreach ($proc in $emuProcs) {
        if ($proc.CommandLine -match "-avd\s+$AvdName") {
            Write-Host "Emulator for AVD $AvdName already running. Skipping start."
            exit 0
        }
    }
}

# Start emulator in background
Write-Host "Starting AVD $AvdName..."
Start-Process -FilePath $EmuBin -ArgumentList "@$AvdName", "-no-snapshot-save" -WindowStyle Minimized

# Wait for device to show up via adb
$AdbBin = Join-Path $SdkDir "platform-tools\adb.exe"
if (-not (Test-Path $AdbBin)) {
    Write-Host "adb not found at $AdbBin; waiting might fail. Make sure platform-tools is installed."
    exit 0
}

for ($i = 1; $i -le 60; $i++) {
    Start-Sleep -Seconds 2
    $devices = & $AdbBin devices 2>$null
    if ($devices -match "emulator-") {
        Write-Host "Emulator detected via adb. Boot may continue in the background."
        exit 0
    }
}

Write-Host "Timed out waiting for emulator to be detected by adb. Check the emulator UI or logs."
exit 0
