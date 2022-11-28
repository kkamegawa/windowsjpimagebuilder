################################################################################
##  File:  Initialize-VM.ps1
##  Desc:  VM initialization script, machine level configuration
################################################################################

function Disable-WindowsUpdate {
    $AutoUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    If (Test-Path -Path $AutoUpdatePath) {
        Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 1
        Write-Host "Disabled Windows Update"
    } else {
        Write-Host "Windows Update key does not exist"
    }
}

Write-Host "Disable Server Manager on Logon"
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

Write-Host "Disable 'Allow your PC to be discoverable by other PCs' popup"
New-Item -Path HKLM:\System\CurrentControlSet\Control\Network -Name NewNetworkWindowOff -Force

Write-Host "Disable Windows Update"
Disable-WindowsUpdate

Write-Host "Setting local execution policy"
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine  -ErrorAction Continue | Out-Null
Get-ExecutionPolicy -List
