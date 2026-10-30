# Import reference data from the source Excel files into assets/seed/*.json.
# Usage: unzip both .xlsx files (they are zip archives) and run:
#   powershell -File tools\export_seed.ps1 -rationRoot <unzipped ration xlsx> -calcRoot <unzipped calculator xlsx> -outDir assets\seed
# Note: the seed is applied only when the database is created (first launch).
param([string]$rationRoot, [string]$calcRoot, [string]$outDir)
$ErrorActionPreference = 'Stop'

function Read-Strings($root) {
  [xml]$ss = Get-Content -Raw -Encoding UTF8 "$root\xl\sharedStrings.xml"
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($si in $ss.sst.si) { $list.Add($si.InnerText) }
  return ,$list
}

function Read-Sheet($root, $file, $strings) {
  [xml]$x = Get-Content -Raw -Encoding UTF8 "$root\xl\worksheets\$file"
  $rows = @()
  foreach ($row in $x.worksheet.sheetData.row) {
    $h = @{}
    foreach ($c in $row.c) {
      $col = ($c.r -replace '\d', '')
      $v = $c.v
      if ($c.t -eq 's' -and $v -ne $null) { $v = $strings[[int]$v] }
      if ($v -ne $null) { $h[$col] = $v }
    }
    $rows += , $h
  }
  return , $rows
}

$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Num($s) { [math]::Round([double]::Parse($s, $inv), 4) }

# ---- foods ----
$rs = Read-Strings $rationRoot
# category display names come from column B of the ration sheet
$main = Read-Sheet $rationRoot 'sheet1.xml' $rs
$cats = @(
  @{ key = 'grain';   name = $main[1]['B']; file = 'sheet2.xml' },
  @{ key = 'protein'; name = $main[2]['B']; file = 'sheet3.xml' },
  @{ key = 'fat';     name = $main[3]['B']; file = 'sheet4.xml' },
  @{ key = 'snack';   name = $main[5]['B']; file = 'sheet5.xml' }
)
$foodCats = @()
$i = 0
foreach ($cat in $cats) {
  $i++
  $rows = Read-Sheet $rationRoot $cat.file $rs
  $foods = @()
  foreach ($r in ($rows | Select-Object -Skip 1)) {
    if (-not $r['A']) { continue }
    $foods += [ordered]@{ name = $r['A']; kcal = (Num $r['B']); protein = (Num $r['C']); fat = (Num $r['D']); carbs = (Num $r['E']) }
  }
  $foodCats += [ordered]@{ key = $cat.key; name = $cat.name; sort = $i; foods = $foods }
}
[IO.File]::WriteAllText("$outDir\foods.json", ($foodCats | ConvertTo-Json -Depth 5), $utf8)

# ---- activities ----
$cs = Read-Strings $calcRoot
$rows = Read-Sheet $calcRoot 'sheet2.xml' $cs
$acts = @()
foreach ($r in ($rows | Select-Object -Skip 1)) {
  if (-not $r['D']) { continue }
  $acts += [ordered]@{ category = $r['A']; code = $r['B']; met = (Num $r['C']); name = $r['D'] }
}
. (Join-Path $PSScriptRoot 'split_merged_activities.ps1')
$acts = Split-MergedActivities $acts
[IO.File]::WriteAllText("$outDir\activities.json", ($acts | ConvertTo-Json -Depth 3), $utf8)
# Russian names live in activities_ru.json (code -> name) and are not touched by this import.
"foods: $(($foodCats | ForEach-Object { $_.foods.Count }) -join ',')  activities: $($acts.Count)"
$acts | Group-Object category | Select-Object Name, Count | Format-Table -AutoSize | Out-String
