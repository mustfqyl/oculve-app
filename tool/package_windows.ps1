$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
$distDir = Join-Path $repoRoot 'dist'
$packageDir = Join-Path $env:RUNNER_TEMP 'oculve-windows-package'
$zipPath = Join-Path $distDir 'Oculve-Windows-Test.zip'

if (-not (Test-Path (Join-Path $buildDir 'oculve.exe'))) {
  throw "Release executable not found at $buildDir"
}

Remove-Item $packageDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item $packageDir -ItemType Directory -Force | Out-Null
New-Item $distDir -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $buildDir '*') $packageDir -Recurse -Force

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere)) {
  throw "Visual Studio locator not found at $vswhere"
}
$vsInstall = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vsInstall) {
  throw 'Visual Studio C++ toolchain installation was not found.'
}
$vcRedistRoot = Join-Path $vsInstall 'VC/Redist/MSVC'
$vcRuntime = Get-ChildItem $vcRedistRoot -Directory |
  Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
  Sort-Object { [version]$_.Name } -Descending |
  ForEach-Object { Join-Path $_.FullName 'x64/Microsoft.VC143.CRT' } |
  Where-Object { Test-Path $_ } |
  Select-Object -First 1
if (-not $vcRuntime) {
  throw "The x64 Microsoft.VC143.CRT redistributable was not found under $vcRedistRoot"
}
Copy-Item (Join-Path $vcRuntime '*.dll') $packageDir -Force

$ucrtDir = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Redist/ucrt/DLLs/x64'
if (-not (Test-Path (Join-Path $ucrtDir 'ucrtbase.dll'))) {
  throw "The redistributable x64 UCRT DLLs were not found under $ucrtDir"
}
Copy-Item (Join-Path $ucrtDir '*.dll') $packageDir -Force

$requiredRuntimeDlls = @(
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
  'ucrtbase.dll'
)
foreach ($dll in $requiredRuntimeDlls) {
  if (-not (Test-Path (Join-Path $packageDir $dll))) {
    throw "Required runtime DLL was not packaged: $dll"
  }
}

@'
Oculve Windows x64 test build

Extract the entire ZIP to a folder, then run oculve.exe from that folder.
Keep the xray subfolder and the DLL files beside oculve.exe.

This is an unsigned test build, not a stable production release. A real
Windows VPN/WFP tunnel session and IP/DNS leak test have not been performed.
'@ | Set-Content (Join-Path $packageDir 'README.txt') -Encoding utf8

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $entries = @($archive.Entries | ForEach-Object FullName)
  foreach ($dll in $requiredRuntimeDlls) {
    if ($entries -notcontains $dll) {
      throw "Packaged ZIP is missing required runtime DLL: $dll"
    }
  }
  if ($entries -notcontains 'oculve.exe') {
    throw 'Packaged ZIP is missing oculve.exe.'
  }
}
finally {
  $archive.Dispose()
}

Write-Output "Portable Windows package created: $zipPath"
