#Requires -Version 5.1

<#
.SYNOPSIS
    Installs the pinned PowerShell 7.6.10 x64 MSI release.

.DESCRIPTION
    Downloads the official PowerShell 7.6.10 x64 MSI, verifies its SHA-256
    checksum, and installs it silently for Azure Image Builder.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$version = '7.6.10'
$installerName = "PowerShell-$version-win-x64.msi"
$installerUri = "https://github.com/PowerShell/PowerShell/releases/download/v$version/$installerName"
$expectedSha256 = '7D8DAEA48B450D4D62FCD1AC4D6FAA7AC2DB5E11ABA5061EE81B7496ADCA8C07'
$installerPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $installerName

try {
    Write-Host "Downloading PowerShell $version from the official GitHub release..."

    # Windows PowerShell 5.1 may otherwise negotiate an older TLS version.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $maxDownloadAttempts = 3
    for ($attempt = 1; $attempt -le $maxDownloadAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $installerUri -OutFile $installerPath -UseBasicParsing -TimeoutSec 1200
            break
        }
        catch {
            if ($attempt -eq $maxDownloadAttempts) {
                throw "Download failed after $maxDownloadAttempts attempts: $($_.Exception.Message)"
            }

            if (Test-Path -LiteralPath $installerPath -PathType Leaf) {
                Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
            }

            $retryDelaySeconds = 15 * $attempt
            Write-Host "Download attempt $attempt failed. Retrying in $retryDelaySeconds seconds..."
            Start-Sleep -Seconds $retryDelaySeconds
        }
    }

    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "The PowerShell MSI was not downloaded from $installerUri."
    }

    $actualSha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
    if (-not [string]::Equals($actualSha256, $expectedSha256, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SHA-256 mismatch for $installerName. Expected $expectedSha256, got $actualSha256."
    }

    Write-Host "Checksum verified. Installing PowerShell $version silently..."
    $msiexecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
    $arguments = '/i "{0}" /qn /norestart ADD_PATH=1 USE_MU=0 ENABLE_MU=0' -f $installerPath
    $process = Start-Process -FilePath $msiexecPath -ArgumentList $arguments -Wait -PassThru

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "msiexec.exe failed to install $installerName with exit code $($process.ExitCode)."
    }

    $pwshPath = Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe'
    if (-not (Test-Path -LiteralPath $pwshPath -PathType Leaf)) {
        throw "PowerShell was installed, but the expected executable was not found at $pwshPath."
    }

    $installedVersion = (& $pwshPath -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $installedVersion -ne $version) {
        throw "Installed PowerShell version verification failed. Expected $version, got '$installedVersion'."
    }

    if ($process.ExitCode -eq 3010) {
        Write-Host "PowerShell $version installed successfully; a restart is required."
    }
    else {
        Write-Host "PowerShell $version installed and verified successfully."
    }
}
catch {
    [Console]::Error.WriteLine("PowerShell $version installation failed: $($_.Exception.Message)")
    exit 1
}
finally {
    if (Test-Path -LiteralPath $installerPath -PathType Leaf) {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}
