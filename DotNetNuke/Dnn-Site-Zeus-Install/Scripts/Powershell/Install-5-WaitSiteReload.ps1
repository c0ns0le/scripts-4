##requires -version 4
<#
.SYNOPSIS
 	Abre la pagina de Inicio y espera que el sitio cargue.
.DESCRIPTION
	Usado especialmente después de instalar varios módulos con el propósito de:
		* Cargar DLLs del sitio
		* Ejecutar post-tareas de instalación
#>
Param(
	[Parameter(Mandatory=$true)][string]$DnnRootUrl
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

Wait-DnnSite -RootUrl $DnnRootUrl

Stop-Stopwatch
