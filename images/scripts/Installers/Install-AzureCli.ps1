################################################################################
##  File:  Install-AzureCli.ps1
##  Desc:  Install Azure CLI
################################################################################

Write-Host "Install the latest Azure CLI release"
$azCliUrl = "https://aka.ms/installazurecliwindows"
Install-Binary -Url $azCliUrl -Name "azure-cli.msi"

$AzureCliExtensionPath = Join-Path $Env:CommonProgramFiles 'AzureCliExtensionDirectory'
if (-not(Test-Path -Path $AzureCliExtensionPath)) {
	New-Item -ItemType "directory" -Path $AzureCliExtensionPath -Force
}

[Environment]::SetEnvironmentVariable("AZURE_EXTENSION_DIR", $azureCliExtensionPath, [System.EnvironmentVariableTarget]::Machine)

Invoke-PesterTests -TestFile "CLI.Tools" -TestName "Azure CLI"