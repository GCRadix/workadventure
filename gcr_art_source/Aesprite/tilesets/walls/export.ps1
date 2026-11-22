# Builds out\walls.png + out\walls.tsx (next to this script)
# from walls_master.aseprite + palettes\NN_<colour>.gpl (NN = colour band, 01 = top).
# Usage:  .\export.ps1  [-CopyTo <folder>]   (-CopyTo also copies the .png/.tsx there, e.g. next to a map)
param([string]$CopyTo = "")
. (Join-Path $PSScriptRoot "..\_common.ps1") -OutDir (Join-Path $PSScriptRoot "out") -Width 256   # 8 columns, fixed

$png = Join-Path $OutDir "walls.png"
if (Test-Path $png) { Remove-Item $png }
$log = Invoke-Aseprite @("-b", "--script-param", "out=`"$png`"", "--script", "`"$(Join-Path $PSScriptRoot 'build_walls.lua')`"")
if ($log -notmatch "walls ok") { throw "build_walls.lua failed:`n$log" }
$log -split "`n" | Where-Object { $_ -match "^WARNING" }
$used = [int[]](($log -split "`n" | Where-Object { $_ -match "^used tiles:" }) -replace "^used tiles:\s*", "" -split "," | Where-Object { $_ -ne "" })
$h = Test-Sheet $png
Write-Tsx "walls" $h $used   # every wall tile collides
"walls:  ${Width}x$h ($($used.Count) tiles marked collides) -> $OutDir"
Copy-Tileset "walls" $CopyTo
