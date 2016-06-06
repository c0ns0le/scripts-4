##requires -version 4
<#
.SYNOPSIS
  Install IIS
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initializations]------------------------------------------------------
 
$ErrorActionPreference = "Stop" # Set Error Action to Stop
$Script:ScriptVersion = "1.0"   # Script Version

#-----------------------------------------------------------[Include]------------------------------------------------------------

.  "$PSScriptRoot\Lib-General.ps1"
.  "$PSScriptRoot\Lib-IIS.ps1"
.  "$PSScriptRoot\Lib-Dnn.ps1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init-DnnSite() {
	Clear-Host
	Set-Location $PSScriptRoot
	[Environment]::CurrentDirectory = $PSScriptRoot

	Reset-Indented
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Init-DnnSite

Start-StopWatch

Create-DnnSite $Script:appSettings.Source $Script:appSettings.Target $Script:appSettings.Web.AppPool $Script:appSettings.Web.Site
InstallWizard-DnnSite $Script:appSettings.Dnn.Root.Url $Script:appSettings.Dnn

Stop-StopWatch
