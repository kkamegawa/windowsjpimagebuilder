<#
    .SYNOPSIS
    Installs a Windows display language (ja-JP by default) on Windows Server 2025 under a
    single deadline, with per-capability diagnostics.

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
      2. Every operation that can reach the Features on Demand source - Install-Language and
         each Add-WindowsCapability retry - runs under one shared deadline derived from
         -TimeoutMinutes, so no single download can consume the whole image build timeout.
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
    Deadline for the whole language install, covering Install-Language and every capability
    retry together. Defaults to 25 minutes.

    .NOTES
    References:
    - Install-Language (LanguagePackManagement):
      https://learn.microsoft.com/powershell/module/languagepackmanagement/install-language?view=windowsserver2025-ps
    - Add-WindowsCapability (DISM):
      https://learn.microsoft.com/powershell/module/dism/add-windowscapability
#>

[CmdletBinding()]
param(
    # Restricted to a BCP-47 style tag so the value can be embedded in the child process
    # command line below without further quoting concerns.
    [ValidatePattern('^[A-Za-z]{2,3}(-[A-Za-z0-9]+)*$')]
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

function Get-RemainingSeconds {
    param([datetime]$Deadline)

    $remaining = [int][math]::Floor(($Deadline - (Get-Date)).TotalSeconds)
    if ($remaining -lt 0) {
        return 0
    }

    return $remaining
}

function Invoke-BoundedOperation {
    <#
        Runs a command in a child Windows PowerShell process and kills it once the deadline
        is reached, so a servicing operation that never returns cannot hold up the image
        build. A child process is used rather than Start-Job because the job infrastructure
        is unavailable when the host runs in a restricted language mode.

        Returns an object with TimedOut, ErrorMessage and Elapsed; it never throws for a
        failure of the command itself, so the caller decides what is fatal.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )

    $outcome = [pscustomobject]@{
        Description  = $Description
        TimedOut     = $false
        ErrorMessage = $null
        Elapsed      = [TimeSpan]::Zero
    }

    if ($TimeoutSeconds -le 0) {
        $outcome.TimedOut = $true
        $outcome.ErrorMessage = 'No time left before the deadline.'
        return $outcome
    }

    $powerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    $wrapped = "`$ErrorActionPreference = 'Stop'; try { $Command; exit 0 } catch { Write-Error `$_; exit 1 }"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $process = Start-Process -FilePath $powerShellPath -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
            -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', $wrapped)

        # Touching Handle keeps the process handle open, without which ExitCode is not
        # readable after the process has exited.
        $null = $process.Handle

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $outcome.TimedOut = $true
            $outcome.ErrorMessage = "Did not finish within $TimeoutSeconds seconds."
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        } else {
            # WaitForExit(milliseconds) can return before the exit code is available, so let
            # the process settle before reading it.
            $process.WaitForExit()

            if ($process.ExitCode -ne 0) {
                $stderr = Get-Content -Path $stderrPath -Raw -ErrorAction SilentlyContinue
                if ($stderr) {
                    $outcome.ErrorMessage = ($stderr -replace '\s+', ' ').Trim()
                } else {
                    $outcome.ErrorMessage = "Exited with code $($process.ExitCode)."
                }
            }
        }

        $stdout = Get-Content -Path $stdoutPath -Raw -ErrorAction SilentlyContinue
        if ($stdout -and $stdout.Trim()) {
            Write-Host $stdout.TrimEnd()
        }
    } finally {
        $stopwatch.Stop()
        $outcome.Elapsed = $stopwatch.Elapsed
        Remove-Item -Path $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }

    return $outcome
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

# One deadline covers Install-Language and every capability retry, so the whole step is
# bounded rather than just its first operation.
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

try {
    Write-Host "Installing language $Language (deadline: $TimeoutMinutes minutes from now)"

    $install = Invoke-BoundedOperation -Description "Install-Language $Language" `
        -TimeoutSeconds (Get-RemainingSeconds -Deadline $deadline) `
        -Command "Import-Module -Name LanguagePackManagement; Install-Language -Language '$Language' -CopyToSettings | Out-Null"

    Write-Host ("Install-Language took {0:N1} minutes." -f $install.Elapsed.TotalMinutes)

    if ($install.TimedOut) {
        Write-Warning "Install-Language hit the deadline. Continuing with per-capability installation. ($($install.ErrorMessage))"
    } elseif ($install.ErrorMessage) {
        # A partial install is expected when an optional Feature on Demand is unavailable.
        # The per-capability pass below reports which one, and the final check decides
        # whether the build can continue.
        Write-Warning "Install-Language reported an error: $($install.ErrorMessage)"
    } else {
        Write-Host "Install-Language completed."
    }

    # Report and retry the individual capabilities. und-JPAN covers the Japanese font
    # capability, which is named after the script rather than the language tag.
    $capabilities = Get-WindowsCapability -Online |
        Where-Object { $_.Name -like "*$Language*" -or $_.Name -like '*und-JPAN*' }

    Write-Host "Language capability state:"
    foreach ($capability in $capabilities) {
        Write-Host ("  {0,-12} {1}" -f $capability.State, $capability.Name)
    }

    foreach ($capability in ($capabilities | Where-Object { $_.State -ne 'Installed' })) {
        $remaining = Get-RemainingSeconds -Deadline $deadline
        if ($remaining -le 0) {
            Write-Warning "Deadline reached; skipping the remaining capability retries."
            break
        }

        Write-Host "Retrying capability $($capability.Name) (up to $remaining seconds)"
        $retry = Invoke-BoundedOperation -Description $capability.Name `
            -TimeoutSeconds $remaining `
            -Command "Add-WindowsCapability -Online -Name '$($capability.Name)' | Out-Null"

        if ($retry.TimedOut -or $retry.ErrorMessage) {
            Write-Warning "  $($capability.Name) could not be installed: $($retry.ErrorMessage)"
        } else {
            Write-Host "  installed."
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
