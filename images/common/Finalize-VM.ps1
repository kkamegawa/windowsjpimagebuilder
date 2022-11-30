################################################################################
##  File:  Finalize-VM.ps1
##  Desc:  VM Finalize script, machine level configuration
################################################################################

function Enable-WindowsUpdate {
    $AutoUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    If (Test-Path -Path $AutoUpdatePath) {
        Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 0
        Write-Host "Enabled Windows Update"
    } else {
        Write-Host "Windows Update key does not exist"
    }
}

Write-Host "Cleanup WinSxS"
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Host "Clean up various directories"
@(
    "$env:SystemDrive\Recovery",
    "$env:SystemRoot\logs",
    "$env:SystemRoot\winsxs\manifestcache",
    "$env:SystemRoot\Temp",
    "$env:TEMP"
) | ForEach-Object {
    if (Test-Path $_) {
        Write-Host "Removing $_"
        cmd /c "takeown /d Y /R /f $_ 2>&1" | Out-Null
        cmd /c "icacls $_ /grant:r administrators:f /t /c /q 2>&1" | Out-Null
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host "Enable Server Manager on Logon"
Get-ScheduledTask -TaskName ServerManager | Enable-ScheduledTask

Write-Host "Enable 'Allow your PC to be discoverable by other PCs' popup"
if(Test-Path -Path "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff") {
    wrie-host "Remove 'Allow your PC to be discoverable by other PCs' popup"
    Remove-Item -Path HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff -Force
}

Write-Host "Enable Windows Update"
Enable-WindowsUpdate

Write-Host "Setting local execution policy"
Set-ExecutionPolicy -ExecutionPolicy Undefined  -Scope LocalMachine  -ErrorAction Continue | Out-Null
Get-ExecutionPolicy -List
