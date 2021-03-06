#requires -RunAsAdministrator
<#
.SYNOPSIS
	Resyncs windows time with external time server
#>
$ErrorActionPreference = "Stop"

$timeSvc = "W32Time"
if ((Get-Service $timeSvc -ErrorAction Ignore).Status -ne "Running") {
	"Starting Service '$timeSvc'"
	Start-Service $timeSvc
}
"Resync-ing time"
W32tm /resync /force
"Done"
