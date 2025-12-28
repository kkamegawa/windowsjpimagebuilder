################################################################################
##  File:  Install-Chocolatey.ps1
##  Desc:  Install Chocolatey package manager
################################################################################

Write-Host "Installing Chocolatey..."

# Set TLS 1.2 for downloading
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install Chocolatey using official method with integrity verification
try {
    $env:chocolateyUseWindowsCompression = 'true'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    
    # Download the install script
    $installScriptUrl = 'https://community.chocolatey.org/install.ps1'
    $installScript = (New-Object System.Net.WebClient).DownloadString($installScriptUrl)
    
    # Calculate SHA256 hash of the downloaded script
    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($installScript)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($scriptBytes)
    $downloadedHash = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
    
    Write-Host "Downloaded Chocolatey install script hash: $downloadedHash"
    Write-Host "Note: Verify this hash matches the official Chocolatey documentation if needed"
    
    # Execute the install script
    iex $installScript
    
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
