################################################################################
##  File:  Install-Chocolatey.ps1
##  Desc:  Install Chocolatey package manager
################################################################################

Write-Host "Installing Chocolatey..."

# Set TLS 1.2 for downloading
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install Chocolatey using official method
try {
    $env:chocolateyUseWindowsCompression = 'true'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Update PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # Verify installation
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco --version
        Write-Host "Chocolatey installation completed successfully"
    } else {
        throw "Chocolatey installation failed - choco command not found"
    }
} catch {
    Write-Error "Failed to install Chocolatey: $_"
    exit 1
}
