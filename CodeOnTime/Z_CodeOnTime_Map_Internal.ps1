#Requires -Version 4.0
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Mapea la ruta de proyectos a un folder dentro del Branch. Code OnTime solo permite apuntar a un folder a la vez. Luego, habría que alternar trabajar entre un "branch" y otro.

.DESCRIPTION
  Mapea la ruta de proyectos, que generalmente está en "Mis Documentos" para el usuario actual, y lo pasa un folder dentro del Branch especificado. 

  Más información:
  http://blog.codeontime.com/2010/06/using-my-own-folder-for-code-on-time.html

.PARAMETER Branch
  Nombre del branch en TFS a donde se desea apuntar Code OnTime

.NOTES
  Version:        1.0
  Author:         Zeus Tecnología
  Creation Date:  2015-04-03
  Purpose/Change: Mapear Ruta Mis Documentos de Code OnTime
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Stop on Error
$global:ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$global:ScriptVersion = "1.0"


$global:DnnAlias = "dev.dnndev.me";



#-----------------------------------------------------------[Functions]------------------------------------------------------------

# Dot Source required Function Libraries

<#
.SYNOPSYS
  instala Administrador de Paquetes de Windows y Actualiza Powershell a v 4.0
#>
Function Install-Prerrequisites {
	if (-not (Get-Command choco -CommandType Application -ErrorAction SilentlyContinue)) {
		Write-Host "Instalando Administrador de Paquetes de Windows..."
		iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
		$env:Path += ";%ALLUSERSPROFILE%\chocolatey\bin";
		Set-Alias choco %ALLUSERSPROFILE%\chocolatey\bin\choco.exe
	}

	if ($PSVersionTable.PSVersion.Major -lt 4) {
		Write-Host "Instalando Update para Powershell..."
		choco install powershell
		Write-Warning "REINICIE EL COMPUTADOR ANTES DE CONTINUAR";
		Exit 2;
	}
}


<#
.SYNOPSIS
  Mapea la ruta de proyectos a un folder dentro del Branch. 
  Code OnTime solo permite apuntar a un folder a la vez. 
  Luego, habría que alternar trabajar entre un "branch" y otro.
#>
Function Map-CodeOnTimeMyDocumentsToBranch {
	# C:\TFS\Zeus\1_Main\Web (él automáticamente agrega un subfolder "Code OnTime"
	$tfsCodeOnTimeMyDocuments = $PSScriptRoot
	if (-not (Test-Path $tfsCodeOnTimeMyDocuments)) {
		throw "No se encuentra la ruta del Branch: '$tfsCodeOnTimeMyDocuments'";
	}

	$CodeOnTimeInstallDir = "$(dir 'Env:\ProgramFiles(x86)' | select -ExpandProperty value)\Code OnTime LLC\Code OnTime Generator"
	if (-not (Test-Path $CodeOnTimeInstallDir)) {
		throw "No se detecta instalado Code OnTime. Normalmente se instala en la ruta '$CodeOnTimeInstallDir'";
	}
	$CodeOnTimeIniPath = Join-Path $CodeOnTimeInstallDir "CodeOnTime.exe.config"
	if (Test-Path $CodeOnTimeIniPath) {
		Remove-Item $CodeOnTimeIniPath -Force
	}

	$xmlCodeOnTimeIni = @"
<?xml version="1.0" encoding="utf-8" ?>
<configuration>
	<configSections>
		<sectionGroup name="userSettings" type="System.Configuration.UserSettingsGroup, System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" >
			<section name="CodeOnTime.Properties.Settings" type="System.Configuration.ClientSettingsSection, System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" allowExeDefinition="MachineToLocalUser" requirePermission="false" />
		</sectionGroup>
		<sectionGroup name="applicationSettings" type="System.Configuration.ApplicationSettingsGroup, System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" >
			<section name="CodeOnTime.Properties.Settings" type="System.Configuration.ClientSettingsSection, System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" requirePermission="false" />
		</sectionGroup>
	</configSections>
	<applicationSettings>
		<CodeOnTime.Properties.Settings>
			<setting name="MyDocuments" serializeAs="String">
				<value>$tfsCodeOnTimeMyDocuments</value>
			</setting>
		</CodeOnTime.Properties.Settings>
	</applicationSettings>
</configuration>
"@

	Write-Verbose "Remapeando Code OnTime para usar '$tfsCodeOnTimeMyDocuments' como ruta de proyectos"
	Set-Content -Path $CodeOnTimeIniPath -Value $xmlCodeOnTimeIni -Encoding UTF8
}

#-----------------------------------------------------------[Loading]------------------------------------------------------------
Clear-Host
#-----------------------------------------------------------[Execution]------------------------------------------------------------

# mapear C:\Users\<username>\Documents\Code OnTime\*' to C:\TFS\Zeus\<branch>\Code OnTime'
Map-CodeOnTimeMyDocumentsToBranch