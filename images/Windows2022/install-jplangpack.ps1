<#+
    Purpose:
      Install Japanese (ja-JP) language pack & related capabilities on Windows Server 2022.
      This script is intended to run in an Azure Image Builder (AIB) customization step
      BEFORE applying user/system locale overrides (which occur in a separate script
      such as install-languagepack.ps1) and followed by a reboot.

    Recommended AIB sequence:
      1. Run this script (language + capabilities install)
      2. WindowsRestart customizer
      3. Run install-languagepack.ps1 (sets UI/culture/system locale & copies to system)
      4. WindowsRestart customizer
      5. Generalize / image capture

    Notes:
      - Uses Install-Language when available; falls back to capability adds if not.
      - Idempotent: skips items already present.
      - Avoids manual partial ISO fetch (was brittle & hash-dependent).

    Verification after reboot:
      Get-InstalledLanguage | Where Language -eq 'ja-JP'
      Get-WindowsCapability -Online | Where-Object Name -like '*ja-JP*' | Where-Object State -eq Installed

    Exit codes:
      0 success / 1 failure installing core language.
#>

[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'

$Lang      = 'ja-JP'
$Capabilities = @(
    'Language.Basic~~~ja-JP~0.0.1.0'
    'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0'
    'Language.OCR~~~ja-JP~0.0.1.0'
    'Language.Handwriting~~~ja-JP~0.0.1.0'       # Optional handwriting
    'Language.Speech~~~ja-JP~0.0.1.0'            # Optional speech
    'Language.TextToSpeech~~~ja-JP~0.0.1.0'      # Optional TTS
)

Write-Host "[LangInstall] Starting Japanese language installation for $Lang"

# Helper to install a capability if missing
function Install-CapabilityIfNeeded {
    param([Parameter(Mandatory)][string]$Name)
    $cap = Get-WindowsCapability -Online -Name $Name -ErrorAction SilentlyContinue
    if ($cap -and $cap.State -eq 'Installed') {
        Write-Host "[LangInstall] Capability already installed: $Name"
        return
    }
    Write-Host "[LangInstall] Installing capability: $Name"
    Add-WindowsCapability -Online -Name $Name -ErrorAction Stop | Out-Null
}

# Try modern Install-Language (Server 2022 supports it via LanguagePackManagement PowerShell 5.1 update)
$installLanguageCmd = Get-Command -Name Install-Language -ErrorAction SilentlyContinue
if ($installLanguageCmd) {
    $already = Get-InstalledLanguage -Language $Lang -ErrorAction SilentlyContinue
    if (-not $already) {
        Write-Host "[LangInstall] Using Install-Language for $Lang"
        try {
            Install-Language -Language $Lang -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "[LangInstall] Install-Language failed: $_. Falling back to capabilities path."
        }
    } else {
        Write-Host "[LangInstall] Language $Lang already installed (Install-Language path)."
    }
} else {
    Write-Host "[LangInstall] Install-Language cmdlet not found. Using capability-only path."
}

# Ensure Basic at least
Install-CapabilityIfNeeded -Name 'Language.Basic~~~ja-JP~0.0.1.0'

# Remaining capabilities
foreach ($c in $Capabilities | Where-Object { $_ -ne 'Language.Basic~~~ja-JP~0.0.1.0' }) {
    try { Install-CapabilityIfNeeded -Name $c } catch { Write-Warning "[LangInstall] Failed to install $c : $_" }
}

# Time zone is sometimes expected already at later script, but safe to set here too
try {
    Set-TimeZone -Id 'Tokyo Standard Time'
    Write-Host '[LangInstall] Time zone set to Tokyo Standard Time'
} catch { Write-Warning "[LangInstall] Failed to set time zone: $_" }

# Final validation
$validation = Get-InstalledLanguage -Language $Lang -ErrorAction SilentlyContinue
if (-not $validation) {
    Write-Error "[LangInstall] FAILED: $Lang language not detected after installation attempts."
    exit 1
}

Write-Host '[LangInstall] Completed Japanese language pack installation. Reboot recommended.'
exit 0
