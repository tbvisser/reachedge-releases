# Reachedge: one-command install for Windows (PowerShell).
#   irm https://raw.githubusercontent.com/tbvisser/reachedge-releases/main/install.ps1 | iex
#
# Installs everything in %USERPROFILE%\.reachedge (no admin rights): a private Node.js runtime, the app,
# your data (kept on update), a `reachedge` command and a Start menu shortcut.
# Options (env vars): REACHEDGE_HOME, REACHEDGE_PORT, REACHEDGE_TARBALL (local file or URL),
#   REACHEDGE_RELEASES_REPO (public GitHub repo with the release, default tbvisser/reachedge-releases),
#   REACHEDGE_NO_OPEN=1, REACHEDGE_NO_PATH=1 (don't change the user Path), REACHEDGE_NO_SHORTCUT=1 (no Start menu entry)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ReleasesRepo = if ($env:REACHEDGE_RELEASES_REPO) { $env:REACHEDGE_RELEASES_REPO } else { "tbvisser/reachedge-releases" }
$ReachedgeHome = if ($env:REACHEDGE_HOME) { $env:REACHEDGE_HOME } else { Join-Path $env:USERPROFILE ".reachedge" }
$Port = if ($env:REACHEDGE_PORT) { $env:REACHEDGE_PORT } else { "3737" }
$NodeMajor = 24

function Say($t) { Write-Host "  $t" }
function Fail($t) { Write-Host "`n  Error: $t`n" -ForegroundColor Red; exit 1 }

Write-Host "`n  Installing Reachedge`n" -ForegroundColor White

$arch = if ([Environment]::Is64BitOperatingSystem) { if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" } } else { Fail "32-bit Windows is not supported." }
foreach ($d in "runtime", "bin", "logs", "data") { New-Item -ItemType Directory -Force -Path (Join-Path $ReachedgeHome $d) | Out-Null }
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("reachedge-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
  # 1. Node.js runtime, checksum verified
  $sums = (Invoke-WebRequest -UseBasicParsing "https://nodejs.org/dist/latest-v$NodeMajor.x/SHASUMS256.txt").Content -split "`n"
  $line = $sums | Where-Object { $_ -match "node-v[0-9.]+-win-$arch\.zip$" } | Select-Object -First 1
  if (-not $line) { Fail "Could not find Node.js. Are you connected to the internet?" }
  $sum, $file = ($line -split "\s+")[0, 1]
  $version = ($file -replace "node-(v[0-9.]+)-.*", '$1')
  $nodeExe = Join-Path $ReachedgeHome "runtime\node\node.exe"
  $have = if (Test-Path $nodeExe) { & $nodeExe --version } else { "" }
  if ($have -eq $version) { Say "Node.js $version is already installed" } else {
    Say "Downloading Node.js $version..."
    $zip = Join-Path $Tmp "node.zip"
    Invoke-WebRequest -UseBasicParsing "https://nodejs.org/dist/latest-v$NodeMajor.x/$file" -OutFile $zip
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne $sum) { Fail "The Node.js checksum does not match." }
    Expand-Archive $zip -DestinationPath $Tmp -Force
    $extracted = Get-ChildItem $Tmp -Directory | Where-Object { $_.Name -like "node-v*" } | Select-Object -First 1
    Remove-Item -Recurse -Force (Join-Path $ReachedgeHome "runtime\node") -ErrorAction SilentlyContinue
    Move-Item $extracted.FullName (Join-Path $ReachedgeHome "runtime\node")
  }

  # 2. The app
  $src = if ($env:REACHEDGE_TARBALL) { $env:REACHEDGE_TARBALL } else { "https://github.com/$ReleasesRepo/releases/latest/download/reachedge.tar.gz" }
  Say "Downloading Reachedge..."
  $tgz = Join-Path $Tmp "reachedge.tar.gz"
  if ($src -like "http*") { Invoke-WebRequest -UseBasicParsing $src -OutFile $tgz } else { Copy-Item $src $tgz }
  $appTmp = Join-Path $Tmp "app"
  New-Item -ItemType Directory -Path $appTmp | Out-Null
  tar -xzf $tgz -C $appTmp
  if (-not (Test-Path (Join-Path $appTmp "server.js"))) { Fail "The package is incomplete (server.js is missing)." }

  $launcher = Join-Path $ReachedgeHome "bin\reachedge.ps1"
  if (Test-Path $launcher) { try { & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher stop | Out-Null } catch {} }
  Remove-Item -Recurse -Force (Join-Path $ReachedgeHome "app") -ErrorAction SilentlyContinue
  Move-Item $appTmp (Join-Path $ReachedgeHome "app")

  # 3. The `reachedge` command + Start menu shortcut
  Copy-Item (Join-Path $ReachedgeHome "app\launcher\reachedge.ps1") $launcher -Force
  "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0reachedge.ps1`" %*" | Set-Content (Join-Path $ReachedgeHome "bin\reachedge.cmd") -Encoding ASCII

  $bin = Join-Path $ReachedgeHome "bin"
  if ($env:REACHEDGE_NO_PATH -ne "1") {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not ($userPath -split ";" | Where-Object { $_ -eq $bin })) {
      [Environment]::SetEnvironmentVariable("Path", "$userPath;$bin", "User")
    }
  }

  if ($env:REACHEDGE_NO_SHORTCUT -ne "1") {
    $startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Reachedge.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($startMenu)
    $lnk.TargetPath = "powershell.exe"
    $lnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcher`" open"
    $ico = Join-Path $ReachedgeHome "app\public\reachedge.ico"
    if (Test-Path $ico) { $lnk.IconLocation = $ico }
    $lnk.Save()
  }

  # 4. Start
  Write-Host ""
  if ($env:REACHEDGE_NO_OPEN -eq "1") { & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher start } else { & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher open }
  Write-Host "`n  Done. Reachedge is running at http://127.0.0.1:$Port`n" -ForegroundColor White
  Say "To start it later: use the Start menu (Reachedge) or type 'reachedge' in a new window."
  Say "Stop: reachedge stop  Update: reachedge update  Remove: reachedge uninstall"
  Write-Host ""
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
