function Invoke-LanguagePackCabFileDownload
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $LangPackIsoUri,

        [Parameter(Mandatory = $true)]
        [long] $OffsetToCabFileInIsoFile,

        [Parameter(Mandatory = $true)]
        [long] $CabFileSize,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $CabFileHash,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationFilePath
    )

    $request = [System.Net.HttpWebRequest]::Create($LangPackIsoUri)
    $request.Method = 'GET'

    # Set the language pack CAB file data range.
    $request.AddRange('bytes', $OffsetToCabFileInIsoFile, $OffsetToCabFileInIsoFile + $CabFileSize - 1)

    # Donwload the language pack CAB file.
    $response = $request.GetResponse()
    $reader = New-Object -TypeName 'System.IO.BinaryReader' -ArgumentList $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($DestinationFilePath)
    $contents = $reader.ReadBytes($response.ContentLength)
    $fileStream.Write($contents, 0, $contents.Length)
    $fileStream.Dispose()
    $reader.Dispose()
    $response.Close()
    $response.Dispose()

    # Verify integrity of the downloaded language pack CAB file.
    $fileHash = Get-FileHash -Algorithm SHA1 -LiteralPath $DestinationFilePath
    if ($fileHash.Hash -ne $CabFileHash) {
        throw ('The file hash of the language pack CAB file "{0}" is not match to expected value. The download was may failed.') -f $DestinationFilePath
    }
}

# Download the language pack CAB file for Japanese.
#
# Reference:
# - Cannot configure a language pack for Windows Server 2019 Desktop Experience
#   https://docs.microsoft.com/en-us/troubleshoot/windows-server/shell-experience/cannot-configure-language-pack-windows-server-desktop-experience
$langPackFilePath = Join-Path -Path $env:TEMP -ChildPath 'Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab'
$params = @{
    LangPackIsoUri           = 'https://software-static.download.prss.microsoft.com/pr/download/17763.1.180914-1434.rs5_release_SERVERLANGPACKDVD_OEM_MULTI.iso'
    OffsetToCabFileInIsoFile = 0x3BD26800L
    CabFileSize              = 62015873
    CabFileHash              = 'B562ECD51AFD32DB6E07CB9089691168C354A646'
    DestinationFilePath      = $langPackFilePath
}
Invoke-LanguagePackCabFileDownload @params -Verbose

# Install the language pack.
Add-WindowsPackage -Online -NoRestart -PackagePath $langPackFilePath -Verbose

# Delete the language pack CAB file.
Remove-Item -LiteralPath $langPackFilePath -Force -Verbose

# Install the Japanese language related capabilities.
Add-WindowsCapability -Online -Name 'Language.Basic~~~ja-JP~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.OCR~~~ja-JP~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.Handwriting~~~ja-JP~0.0.1.0' -Verbose   # Optional
Add-WindowsCapability -Online -Name 'Language.Speech~~~ja-JP~0.0.1.0' -Verbose        # Optional
Add-WindowsCapability -Online -Name 'Language.TextToSpeech~~~ja-JP~0.0.1.0' -Verbose  # Optional

# Set the time zone for the current computer.
Set-TimeZone -Id 'Tokyo Standard Time' -Verbose
