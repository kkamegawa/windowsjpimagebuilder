<#!
.SYNOPSIS
    Compute SHA256 hashes of Windows Server 2022 image builder scripts and emit JSON for easy copy into .bicepparam.

.DESCRIPTION
    Scans the well-known script set used in windows2022image.bicep, calculates SHA256, and outputs:
    {
      "initScriptChecksum": "...",
      "installJpLangPackChecksum": "...",
      "configureLangChecksum": "...",
      "finalizeScriptChecksum": "..."
    }

    Use -AsObject to get a PowerShell object instead of JSON text.

.PARAMETER RepositoryRoot
    Root directory of the repository (defaults to script parent \..\.. ).

.PARAMETER AsObject
    Return as PSCustomObject instead of JSON string.

.EXAMPLE
    PS> ./Get-2022ScriptHashes.ps1
    {"initScriptChecksum":"7148...","installJpLangPackChecksum":"A590...", ... }

.EXAMPLE
    PS> $h = ./Get-2022ScriptHashes.ps1 -AsObject; $h.initScriptChecksum

.NOTES
    Safe to run in CI; no network calls. Only fails if required files are missing or unreadable.
#>
[CmdletBinding()]
param(
    [Parameter()][string]$RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).Path,
    [switch]$AsObject
)

$ErrorActionPreference = 'Stop'

# Map logical names to relative paths
$scriptMap = [ordered]@{
    initScriptChecksum            = 'images/common/Initialize-VM.ps1'
    installJpLangPackChecksum     = 'images/Windows2022/install-jplangpack.ps1'
    configureLangChecksum         = 'images/Windows2022/install-languagepack.ps1'
    finalizeScriptChecksum        = 'images/common/Finalize-VM.ps1'
}

$result = [ordered]@{}
foreach ($k in $scriptMap.Keys) {
    $path = Join-Path -Path $RepositoryRoot -ChildPath $scriptMap[$k]
    if (-not (Test-Path -LiteralPath $path)) {
        throw "File not found: $path (for key $k)"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToUpperInvariant()
    $result[$k] = $hash
}

if ($AsObject) {
    [PSCustomObject]$result
} else {
    $json = $result | ConvertTo-Json -Depth 2 -Compress
    Write-Output $json
}
