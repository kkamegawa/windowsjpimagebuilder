$DefaultHKEY = "HKU\DEFAULT_USER"
$DefaultRegPath = "C:\Users\Default\NTUSER.DAT"

Get-Content 'C:\images\ja-jp-default.reg' | Set-Content 'C:\images\ja-jp-default-utf16.reg' -Encoding unicode
Get-Content 'C:\images\ja-jp-welcome.reg' | Set-Content 'C:\images\ja-jp-welcome-utf16.reg' -Encoding unicode

reg load $DefaultHKEY $DefaultRegPath
reg import "C:\images\ja-jp-default-utf16.reg"
reg unload $DefaultHKEY
reg import "C:\images\ja-jp-welcome-utf16.reg"