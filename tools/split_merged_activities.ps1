# The source Compendium sheet has a broken last row: code 19405's name cell also contains
# ~50 more activities ("Religious Activities 20000 1.0 Sitting in church ..."), each with code and MET.
# This splits them into separate records. Called by export_seed.ps1; can be run on activities.json directly:
#   powershell -File tools\split_merged_activities.ps1 -path assets\seed\activities.json
param([string]$path)
$ErrorActionPreference = 'Stop'

function Split-MergedActivities($acts) {
  $rx = [regex]'(Religious Activities|Volunteer Activities|Video Games) (\d{5}) ([\d.]+) (.*?)(?= (?:Religious Activities|Volunteer Activities|Video Games) \d{5} |$)'
  $inv = [Globalization.CultureInfo]::InvariantCulture
  $out = New-Object System.Collections.Generic.List[object]
  foreach ($a in $acts) {
    $name = [string]$a.name
    $first = $rx.Match($name)
    if (-not $first.Success) { $out.Add($a); continue }
    $out.Add([ordered]@{ category = $a.category; code = $a.code; met = $a.met; name = $name.Substring(0, $first.Index).Trim() })
    foreach ($m in $rx.Matches($name)) {
      $out.Add([ordered]@{
        category = $m.Groups[1].Value
        code     = $m.Groups[2].Value
        met      = [double]::Parse($m.Groups[3].Value, $inv)
        name     = $m.Groups[4].Value.Trim()
      })
    }
  }
  return , $out
}

if ($path) {
  $acts = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
  $fixed = Split-MergedActivities $acts
  [IO.File]::WriteAllText($path, ($fixed | ConvertTo-Json -Depth 3), (New-Object System.Text.UTF8Encoding($false)))
  "activities: $($acts.Count) -> $($fixed.Count)"
}
