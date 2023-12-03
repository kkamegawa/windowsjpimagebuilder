$downloadPath = 'c:\images\langpack.iso'

# Install Language pack
## ISO mount
Mount-DiskImage $downloadPath
## Get mounted disk letter
$driveLetter = (Get-DiskImage -ImagePath $downloadPath | Get-Volume).DriveLetter
$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab"
## install language pack
lpksetup.exe /i ja-JP /p $lppath /r /s
Wait-Process -Name lpksetup

# Install Features on Demand
$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-LanguageFeatures-Basic-ja-jp-Package~31bf3856ad364e35~amd64~~.cab"
lpksetup.exe /i ja-JP /p $lppath /r /s
Wait-Process -Name lpksetup

$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-LanguageFeatures-Fonts-Jpan-Package~31bf3856ad364e35~amd64~~.cab"
lpksetup.exe /i ja-JP /p $lppath /r /s
Wait-Process -Name lpksetup

$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-LanguageFeatures-Handwriting-ja-jp-Package~31bf3856ad364e35~amd64~~.cab"
lpksetup.exe /i ja-JP /p $lppath /r /s
Wait-Process -Name lpksetup

$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-LanguageFeatures-Speech-ja-jp-Package~31bf3856ad364e35~amd64~~.cab"
lpksetup.exe /i ja-JP /p $lppath /r /s
Wait-Process -Name lpksetup

$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-LanguageFeatures-TextToSpeech-ja-jp-Package~31bf3856ad364e35~amd64~~.cab"
lpksetup.exe /i ja-JP /p $lppath /r /s
Wait-Process -Name lpksetup

# Clean file
## Unmount disk
DisMount-DiskImage $downloadPath
## Delete ISO file
Remove-Item $downloadPath
