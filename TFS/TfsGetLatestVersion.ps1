#Requires -Version 4.0
<#
.SYNOPSIS
  Borra del TFS archivos temporales usados al compilar los proyectos de Fox en Windows
#>
Set-StrictMode -Version Latest
#----------------------------------------------------------[Declarations]----------------------------------------------------------

$ErrorActionPreference = "Stop"
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

# Function Libraries

. "$PSScriptRoot\TFS-Functions.ps1"
	
#-----------------------------------------------------------[Setup]------------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------
$rootParent = "C:\TFS1"

$subfolders = Get-ChildItem $rootParent -Directory | Select -ExpandProperty FullName
foreach ($subfolder in $subfolders) {
	Write-Host "[$subfolder]"
	TfsGet $subfolder #-ExtraParams "/latest"
}

#-----------------------------------------------------------[Finish]------------------------------------------------------------
Write-Host "Completado!" -ForegroundColor Red
