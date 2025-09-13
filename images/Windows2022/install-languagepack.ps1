<#+
    Configure Japanese (ja-JP) for Windows Server 2022 after language pack installation + reboot.

    This script mirrors the Windows2025 approach using the International module
    rather than the legacy intl.cpl XML method.

    Expected run order in AIB:
      (1) install-jplangpack.ps1  -> installs language/capabilities
      (2) WindowsRestart          -> ensures components staged
      (3) THIS script              -> sets per-user + system + default
      (4) WindowsRestart          -> ensures logon UI picks up changes

    If logon screen still appears in English, you can enable the optional
    registry fallback section near the bottom (commented out by default).
#>

[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'

$Lang      = 'ja-JP'
$GeoId     = 122  # Japan
$TimeZone  = 'Tokyo Standard Time'
$InputTip  = '0411:00000411'  # Japanese IME

Write-Host '[LangConfig] Starting locale configuration'

# 1. Validate language installed (previous step should have done this)
try {
    $installed = Get-InstalledLanguage -Language $Lang -ErrorAction Stop
    Write-Host "[LangConfig] Language $Lang installed." 
} catch {
    Write-Error "[LangConfig] Language $Lang not installed. Run install-jplangpack.ps1 earlier + reboot. $_"
    exit 1
}

# 2. User language list
$userLangList = New-WinUserLanguageList -Language $Lang
if ($userLangList[0].InputMethodTips -notcontains $InputTip) {
    $userLangList[0].InputMethodTips.Add($InputTip) | Out-Null
}
Set-WinUserLanguageList -LanguageList $userLangList -Force | Out-Null
Write-Host '[LangConfig] Set user language list.'

# 3. UI override
Set-WinUILanguageOverride -Language $Lang
Write-Host '[LangConfig] UI language override set.'

# 4. Culture / system locale
Set-Culture -CultureInfo $Lang
Set-WinHomeLocation -GeoId $GeoId
Set-WinSystemLocale -SystemLocale $Lang
Write-Host '[LangConfig] Culture, home location, and system locale set.'

# 5. Time zone (optional)
try {
    Set-TimeZone -Name $TimeZone
    Write-Host "[LangConfig] Time zone set to $TimeZone"
} catch { Write-Warning "[LangConfig] Time zone change failed: $_" }

# 6. Copy to system + default (Welcome screen & new users)
try {
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    Write-Host '[LangConfig] Copied international settings to System & Default.'
} catch { Write-Warning "[LangConfig] Copy-UserInternationalSettingsToSystem failed: $_" }

# 7. Optional fallback: force PreferredUILanguages to only ja-JP if logon screen remains English
#    Enable only if necessary.
<#
try {
    $muiSettingsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\MUI\Settings'
    $pref = (Get-ItemProperty -Path $muiSettingsPath -Name PreferredUILanguages -ErrorAction SilentlyContinue).PreferredUILanguages
    if ($null -eq $pref -or ($pref -notcontains $Lang) -or ($pref.Count -gt 1)) {
        Write-Host '[LangConfig] Adjusting PreferredUILanguages registry to only ja-JP'
        New-Item -Path $muiSettingsPath -Force | Out-Null
        Set-ItemProperty -Path $muiSettingsPath -Name PreferredUILanguages -Value ([string[]]@($Lang))
    }
} catch { Write-Warning "[LangConfig] Fallback registry PreferredUILanguages adjustment failed: $_" }
#>

Write-Host '[LangConfig] Completed. Reboot recommended now.'
exit 0
