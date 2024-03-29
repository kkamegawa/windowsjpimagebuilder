function Set-LanguageOptions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserLocale,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $InputLanguageID,

        [Parameter(Mandatory = $true)]
        [int] $LocationGeoId,

        [Parameter(Mandatory = $true)]
        [bool] $CopySettingsToSystemAccount,

        [Parameter(Mandatory = $true)]
        [bool] $CopySettingsToDefaultUserAccount,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SystemLocale
    )

    # Reference:
    # - Guide to Windows Vista Multilingual User Interface
    #   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-vista/cc721887(v=ws.10)
    $xmlFileContentTemplate = @'
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToSystemAcct="{0}" CopySettingsToDefaultUserAcct="{1}"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="{2}" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="{3}" Default="true"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="{2}"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
    <gs:LocationPreferences>
        <gs:GeoID Value="{4}"/>
    </gs:LocationPreferences>
    <gs:SystemLocale Name="{5}"/>
</gs:GlobalizationServices>
'@

    # Create the XML file content.
    $fillValues = @(
        $CopySettingsToSystemAccount.ToString().ToLowerInvariant(),
        $CopySettingsToDefaultUserAccount.ToString().ToLowerInvariant(),
        $UserLocale,
        $InputLanguageID,
        $LocationGeoId,
        $SystemLocale
    )
    $xmlFileContent = $xmlFileContentTemplate -f $fillValues

    Write-Verbose -Message ('MUI XML: {0}' -f $xmlFileContent)

    # Create a new XML file and set the content.
    $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')
    Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFileContent

    # Copy the current user language settings to the default user account and system user account.
    $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
    $procStartInfo.UseShellExecute = $false
    $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    $proc = [System.Diagnostics.Process]::Start($procStartInfo)
    $proc.WaitForExit()
    $proc.Dispose()

    # Delete the XML file.
    Remove-Item -LiteralPath $xmlFileFilePath -Force
}

# Set the current user's language options and copy it to the default user account and system account. Also, set the system locale.
#
# References:
# - Default Input Profiles (Input Locales) in Windows
#   https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
# - Table of Geographical Locations
#   https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
$params = @{
    UserLocale                       = 'ja-JP'
    InputLanguageID                  = '0411:{03B5835F-F03C-411B-9CE2-AA23E1171E36}{A76C93D9-5523-4E90-AAFA-4DB112F9AC76}'
    LocationGeoId                    = 122  # Japan
    CopySettingsToSystemAccount      = $true
    CopySettingsToDefaultUserAccount = $true
    SystemLocale                     = 'ja-JP'
}
Set-LanguageOptions @params -Verbose
