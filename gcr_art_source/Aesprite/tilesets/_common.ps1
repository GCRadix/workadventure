# Shared helpers for the tileset export.ps1 scripts. Dot-source it with the output folder
# and the sheet width of that tileset:
#   . (Join-Path $PSScriptRoot "..\_common.ps1") -OutDir (Join-Path $PSScriptRoot "out") -Width 256
# A tileset's width must never change once it is used in Tiled: it renumbers every tile.
param(
    [Parameter(Mandatory)][string]$OutDir,
    [Parameter(Mandatory)][int]$Width
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Aseprite = if ($env:ASEPRITE) { $env:ASEPRITE } else { "C:\Program Files\Aseprite\Aseprite.exe" }
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
$Tile = 32
New-Item -ItemType Directory -Force $OutDir | Out-Null

# Aseprite.exe is a GUI app: wait for it explicitly and capture its output.
function Invoke-Aseprite([string[]]$ArgList) {
    $log = Join-Path $env:TEMP "tilesets_export.log"
    $p = Start-Process -FilePath $Aseprite -ArgumentList $ArgList -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $text = @(Get-Content $log, "$log.err" -ErrorAction SilentlyContinue) -join "`n"
    if ($p.ExitCode -ne 0) { throw "Aseprite failed (exit $($p.ExitCode)):`n$text" }
    $text
}

# Checks width/height; returns the height.
function Test-Sheet([string]$png) {
    if (-not (Test-Path $png)) { throw "$png was not written" }
    $img = [System.Drawing.Image]::FromFile($png)
    $w = $img.Width; $h = $img.Height; $img.Dispose()
    if ($w -ne $Width) { throw "$png is $w px wide, expected $Width. Tiled tile IDs would shift - add rows, never columns." }
    if ($h % $Tile -ne 0) { throw "$png height $h is not a multiple of $Tile." }
    $h
}

# Writes <name>.tsx next to <name>.png. $collides = tile ids that get collides=true.
function Write-Tsx([string]$name, [int]$height, [int[]]$collides = @()) {
    $cols = $Width / $Tile
    $count = $cols * ($height / $Tile)
    $tiles = ($collides | ForEach-Object {
        "  <tile id=`"$_`">`n   <properties>`n    <property name=`"collides`" type=`"bool`" value=`"true`"/>`n   </properties>`n  </tile>"
    }) -join "`n"
    $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="$name" tilewidth="$Tile" tileheight="$Tile" tilecount="$count" columns="$cols">
 <image source="$name.png" width="$Width" height="$height"/>
$tiles
</tileset>
"@
    [System.IO.File]::WriteAllText((Join-Path $OutDir "$name.tsx"), $xml, (New-Object System.Text.UTF8Encoding $false))
}

function Copy-Tileset([string]$name, [string]$dest) {
    if (-not $dest) { return }
    foreach ($ext in "png", "tsx") { Copy-Item (Join-Path $OutDir "$name.$ext") -Destination $dest -Force }
    "  copied $name.png/.tsx to $dest"
}
