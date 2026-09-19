<#
    .SYNOPSIS
    Installs a Windows display language (ja-JP by default) on Windows Server 2025 with a
    bounded execution time and per-capability diagnostics.

    .DESCRIPTION
    Install-Language downloads the language pack and its Features on Demand from Windows
    Update. Two things make the bare cmdlet a poor fit for an image build:

      * Initialize-VM.ps1 sets NoAutoUpdate=1 earlier in the build, which makes the Features
        on Demand source unreliable.
      * When a Feature on Demand cannot be retrieved, the cmdlet keeps retrying internally
        with no progress output and no time limit.

    Observed image builds spent about 61 minutes inside a single Install-Language call before
    failing with ErrorCode -2147024894 (0x80070002, ERROR_FILE_NOT_FOUND) and "Language pack
    or features could only be partially installed" - a quarter of the 240 minute build budget
    with nothing to show for it.

    This script keeps Install-Language as the primary mechanism, because it is the supported
    way to install a display language on Windows Server, but wraps it so that:

      1. Automatic updates are re-enabled for the duration of the install, so the Features on
         Demand source is reachable, and the original value is restored afterwards.
      2. Install-Language runs in a background job bounded by -TimeoutMinutes, so a stuck
         download can no longer consume the whole image build timeout.
      3. Every language capability is reported as Installed or NotPresent, and the missing
         ones are retried individually so the log names the component that actually failed.
      4. The script fails only when the language itself is missing. Missing optional
         capabilities are reported as warnings, because several of them are not offered for
         the Server SKU and are not needed by the image.

    The follow-up script (install-languagepack.ps1) still performs the actual locale, culture
    and Welcome screen configuration; this script only makes sure the language is present.

    .PARAMETER Language
    Language tag to install. Defaults to ja-JP.

    .PARAMETER TimeoutMinutes
    Upper bound for the Install-Language call. Defaults to 25 minutes.

    .NOTES
    References:
    - Install-Language (LanguagePackManagement):
      https://learn.microsoft.com/powershell/module/languagepackmanagement/install-language?view=windowsserver2025-ps
    - Add-WindowsCapability (DISM):
      https://learn.microsoft.com/powershell/module/dism/add-windowscapability
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Language = 'ja-JP',

    [ValidateRange(1, 120)]
    [int]$TimeoutMinutes = 25
)

$ErrorActionPreference = 'Stop'

$AutoUpdatePath = 'HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

function Get-NoAutoUpdateValue {
    if (-not (Test-Path -Path $AutoUpdatePath)) {
        return $null
    }

    $property = Get-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -ErrorAction SilentlyContinue
    if ($null -eq $property) {
        return $null
    }

    return [int]$property.NoAutoUpdate
}

function Set-NoAutoUpdateValue {
    param([int]$Value)

    Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value $Value
}

# Features on Demand are downloaded from Windows Update, which Initialize-VM.ps1 has already
# turned off. Restore the original value in the finally block so the rest of the build keeps
# the state it expects.
$originalNoAutoUpdate = Get-NoAutoUpdateValue
$mustRestore = $false

if ($null -ne $originalNoAutoUpdate -and $originalNoAutoUpdate -ne 0) {
    Write-Host "Temporarily enabling Windows Update for Features on Demand (NoAutoUpdate: $originalNoAutoUpdate -> 0)"
    Set-NoAutoUpdateValue -Value 0
    $mustRestore = $true
}

try {
    Write-Host "Installing language $Language (timeout: $TimeoutMinutes minutes)"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $job = Start-Job -ScriptBlock {
        param([string]$Tag)

        Import-Module -Name LanguagePackManagement -ErrorAction Stop
        Install-Language -Language $Tag -CopyToSettings -ErrorAction Stop | Out-Null
    } -ArgumentList $Language

    $finished = Wait-Job -Job $job -Timeout ($TimeoutMinutes * 60)

    if ($null -eq $finished) {
        Write-Warning "Install-Language did not finish within $TimeoutMinutes minutes. Stopping it and continuing with per-capability installation."
        Stop-Job -Job $job
    } else {
        try {
            Receive-Job -Job $job -ErrorAction Stop
            Write-Host "Install-Language completed."
        } catch {
            # A partial install is expected when an optional Feature on Demand is unavailable.
            # The per-capability pass below reports which one, and the final check decides
            # whether the build can continue.
            Write-Warning "Install-Language reported an error: $($_.Exception.Message)"
        }
    }

    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $stopwatch.Stop()
    Write-Host ("Install-Language took {0:N1} minutes." -f $stopwatch.Elapsed.TotalMinutes)

    # Report and retry the individual capabilities. und-JPAN covers the Japanese font
    # capability, which is named after the script rather than the language tag.
    $capabilities = Get-WindowsCapability -Online |
        Where-Object { $_.Name -like "*$Language*" -or $_.Name -like '*und-JPAN*' }

    Write-Host "Language capability state:"
    foreach ($capability in $capabilities) {
        Write-Host ("  {0,-12} {1}" -f $capability.State, $capability.Name)
    }

    foreach ($capability in ($capabilities | Where-Object { $_.State -ne 'Installed' })) {
        Write-Host "Retrying capability $($capability.Name)"
        try {
            Add-WindowsCapability -Online -Name $capability.Name -ErrorAction Stop | Out-Null
            Write-Host "  installed."
        } catch {
            Write-Warning "  $($capability.Name) could not be installed: $($_.Exception.Message)"
        }
    }

    # install-languagepack.ps1 uses Get-InstalledLanguage as its precondition, so use the same
    # check here to fail early rather than after another reboot.
    try {
        Get-InstalledLanguage -Language $Language -ErrorAction Stop | Out-Null
        Write-Host "$Language is installed."
    } catch {
        throw "$Language is not installed after the install attempt. See the capability state above. ($_)"
    }
} finally {
    if ($mustRestore) {
        Write-Host "Restoring NoAutoUpdate to $originalNoAutoUpdate"
        Set-NoAutoUpdateValue -Value $originalNoAutoUpdate
    }
}
