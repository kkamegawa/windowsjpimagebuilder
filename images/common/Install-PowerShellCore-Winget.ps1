################################################################################
##  File:  Install-PowerShellCore-Winget.ps1
##  Desc:  Install PowerShell Core LTS via winget (Windows Server 2025)
################################################################################

Write-Host "Installing PowerShell Core LTS via winget..."

# Install PowerShell Core LTS using winget
winget install --id Microsoft.PowerShell.LTS --source winget --silent --accept-package-agreements --accept-source-agreements

# Update PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify installation
pwsh -Version

Write-Host "PowerShell Core LTS installation completed"
