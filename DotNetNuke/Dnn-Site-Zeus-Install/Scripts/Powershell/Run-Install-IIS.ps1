##requires -version 4
<#
.SYNOPSIS
  Install IIS
#>

#---------------------------------------------------------[Include]--------------------------------------------------------
 
$ErrorActionPreference = "Stop" # Set Error Action to Stop
$Script:ScriptVersion = "1.0"   # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

.  "$PSScriptRoot\Lib-General.ps1"

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------

Install_IIS-WinComponents
