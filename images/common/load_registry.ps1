$DefaultHKEY = "HKU\DEFAULT_USER"
$DefaultRegPath = "C:\Users\Default\NTUSER.DAT"

reg load $DefaultHKEY $DefaultRegPath
reg import "C:\images\ja-jp-default.reg"
reg unload $DefaultHKEY
reg import "C:\images\ja-jp-welcome.reg"