#Requires -Version 4.0
<#
.SYNOPSIS
  Borra del TFS archivos temporales usados al compilar los proyectos de Fox en Windows
#>
$ErrorActionPreference = "Stop"

#----------------------------------------------------------[Declarations]----------------------------------------------------------
$Script:MainScriptRoot = &{ if ($PSScriptRoot) { $PSScriptRoot } else { (Resolve-Path .).Path } };
$Script:MainScriptName = &{ if ($MyInvocation.MyCommand.Name) { $MyInvocation.MyCommand.Name } else { "TfsPowershellConsole.ps1" } };
$Script:MainScriptName = [IO.Path]::GetFileNameWithoutExtension($Script:MainScriptName)

#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

# Function Libraries

# $/Comun/TFS/Libs
# C:\TFS\Zeus\Comun\TFS\Tools\Migration\TfsPowershellConsole.ps1
. "$Script:MainScriptRoot\..\..\Libs\TfsFunctions.ps1"

#-----------------------------------------------------------[Setup]------------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#dir "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\*.Test" -Directory | % { "TfsRename `"{0}`" `"`{1}{2}`" " -f $_.FullName, '$/Comun/ConectoresHardware/Dev/Plugins/',$_.Name.Replace("ImpresoraFiscal.", "ImpresoraFiscal/") } 
#exit

#TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\EpsonTMU220B.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/EpsonTMU220B.Test" 
#exit
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.BematechMP2100.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/BematechMP2100.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.Epson.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/Epson.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.EpsonLX300.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/EpsonLX300.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.EpsonTM200.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/EpsonTM200.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.EpsonTMH6000.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/EpsonTMH6000.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.Hasar.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/Hasar.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.Hasar_SMHPL23F.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/Hasar_SMHPL23F.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.OKIML1120.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/OKIML1120.Test" 
TfsRename "C:\TFS\Zeus\Comun\ConectoresHardware\Dev\ImpresoraFiscal.Tally1125.Test" "$/Comun/ConectoresHardware/Dev/Plugins/ImpresoraFiscal/Tally1125.Test" 


#-----------------------------------------------------------[Finish]------------------------------------------------------------
Write-Host "Completado!" -ForegroundColor Red
