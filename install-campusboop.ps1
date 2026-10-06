$ErrorActionPreference = 'Stop'
$Version = '1.1'
$BaseUrl = 'https://campusboop.creatorpromote.com'
$Package = "CampusBoop-v$Version-Windows-x64.zip"
$ExpectedSha = '8a343ab547498892994f0b69f712702a661cf94fea903c79cbd9a1ed026c1bfb'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\CampusBoop'
$OldBinDir = Join-Path $InstallDir 'bin'

Write-Host "CampusBoop v$Version // Windows installer" -ForegroundColor Cyan
if (-not [Environment]::Is64BitOperatingSystem) { throw 'CampusBoop v1.1 requires 64-bit Windows.' }

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

    # Stop CampusBoop before replacing app files.
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'SchoolCheckIn\.ps1' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Stop-Process -Name 'SchoolLogin' -Force -ErrorAction SilentlyContinue

    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $source = Join-Path $extract 'CampusBoop'
    if (-not (Test-Path (Join-Path $source 'CampusBoop.exe'))) { throw 'The downloaded package does not contain CampusBoop.exe.' }

    # v1.0 created a terminal command. v1.1 intentionally keeps Windows simpler:
    # installer command + Start Menu shortcut, with manual removal instructions.
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($null -ne $userPath) {
        $clean = (($userPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $OldBinDir.TrimEnd('\') }) -join ';')
        if ($clean -ne $userPath) { [Environment]::SetEnvironmentVariable('Path',$clean,'User') }
    }

    if (Test-Path $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $InstallDir -Recurse -Force

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
    Write-Host 'The first-run setup is opening now.'
    Write-Host ''
    Write-Host "Instructions: $BaseUrl/#instructions" -ForegroundColor Cyan
    Write-Host 'Later, open CampusBoop from Windows Search / Start Menu.' -ForegroundColor DarkGray
    Write-Host 'Windows removal is manual; the website shows the exact steps.' -ForegroundColor DarkGray

    Start-Process -FilePath (Join-Path $InstallDir 'CampusBoop.exe') -WorkingDirectory $InstallDir
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
