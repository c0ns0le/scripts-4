##requires -version 4
<#
.SYNOPSIS
  Instala IIS desde los Componentes de Windows

.EXAMPLE
	Invoca script desde el simbolo del sistema

SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File
%PS% "%USERPROFILE%\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\Scripts\Powershell\Install-1-IIS.ps1"
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Include]--------------------------------------------------------

$ErrorActionPreference = "Stop" # Set Error Action to Stop
$Script:ScriptVersion = "1.0"   # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------
if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # powershell 2.0

.  "$PSScriptRoot\Lib-General.ps1"

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------

Disable-InternetExplorerESC
Install_IIS-WinComponents
