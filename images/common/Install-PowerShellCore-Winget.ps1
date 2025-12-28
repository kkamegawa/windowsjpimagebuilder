################################################################################
##  File:  Install-PowerShellCore-Winget.ps1
##  Desc:  Install PowerShell Core LTS via winget (Windows Server 2025)
################################################################################

Write-Host "Installing PowerShell Core LTS via winget..."

try {
    # Install PowerShell Core LTS using winget
    winget install --id Microsoft.PowerShell.LTS --source winget --silent --accept-package-agreements --accept-source-agreements
    
    if ($LASTEXITCODE -ne 0) {
        throw "Winget installation failed with exit code $LASTEXITCODE"
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
