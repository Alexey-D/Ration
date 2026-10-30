# Packs PNG files (icon_16.png ... icon_256.png) into a multi-size .ico (PNG-compressed entries, Windows Vista+).
# Usage: powershell -File tools\make_ico.ps1 -pngDir <dir with icon_N.png> -out windows\runner\resources\app_icon.ico
param([string]$pngDir, [string]$out)
$ErrorActionPreference = 'Stop'
$sizes = 16, 24, 32, 48, 64, 128, 256
$images = foreach ($s in $sizes) { , [IO.File]::ReadAllBytes((Join-Path $pngDir "icon_$s.png")) }

$ms = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter($ms)
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)   # ICONDIR
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {                                   # ICONDIRENTRY
  $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
  $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([UInt16]1); $w.Write([UInt16]32)
  $w.Write([UInt32]$images[$i].Length); $w.Write([UInt32]$offset)
  $offset += $images[$i].Length
}
foreach ($img in $images) { $w.Write($img) }
$w.Flush()
[IO.File]::WriteAllBytes($out, $ms.ToArray())
"written $out ($($ms.Length) bytes, $($sizes.Count) sizes)"
