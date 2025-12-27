################################################################################
##  File:  Install-Chocolatey.ps1
##  Desc:  Install Chocolatey package manager
################################################################################

Write-Host "Installing Chocolatey..."

# Set TLS 1.2 for downloading
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install Chocolatey
$env:chocolateyUseWindowsCompression = 'true'
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Update PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify installation
choco --version

Write-Host "Chocolatey installation completed"
