################################################################################
##  File:  Install-PowerShellCore.ps1
##  Desc:  Install PowerShell Core LTS via Chocolatey
################################################################################

Write-Host "Installing PowerShell Core LTS via Chocolatey..."

# Install PowerShell Core LTS
choco install powershell-core --version=7.4.6 -y --no-progress

# Update PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify installation
pwsh -Version

Write-Host "PowerShell Core LTS installation completed"
