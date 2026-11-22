# Builds one tileset per floor type into out\ (next to this script):
#   <type>\<type>.aseprite (Indexed) x <type>\NN_<name>.gpl  ->  out\<type>.png + out\<type>.tsx
# Each frame = a pattern, each NN_ palette = a colour; every pattern/colour pair = one row (16 columns, fixed).
# New pairs are appended; rows are remembered in <type>\slotmap.tsv (keep it).
# Stops if a tile id would change; -Force re-lays out from scratch (only for types no map uses yet).
# Usage:  .\export.ps1  [-CopyTo <folder>] [-Force]   (-CopyTo also copies the .png/.tsx there)
param([string]$CopyTo = "", [switch]$Force)
. (Join-Path $PSScriptRoot "..\_common.ps1") -OutDir (Join-Path $PSScriptRoot "out") -Width 512   # 16 columns, fixed

$params = @("-b", "--script-param", "outdir=`"$OutDir`"")
if ($Force) { $params += @("--script-param", "force=1") }
$log = Invoke-Aseprite ($params + @("--script", "`"$(Join-Path $PSScriptRoot 'build_floors.lua')`""))
$lines = $log -split "`n" | ForEach-Object { $_.Trim() }
$lines | Where-Object { $_ -match "^(WARNING|ERROR)" }
if ($log -notmatch "floors ok") { throw "Floor export stopped, nothing was copied. Fix the ERROR lines above (or use -Force if the id change is intended)." }

foreach ($l in $lines | Where-Object { $_ -match "^tileset " }) {
    $name = ($l -split " ")[1]
    $h = Test-Sheet (Join-Path $OutDir "$name.png")
    Write-Tsx $name $h
    "${name}: ${Width}x$h -> $OutDir"
    Copy-Tileset $name $CopyTo
}
