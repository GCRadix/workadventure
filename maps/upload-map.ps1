# Uploads a Tiled map from this folder to the local map-storage, so it can be opened and edited with the
# in-game map editor at http://play.workadventure.localhost/~/<Directory>/map.wam
#
#   .\upload-map.ps1                              # starter\map.json -> gcr_office
#   .\upload-map.ps1 -Map other\map.json -Directory other_office
#
# What it does:
#   - packs the map as map.tmj (map-storage refuses .json maps), plus every tileset image and the script it uses,
#     rewriting their paths so they sit next to the map (../assets/x.png -> assets/x.png)
#   - leaves map.wam out of the upload, so the objects and areas placed with the map editor are kept
#     (on the very first upload of a directory, map-storage creates a fresh map.wam itself)
param(
    [string]$Map = "starter\map.json",
    [string]$Directory = "gcr_office",
    [string]$MapStorage = "http://map-storage.workadventure.localhost",
    [string]$User = "john.doe",
    [string]$Password = "password"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$mapPath = (Resolve-Path (Join-Path $PSScriptRoot $Map)).Path
$mapDir = Split-Path $mapPath
$json = Get-Content $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json

# files to pack: published path -> file on disk
$files = [ordered]@{}
function Add-Asset([string]$ref, [string]$baseDir) {
    $full = [IO.Path]::GetFullPath((Join-Path $baseDir $ref))
    if (-not (Test-Path $full)) { throw "Missing file: $ref (looked for $full)" }
    $rel = $ref -replace '\\', '/'
    while ($rel.StartsWith("../")) { $rel = $rel.Substring(3) }   # ../assets/x.png -> assets/x.png
    $rel = $rel.TrimStart("./")
    $files[$rel] = $full
    return $rel
}

foreach ($ts in $json.tilesets) {
    if ($ts.source) {
        # external tileset (.tsx): pack it and the image it points to (relative to the .tsx)
        $tsxRel = Add-Asset $ts.source $mapDir
        $tsxFull = $files[$tsxRel]
        [xml]$tsx = Get-Content $tsxFull -Raw
        $img = $tsx.tileset.image.source
        if ($img) {
            $imgFull = [IO.Path]::GetFullPath((Join-Path (Split-Path $tsxFull) $img))
            $imgRel = (Split-Path $tsxRel -Parent) -replace '\\', '/'
            $imgRel = (($imgRel, ($img -replace '\\', '/')) -join "/").TrimStart("/")
            # keep the image next to the .tsx exactly as the .tsx expects it
            $files[$imgRel] = $imgFull
        }
        $ts.source = $tsxRel
    } elseif ($ts.image) {
        $ts.image = Add-Asset $ts.image $mapDir
    }
}

# the map script and other map-level properties pointing to files
foreach ($p in @($json.properties)) {
    if ($p.name -eq "script") { $p.value = Add-Asset $p.value $mapDir }
    if ($p.name -eq "mapImage" -and -not (Test-Path (Join-Path $mapDir $p.value))) {
        $json.properties = @($json.properties | Where-Object { $_.name -ne "mapImage" })
    }
}

# build the zip with forward-slash paths (map-storage can't read zips made by Compress-Archive)
$zipPath = Join-Path $env:TEMP "map-upload-$Directory.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$zip = [IO.Compression.ZipFile]::Open($zipPath, "Create")
try {
    $entry = $zip.CreateEntry("map.tmj")
    $w = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
    $w.Write(($json | ConvertTo-Json -Depth 100 -Compress)); $w.Close()
    foreach ($k in $files.Keys) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $files[$k], $k) | Out-Null
    }
} finally { $zip.Dispose() }

"Uploading $Map to $Directory ($($files.Count + 1) files)"
$out = & curl.exe -s -u "${User}:${Password}" -F "file=@$zipPath" --form-string "directory=$Directory" -w "`n%{http_code}" "$MapStorage/upload"
Remove-Item $zipPath -Force
$code = ($out | Select-Object -Last 1)
if ($code -ne "200") { throw "Upload failed (HTTP $code):`n$(($out | Select-Object -SkipLast 1) -join "`n")" }
"Done. Reload http://play.workadventure.localhost/~/$Directory/map.wam"
