################################################################################
##  File:  Install-PowerShellCore.ps1
##  Desc:  Install PowerShell Core LTS via Chocolatey
################################################################################

$PowerShellVersion = "7.4.6"

Write-Host "Installing PowerShell Core LTS version $PowerShellVersion via Chocolatey..."

try {
    # Install PowerShell Core LTS
    choco install powershell-core --version=$PowerShellVersion -y --no-progress
    
    if ($LASTEXITCODE -ne 0) {
        throw "Chocolatey installation failed with exit code $LASTEXITCODE"
    }
    
    # Update PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # Verify installation
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        pwsh -Version
        Write-Host "PowerShell Core LTS installation completed successfully"
    } else {
        throw "PowerShell Core installation failed - pwsh command not found"
    }
} catch {
    Write-Error "Failed to install PowerShell Core: $_"
    exit 1
}
