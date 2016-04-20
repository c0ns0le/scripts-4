#requires -version 4
<#
.SYNOPSIS
  Corrige la codificación de los archivos SQL de base de datos. 
  Se asegura que todos los archivos tengan codificación ANSI y no UTF8 o Unicode
#>
Param(
	#[Parameter(Mandatory=$true)]
	[string]$Path = "C:\TFS\Zeus\1_Main\BaseDatos", 
	[switch]$Recurse = $true
)
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

. "$PSScriptRoot\..\..\Libs\TfsFunctions.ps1"
. "$PSScriptRoot\..\..\Libs\FileEncodingFunctions.ps1"


#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------

<# Checkout Error Documented
# in case of checkout error, run the following command
# tf workspaces /collection:http://ztfs:8080/tfs/Zeus
#>
$BeforeScriptDoCheckout = {Param([string]$fullFilePath) TfsCheckout $fullFilePath }

# list files with encoding problems
#Check-FileEncoding $Path

# fix encoding problems
Fix-FileEncoding $Path $BeforeScriptDoCheckout

<# for debugging
$files = @(New-Object PSObject -Property @{FullName="C:\TFS\Zeus\1_Main\BaseDatos\Hoteles\Core\1_Estructura\Tablas\dbo.AcompaEventos.sql"; Encoding="UTF8"})
foreach ($file in $files)
{
	...
}
#>
