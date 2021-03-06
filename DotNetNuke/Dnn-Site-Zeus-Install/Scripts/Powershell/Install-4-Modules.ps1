##requires -version 4
<#
.SYNOPSIS
 	Instala módulos/paquetes extra especificados en [Path]
#>
Param(
	[Parameter(Mandatory=$true)][string[]]$Path,
	[Parameter(Mandatory=$true)][string]$DnnRootUrl,
	[Parameter(Mandatory=$true)][string]$DnnRootFolder,
	[Switch]$WaitToReload = $false
)
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initializations]------------------------------------------------------
 
$ErrorActionPreference = "Stop" # Set Error Action to Stop
$Script:ScriptVersion = "1.0"   # Script Version

#-----------------------------------------------------------[Include]------------------------------------------------------------
if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # powershell 2.0

.  "$PSScriptRoot\Lib-General.ps1"
.  "$PSScriptRoot\Lib-Web.ps1"
.  "$PSScriptRoot\Lib-IIS.ps1"
.  "$PSScriptRoot\Lib-Dnn.ps1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Stopwatch

InstallModules-DnnSite -Path $Path -RootUrl $DnnRootUrl -RootFolder $DnnRootFolder -WaitToReload:$WaitToReload

Stop-Stopwatch
