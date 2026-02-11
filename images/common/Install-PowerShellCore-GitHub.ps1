################################################################################
##  File:  Install-PowerShellCore-GitHub.ps1
##  Desc:  Install latest non-preview PowerShell from GitHub releases
################################################################################

$ErrorActionPreference = "Stop"

Write-Host "Installing latest non-preview PowerShell from GitHub releases..."

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $headers = @{ "User-Agent" = "AzureImageBuilder" }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" -Headers $headers

    if (-not $release -or -not $release.assets) {
        throw "Failed to query GitHub releases for PowerShell"
    }

    $asset = $release.assets | Where-Object { $_.name -match '^PowerShell-.*-win-x64\.msi$' } | Select-Object -First 1
    if (-not $asset) {
        throw "PowerShell MSI asset not found in latest release"
    }

    $downloadUrl = $asset.browser_download_url
    $msiPath = Join-Path $env:TEMP $asset.name

    Write-Host "Downloading $($asset.name)..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -Headers $headers -UseBasicParsing

    $signature = Get-AuthenticodeSignature -FilePath $msiPath
    if ($signature.Status -ne "Valid") {
        throw "MSI signature validation failed: $($signature.Status)"
    }
    if ($signature.SignerCertificate.Subject -notmatch "CN=Microsoft Corporation") {
        throw "MSI signer is not Microsoft Corporation"
    }

    Write-Host "Installing PowerShell from $($asset.name)..."
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "MSI installation failed with exit code $($process.ExitCode)"
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        pwsh -Version
        Write-Host "PowerShell installation completed successfully"
    } else {
        throw "PowerShell installation failed - pwsh command not found"
    }

    Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
} catch {
    Write-Error "Failed to install PowerShell: $_"
    exit 1
}
