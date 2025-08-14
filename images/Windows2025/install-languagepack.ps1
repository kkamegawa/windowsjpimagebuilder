<#
    Configure Japanese (ja-JP) as the default UI, culture, and input for the current user,
    then copy those settings to the Welcome screen/system accounts and new user profiles.

    This script uses the International + LanguagePackManagement PowerShell modules,
    which are the supported approach on Windows Server 2022/2025.

    Prereq: ja-JP language is already installed and the machine was rebooted
                    (we do this in the previous AIB step with Install-Language and a WindowsRestart).

    References:
    - Install-Language (LanguagePackManagement):
        https://learn.microsoft.com/powershell/module/languagepackmanagement/install-language?view=windowsserver2025-ps
    - International module (Set-WinUILanguageOverride, Set-Culture, etc.):
        https://learn.microsoft.com/powershell/module/international/?view=windowsserver2025-ps
    - Copy-UserInternationalSettingsToSystem:
        https://learn.microsoft.com/powershell/module/international/copy-userinternationalsettingstosystem?view=windowsserver2025-ps
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Lang    = 'ja-JP'
$GeoId   = 122   # Japan
$TimeZone = 'Tokyo Standard Time'  # Optional but commonly expected for JP images

Write-Verbose "Configuring language and locale to $Lang"

# Ensure the language is installed (should be true after previous step + reboot)
try {
        $installed = Get-InstalledLanguage -Language $Lang -ErrorAction Stop
} catch {
        Write-Warning "Language $Lang does not appear to be installed. Exiting with error. ($_ )"
        throw
}

# Set current user language list (includes keyboard/IME). Force replaces the list.
$userLangList = New-WinUserLanguageList -Language $Lang

# Optionally ensure Japanese IME is present/default (often added automatically with ja-JP)
# $userLangList[0].InputMethodTips.Add('0411:00000411')
Set-WinUserLanguageList -LanguageList $userLangList -Force | Out-Null

# Set UI language override for the current user
Set-WinUILanguageOverride -Language $Lang

# Set culture/format and system-wide settings
Set-Culture -CultureInfo $Lang
Set-WinHomeLocation -GeoId $GeoId
Set-WinSystemLocale -SystemLocale $Lang

# Optional: set time zone to Japan
try {
        Set-TimeZone -Name $TimeZone
} catch {
        Write-Verbose "Skipping time zone change: $TimeZone is not available or operation failed. ($_ )"
}

# Copy current user international settings to Welcome screen/system accounts and new users
Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true

Write-Host "ja-JP has been configured for user, system, and default user. A reboot will finalize changes."
