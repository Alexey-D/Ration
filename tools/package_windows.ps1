# Builds the Windows release and packs it into dist\Ration-<version>-windows-x64.zip
# Usage (from the project root):  powershell -ExecutionPolicy Bypass -File tools\package_windows.ps1
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]

if (-not $SkipBuild) {
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }
}

$release = Join-Path $root 'build\windows\x64\runner\Release'
$dist = Join-Path $root 'dist'
$app = Join-Path $dist 'Ration'
if (Test-Path $app) { Remove-Item -Recurse -Force $app }
New-Item -ItemType Directory -Force $app | Out-Null
Copy-Item "$release\*" $app -Recurse

# Visual C++ runtime (app-local), so the app runs without the VC++ Redistributable installed
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $env:WINDIR "System32\$dll") $app
}
Copy-Item (Join-Path $PSScriptRoot 'dist_readme.txt') (Join-Path $app 'README.txt')

$zip = Join-Path $dist "Ration-$version-windows-x64.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($app, $zip, [IO.Compression.CompressionLevel]::Optimal, $true)

"Folder: $app"
"Zip:    $zip ({0:N1} MB)" -f ((Get-Item $zip).Length / 1MB)
