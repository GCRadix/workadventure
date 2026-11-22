# Exports every tileset (each subfolder with an export.ps1) into that subfolder's out\.
# Usage:  .\export_all.ps1  [-CopyTo <folder>]   (-CopyTo also copies every .png/.tsx there)
param([string]$CopyTo = "")
$ErrorActionPreference = "Stop"
Get-ChildItem $PSScriptRoot -Directory | ForEach-Object {
    $script = Join-Path $_.FullName "export.ps1"
    if (Test-Path $script) { & $script -CopyTo $CopyTo }
}
