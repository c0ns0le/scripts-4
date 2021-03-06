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
	Set-Alias QueueWriterConsole -Value "C:\Users\PEscobar\Documents\GitHub\scripts\Azure\StoragePerformance\QueueWriterConsole\bin\Debug\QueueWriterConsole.exe" -Scope "Script"
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
Init

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$messageCount = 10
"Queueing $messageCount messages..."
QueueWriterConsole $messageCount
"Done"
