# Exports every object project (chairs\, computer\, decoration\, tables\, ... - every folder except tilesets, out, debug)
# as a WorkAdventure entity collection for the in-game map editor:
#   out\objects\collection.json + out\objects\entities\<category>\<object>\*.png
# and copies it into the WorkAdventure repo (maps\assets\gcr_objects), where the maps server serves it.
# How projects, palettes, frames and objects.cfg are read: see build_objects.lua / OBJECTS.md.
#
# Usage:
#   .\export_objects.ps1                                   # build and copy into the WorkAdventure repo
#   .\export_objects.ps1 -NoCopy                           # only build out\objects
#   .\export_objects.ps1 -AllowBreaking                    # accept that ids disappear (you renamed/deleted something)
#   .\export_objects.ps1 -RegisterMap gcr_office/map.wam   # also add the collection to that map (once per map)
#
# Re-exports never break placed objects by accident: the new ids are compared with the last export
# (out\objects and the copy in the repo). If any id would disappear, nothing is written or copied and the
# missing ids are listed. Re-run with -AllowBreaking when that is intended.
param(
    [string]$CopyTo = "A:\Git\workadventure\maps\assets\gcr_objects",
    [switch]$NoCopy,
    [switch]$AllowBreaking,
    [string]$RegisterMap = "",
    [string]$CollectionUrl = "http://maps.workadventure.localhost/assets/gcr_objects/collection.json",
    [string]$Name = "GCR Objects",
    [string]$Prefix = "gcr",
    [string]$MapStorage = "http://map-storage.workadventure.localhost",
    [string]$MapStorageUser = "john.doe",
    [string]$MapStoragePassword = "password"
)
$ErrorActionPreference = "Stop"
$Aseprite = if ($env:ASEPRITE) { $env:ASEPRITE } else { "C:\Program Files\Aseprite\Aseprite.exe" }
$Out = Join-Path $PSScriptRoot "out\objects"
$Stage = Join-Path $PSScriptRoot "out\objects.new"
if ($NoCopy) { $CopyTo = "" }

function Get-Ids([string]$json) {
    if (-not (Test-Path $json)) { return @() }
    @((Get-Content $json -Raw | ConvertFrom-Json).collection | ForEach-Object { $_.id })
}

# build into a staging folder; the previous export stays untouched until everything checks out
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force $Stage | Out-Null
$log = Join-Path $env:TEMP "objects_export.log"
$argList = @("-b", "--script-param", "out=`"$Stage`"", "--script-param", "name=`"$Name`"", "--script-param", "prefix=$Prefix",
    "--script", "`"$(Join-Path $PSScriptRoot 'build_objects.lua')`"")
$p = Start-Process -FilePath $Aseprite -ArgumentList $argList -Wait -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"
$text = @(Get-Content $log, "$log.err" -ErrorAction SilentlyContinue) -join "`n"
$text -split "`n" | Where-Object { $_ -match "^(WARNING|ERROR)" }
if ($p.ExitCode -ne 0 -or $text -notmatch "objects ok") { throw "Object export failed, nothing was written or copied.`n$text" }
($text -split "`n" | Where-Object { $_ -match "^objects ok" }) -replace "^objects ok: ", "objects: "

# ids that existed before (last local export + what is deployed in the repo) but are no longer produced
$newIds = Get-Ids (Join-Path $Stage "collection.json")
$oldIds = @(Get-Ids (Join-Path $Out "collection.json"))
if ($CopyTo) { $oldIds += Get-Ids (Join-Path $CopyTo "collection.json") }
$oldIds = @($oldIds | Sort-Object -Unique)
$gone = @($oldIds | Where-Object { $newIds -notcontains $_ })
if ($gone.Count -gt 0) {
    $objectsNow = @($newIds | ForEach-Object { ($_ -split ":")[1] } | Sort-Object -Unique)
    foreach ($g in $gone) {
        $obj = ($g -split ":")[1]
        $why = if ($objectsNow -contains $obj) { "its frame tag or colour palette changed" } else { "the object is no longer exported (renamed, moved or deleted?)" }
        Write-Host "GONE $g  - $why" -ForegroundColor Yellow
    }
    if (-not $AllowBreaking) {
        Remove-Item $Stage -Recurse -Force
        throw "$($gone.Count) id(s) would disappear, so copies already placed in maps would vanish. Nothing was written or copied.`nIf that is intended (you renamed or deleted something), run again with -AllowBreaking."
    }
    "  -AllowBreaking: accepting $($gone.Count) removed id(s)"
}

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
Move-Item $Stage $Out

if ($CopyTo) {
    New-Item -ItemType Directory -Force $CopyTo | Out-Null
    $destEntities = Join-Path $CopyTo "entities"
    if (Test-Path $destEntities) { Remove-Item $destEntities -Recurse -Force }
    Copy-Item (Join-Path $Out "entities") -Destination $CopyTo -Recurse
    Copy-Item (Join-Path $Out "collection.json") -Destination (Join-Path $CopyTo "collection.json") -Force
    "  copied to $CopyTo"
}

if ($RegisterMap) {
    $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${MapStorageUser}:${MapStoragePassword}"))
    $mapUrl = "$MapStorage/$($RegisterMap.TrimStart('/'))"
    $wam = Invoke-RestMethod -Uri $mapUrl -Headers @{ Authorization = $auth }
    if (@($wam.entityCollections | Where-Object { $_.url -eq $CollectionUrl }).Count -gt 0) {
        "  $RegisterMap already uses $CollectionUrl"
    } else {
        $patch = '[{"op":"add","path":"/entityCollections/-","value":{"url":"' + $CollectionUrl + '","type":"file"}}]'
        Invoke-RestMethod -Uri $mapUrl -Method Patch -Headers @{ Authorization = $auth } -ContentType "application/json" -Body $patch | Out-Null
        "  added $CollectionUrl to $RegisterMap"
    }
}
