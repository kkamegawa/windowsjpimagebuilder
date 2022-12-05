$downloadPath = 'c:\images\langpack.iso'

# Install Language pack
## ISO mount
Mount-DiskImage $downloadPath
## Get mounted disk letter
$driveLetter = (Get-DiskImage -ImagePath $downloadPath | Get-Volume).DriveLetter
$lppath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab"
## install language pack
dism /online /add-package /packagepath:$lppath >> $log
Wait-Process -Name dism

# Install Features on Demand
$fodpath = $driveLetter + ":\LanguagesAndOptionalFeatures\Microsoft-Windows-LanguageFeatures-Basic-ja-jp-Package~31bf3856ad364e35~amd64~~.cab"
dism /online /add-package /packagepath:$fodpath >> $log
Wait-Process -Name dism

# Clean file
## Unmount disk
DisMount-DiskImage $downloadPath
## Delete ISO file
Remove-Item $downloadPath
