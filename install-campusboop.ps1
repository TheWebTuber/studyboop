$ErrorActionPreference = 'Stop'
$Version = '1.0'
$BaseUrl = 'https://campusboop.creatorpromote.com'
$Package = "CampusBoop-v$Version-Windows-x64.zip"
$ExpectedSha = '19697c395a6d56daf5adabb41608040c372b3a28f1272764260eca31e6d529a7'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\CampusBoop'
$BinDir = Join-Path $InstallDir 'bin'
$CommandPath = Join-Path $BinDir 'campusboop.cmd'

Write-Host "CampusBoop v$Version // Windows installer" -ForegroundColor Cyan
if (-not [Environment]::Is64BitOperatingSystem) { throw 'CampusBoop v1.0 requires 64-bit Windows.' }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('CampusBoop-' + [guid]::NewGuid().ToString('N'))
$zip = Join-Path $tmp $Package
$extract = Join-Path $tmp 'extract'
New-Item -ItemType Directory -Force -Path $tmp,$extract | Out-Null
try {
    Write-Host "Downloading $Package..."
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/downloads/$Package" -OutFile $zip
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha) { throw 'SHA-256 verification failed. Nothing was installed.' }
    Write-Host 'SHA-256 verified.' -ForegroundColor Green

    # Stop a running CampusBoop PowerShell helper before replacing app files.
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'SchoolCheckIn\.ps1' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $source = Join-Path $extract 'CampusBoop'
    if (-not (Test-Path (Join-Path $source 'CampusBoop.exe'))) { throw 'The downloaded package does not contain CampusBoop.exe.' }

    if (Test-Path $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $InstallDir,$BinDir | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $InstallDir -Recurse -Force

    @'
@echo off
setlocal
set "ROOT=%LOCALAPPDATA%\Programs\CampusBoop"
if /I "%~1"=="--uninstall" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\uninstall.ps1"
  exit /b %errorlevel%
)
if /I "%~1"=="--purge" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\uninstall.ps1" -Purge
  exit /b %errorlevel%
)
if /I "%~1"=="--help" (
  echo CampusBoop v1.0
  echo   campusboop                 Open CampusBoop
  echo   campusboop --background    Start quietly in the background
  echo   campusboop --help          Show this help
  echo   campusboop --uninstall     Remove the app and keep settings
  echo   campusboop --purge         Remove the app and local settings
  echo Instructions: https://campusboop.creatorpromote.com/#instructions
  exit /b 0
)
if not exist "%ROOT%\CampusBoop.exe" (
  echo CampusBoop is not installed correctly. Reinstall from https://campusboop.creatorpromote.com
  exit /b 1
)
start "" "%ROOT%\CampusBoop.exe" %*
'@ | Set-Content -LiteralPath $CommandPath -Encoding ASCII

    @'
param([switch]$Purge)
$ErrorActionPreference = 'SilentlyContinue'
$root = Join-Path $env:LOCALAPPDATA 'Programs\CampusBoop'
$data = Join-Path $env:LOCALAPPDATA 'SchoolCheckInHelper'
$startup = [Environment]::GetFolderPath('Startup')
$programs = [Environment]::GetFolderPath('Programs')
Remove-Item -LiteralPath (Join-Path $startup 'CampusBoop.lnk') -Force
Remove-Item -LiteralPath (Join-Path $programs 'CampusBoop.lnk') -Force
Remove-Item -LiteralPath (Join-Path $startup 'School Check-in.lnk') -Force
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine -match 'SchoolCheckIn\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Stop-Process -Name 'SchoolLogin' -Force
$bin = Join-Path $root 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$cleanPath = (($userPath -split ';' | Where-Object { $_ -and $_ -ne $bin }) -join ';')
[Environment]::SetEnvironmentVariable('Path',$cleanPath,'User')
if ($Purge) { Remove-Item -LiteralPath $data -Recurse -Force }
$escaped = $root.Replace('"','""')
Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/d','/c',("timeout /t 1 /nobreak >nul & rmdir /s /q `"$escaped`"")
if ($Purge) { Write-Host 'CampusBoop and its local settings were removed.' }
else {
  Write-Host "CampusBoop removed. Your local settings were kept in: $data"
  Write-Host 'Use campusboop --purge before uninstalling if you also want those settings erased.'
}
'@ | Set-Content -LiteralPath (Join-Path $InstallDir 'uninstall.ps1') -Encoding UTF8

    # Add the command directory to the current user's PATH for future terminals.
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    $parts = @($userPath -split ';' | Where-Object { $_ })
    if ($parts -notcontains $BinDir) {
        $newPath = (($parts + $BinDir) -join ';')
        [Environment]::SetEnvironmentVariable('Path',$newPath,'User')
    }

    # Start Menu shortcut.
    $programs = [Environment]::GetFolderPath('Programs')
    $shortcutPath = Join-Path $programs 'CampusBoop.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $InstallDir 'CampusBoop.exe'
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = Join-Path $InstallDir 'assets\creatorpromote.ico'
    $shortcut.Save()

    Write-Host ''
    Write-Host 'CampusBoop is installed.' -ForegroundColor Green
    Write-Host ''
    Write-Host '  Start:       campusboop'
    Write-Host '  Background:  campusboop --background'
    Write-Host '  Help:        campusboop --help'
    Write-Host '  Uninstall:   campusboop --uninstall'
    Write-Host '  Full remove: campusboop --purge'
    Write-Host ''
    Write-Host "Instructions: $BaseUrl/#instructions" -ForegroundColor Cyan
    Write-Host 'Open a new terminal before using the new campusboop command.' -ForegroundColor DarkGray
    Write-Host "You can also start it now from: $InstallDir\CampusBoop.exe" -ForegroundColor DarkGray
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
