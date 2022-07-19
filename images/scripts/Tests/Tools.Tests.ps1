Import-Module (Join-Path $PSScriptRoot "..\SoftwareReport\SoftwareReport.Common.psm1") -DisableNameChecking


Describe "NET48" {
    It "NET48" {
        (Get-DotnetFrameworkTools).Versions | Should -Contain "4.8"
    }
}

Describe "PowerShell Core" {
    It "pwsh" {
        "pwsh --version" | Should -ReturnZeroExitCode
    }

    It "Execute 2+2 command" {
        pwsh -Command "2+2" | Should -BeExactly 4
    }
}


Describe "VCRedist" -Skip:(Test-IsWin22) {
    It "vcredist_140" -Skip:(Test-IsWin19) {
        "C:\Windows\System32\vcruntime140.dll" | Should -Exist
    }

    It "vcredist_2010_x64" -Skip:(Test-IsWin16) {
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1D8E6291-B0D5-35EC-8441-6616F567A0F7}" | Should -Exist
        "C:\Windows\System32\msvcr100.dll" | Should -Exist
    }

    It "vcredist_2010_x64" -Skip:(Test-IsWin16) {
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1D8E6291-B0D5-35EC-8441-6616F567A0F7}" | Should -Exist
        "C:\Windows\System32\msvcr100.dll" | Should -Exist
    }
}

