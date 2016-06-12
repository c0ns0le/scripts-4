#requires -Version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Enter description here
.EXAMPLE
 Enter example here
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init {
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
Init

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows Nt\CurrentVersion\Time Zones" | ? { $_.GetValue("Display")  -like '*UTC-05*' } | 
	%{
"# {1}
WEBSITE_TIME_ZONE: '{0}'
" -f $_.PSChildName, $_.GetValue("Display")
	}

