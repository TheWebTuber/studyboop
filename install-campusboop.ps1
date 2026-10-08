$ErrorActionPreference = 'Stop'
$Version = '1.1.1'
$BaseUrl = 'https://campusboop.creatorpromote.com'
$Package = "CampusBoop-v$Version-Windows-x64.zip"
$ExpectedSha = '5b6c23953bbbc4112f1652ca8e98e702b198f22ce0f18cf201517cf9faf096dc'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\CampusBoop'

Write-Host "CampusBoop v$Version // Windows installer" -ForegroundColor Cyan
if (-not [Environment]::Is64BitOperatingSystem) { throw 'CampusBoop requires 64-bit Windows.' }

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

    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'SchoolCheckIn\.ps1' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $source = Join-Path $extract 'CampusBoop'
    if (-not (Test-Path (Join-Path $source 'CampusBoop.exe'))) { throw 'The downloaded package does not contain CampusBoop.exe.' }

    if (Test-Path $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $InstallDir -Recurse -Force

    # The ZIP was verified before installation. Remove the Internet-zone marker from installed files
    # so Windows does not repeatedly warn about every CampusBoop component after the user chose to install it.
    Get-ChildItem -LiteralPath $InstallDir -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

    $programs = [Environment]::GetFolderPath('Programs')
    $shortcutPath = Join-Path $programs 'CampusBoop.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $InstallDir 'CampusBoop.exe'
    $shortcut.WorkingDirectory = $InstallDir
    $icon = Join-Path $InstallDir 'assets\creatorpromote.ico'
    if (Test-Path $icon) { $shortcut.IconLocation = $icon }
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
