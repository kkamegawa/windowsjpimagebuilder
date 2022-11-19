$downloadUrl = "https://software-download.microsoft.com/download/pr/17763.1.180914-1434.rs5_release_SERVERLANGPACKDVD_OEM_MULTI.iso"
$downloadPath = 'c:\images\LangPack.iso'

### downlaod 
$wc = New-Object net.webclient
$wc.Downloadfile($downloadUrl, $downloadPath)

# Install Language pack
## ISO mount
Mount-DiskImage $downloadPath
## Get mounted disk letter
$driveLetter = (Get-DiskImage -ImagePath $downloadPath | Get-Volume).DriveLetter
$languagePackPath = $driveLetter + ":\x64\langpacks\Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab"
## install language pack
lpksetup.exe /i ja-JP /p $languagePackPath /r /s
Wait-Process -Name lpksetup

# Clean file
## Unmount disk
DisMount-DiskImage $downloadPath
## Delete ISO file
Remove-Item $downloadPath     
