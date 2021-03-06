##requires -version 4
<#
.SYNOPSIS
 	Dado un sitio web configurado con DNN descomprimido, Invoca el Wizard de instalación de DNN 
	y completa el proceso de instalación y configuración de DNN, 
	junto con módulos/paquetes extra especificados (Paso Opcional)
#>
Param(
	[Parameter(Mandatory=$true)][string]$DnnRootUrl,
	[Parameter(Mandatory=$true)][string]$DnnUsername,
	[Parameter(Mandatory=$true)][string]$DnnPassword,
	[Parameter(Mandatory=$true)][string]$DnnEmail,
	[Parameter(Mandatory=$true)][string]$DnnDatabaseServerName,
	[Parameter(Mandatory=$true)][string]$DnnDatabaseName,
	[string]$DnnDatabaseObjectQualifier = "dnn",
	[string]$DnnDatabaseUsername,
	[string]$DnnDatabasePassword,
	[string]$DnnWebsiteTitle = "My Blank Website",
	[string]$DnnTemplate = "Blank Website.template",
	[string]$DnnLanguage = "es-ES"
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

InstallWizard-DnnSite -RootUrl $DnnRootUrl `
    -DnnUsername $DnnUsername `
    -DnnPassword $DnnPassword `
    -DnnEmail $DnnEmail `
    -DnnDatabaseServerName $DnnDatabaseServerName `
    -DnnDatabaseName $DnnDatabaseName `
    -DnnDatabaseObjectQualifier $DnnDatabaseObjectQualifier `
    -DnnDatabaseUsername $DnnDatabaseUsername `
    -DnnDatabasePassword $DnnDatabasePassword `
    -DnnWebsiteTitle $DnnWebsiteTitle `
    -DnnTemplate $DnnTemplate `
    -DnnLanguage $DnnLanguage

Stop-Stopwatch
