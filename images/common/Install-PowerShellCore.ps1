################################################################################
##  File:  Install-PowerShellCore.ps1
##  Desc:  Install PowerShell Core LTS via Chocolatey
################################################################################

Write-Host "Fetching latest PowerShell Core LTS version from Chocolatey..."

try {
    # Get the latest LTS version from Chocolatey
    $chocoSearchOutput = choco search powershell-core --exact --all-versions --limit-output
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to query Chocolatey for PowerShell Core versions"
    }
    
    # Parse output and filter for LTS versions (7.4.x series is current LTS)
    # Format is: packagename|version
    $versions = $chocoSearchOutput | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Length -ge 2) {
            [PSCustomObject]@{
                Name = $parts[0]
                Version = [version]$parts[1]
            }
        }
    } | Where-Object { $_.Version.Major -eq 7 -and $_.Version.Minor -eq 4 } | Sort-Object -Property Version -Descending
    
    if ($versions.Count -eq 0) {
        throw "No PowerShell Core LTS versions found"
    }
    
    $latestLTSVersion = $versions[0].Version.ToString()
    Write-Host "Latest PowerShell Core LTS version: $latestLTSVersion"
    
    # Install PowerShell Core LTS
    Write-Host "Installing PowerShell Core LTS version $latestLTSVersion via Chocolatey..."
    choco install powershell-core --version=$latestLTSVersion -y --no-progress
    
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
