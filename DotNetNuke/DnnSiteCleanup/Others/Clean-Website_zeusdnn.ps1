#requires -version 4
<#
.SYNOPSIS
  Realiza una limpieza sobre el sitio web de hoteles antes de pasar a publicación
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop on first error caught
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#region Functions
#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Delete-File {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path
	)
	"Borrando Archivos..."
	foreach ($item in $Path) {
		if (Test-Path $item) {
			Write-Host "    $($item.Replace($rootFolder, ''))"
			Remove-Item -Path $item -Force
		} 
		else {
			Write-Host "    $($item.Replace($rootFolder, ''))" -ForegroundColor Red
		}
	}
}


Function Delete-Folder {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path,
	[switch]$Recurse = $true
	)
	"Borrando Carpetas (Recursivo)..."
	foreach ($item in $Path) {
		if (Test-Path $item -PathType Container) {
			Write-Host "    $($item.Replace($rootFolder, ''))"
			Remove-Item -Path $item -Force -Recurse:$Recurse
		}
		else {
			Write-Host "    $($item.Replace($rootFolder, ''))" -ForegroundColor Red
		}
	}
}

Function Delete-FolderContents {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path,
	[string[]]$Include = "*",
	[switch]$Recurse = $true
	)
	
	foreach ($item in $Path) {
		if (Test-Path $item -PathType Container) {
			Write-Host "    $($item.Replace($rootFolder, ''))"
			Get-ChildItem -Path $item -Include $Include -Recurse:$Recurse | 
			% {
				Write-Host "        $($_.FullName.Replace($rootFolder, ''))"
				Remove-Item $_.FullName -Force -Recurse:$Recurse
			}
		}
		else {
			Write-Host "    $($item.Replace($rootFolder, ''))" -ForegroundColor Red
		}
	}
}

Function Delete-EmptyFolders {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path,
	[switch]$Recurse = $true
	)

	"Borrando Directorios Vacios:"
	Get-ChildItem -Path $SearchRoot -Directory -Recurse | 
		? { (Get-ChildItem -Path $_.FullName -Recurse -File) -eq $null } | 
	% {
		Write-Host "    $($_.FullName.Replace($rootFolder, ''))"
		Remove-Item $_.FullName -Force -Recurse
	}
}

Function New-Folder {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path
	)

	$Path |
	% {
		if (!(Test-Path $_ -PathType Container)) {
			Write-Host "    $($_.Replace($rootFolder, ''))"
			New-Item $_ -ItemType Directory -Force | Out-Null
		}
		else {
			Write-Host "    $($_.Replace($rootFolder, ''))" -ForegroundColor Red
		}
	}
}
#endregion

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
$rootFolder = "$PSScriptRoot\zeusdnn"
If (!(Test-Path $rootFolder -PathType Container)) { throw "Cannot find folder '$rootFolder'" }
Set-Location $rootFolder

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Host $rootFolder
"Borrando Contenido de las Carpetas:"
Delete-FolderContents "DesktopModules\*Zeus*", "DesktopModules\Deployer" `
		-Include `
			"*.csproj", "*.csproj.user", "*.csproj.vspscc", "*.Publish.xml", "*.sln", "*.vssscc", 
			"*.Debug.config", "*.Release.config", "*.CodeAnalysisLog.xml", "*.lastcodeanalysissucceeded", 
			"*.testsettings", "*.vsmdi", "*.bat", "*.cd", "*.cs",
			# files
			"packages.config", "web.config",
			# subfolders
			".nuget", "bin", "obj", "BuildScripts", "App_Base", "App_Core", 
			"install", "ResourcesZip", "Resources.Zip", "Package", "packages", "Properties", "TestResults", "Service References"
Delete-FolderContents "bin" `
	-Include "*.xml", 
		# pdb for DNN
		"ClientDependency.Core.pdb", "CountryListBox.pdb", "DotNetNuke*.pdb", "Lucene*.pdb",  "WillStrohl*.pdb",
		#
		"Zeus.Back*", 
		# ADVERTENCIA: todavia hay dependencia en Zeus.Front.Clubes.Logica.dll
		"Zeus.Front.Clubes.Interfaz*"

Delete-FolderContents -Include "AjaxControlToolkit.resources.dll" `
	-Path "bin\zh-CHT", 
		"bin\ar", 
		"bin\cs", 
		"bin\de", 
		"bin\fr", 
		"bin\he", 
		"bin\hi", 
		"bin\it", 
		"bin\ja", 
		"bin\ko", 
		"bin\nl", 
		"bin\pt", 
		"bin\ru", 
		"bin\tr-TR", 
		"bin\zh-CHS"

Delete-File `
	"bin\Dummy.NoCopiar.Zeus.Arquitectura.pdb", 
	"bin\Dummy.NoCopiar.Zeus.Arquitectura.dll",
	"bin\ZeusRecursos.dnn",
	"DesktopModules\ZeusInteligEmp\ZeusInteligEmpCore_01.00.00_Install.zip",
	#security bug on DNN 7.3.4
	# Hay un bug conocido en la versión 7.3.4 que un attacker podria reiniciar la contraseña del host e ingresar al sitio como admin.
	# Para mitigar esta situacion mientras se actualiza, es necesario borrar los siguientes archivos:
	"Install\install.*",
	"Install\InstallWizard.*",
	"Install\UpgradeWizard.*",
	"Install\WizardUser.*"


Delete-Folder `
	"App_Data",
	"controls\Config\Backup*",
	"Install\Temp", 
	"DesktopModules\DnnModulesClubes",
	"DesktopModules\DnnModulesHoteles",
	"DesktopModules\ZeusClubes",
	"DesktopModules\ZeusHoteles\Recursos\Upload",
	"DesktopModules\ZeusInteligEmp\Addons\Clubes",
	"DesktopModules\ZeusInteligEmp\Addons\ControlEspacio",
	"DesktopModules\ZeusInteligEmp\Addons\PosAdmin",
	"DesktopModules\ZeusPosAdmin",
	"DesktopModules\ZeusPosTouch",
	"DesktopModules\ZeusRecursos\Upload",
	"DesktopModules\ZeusRecursos\xbap",
	"Portals\_default\Containers\ZeusClubesSkin",
	"Portals\_default\Logs",
	"Portals\_default\Skins\ZeusClubesSkin",
	"ZeusFingerprint"

Delete-EmptyFolders $rootFolder

# create empty folders
"Creando Directorios Vacios Requeridos:"
New-Folder `
	"Install\Temp",
	"DesktopModules\ZeusRecursos\Upload",
	"DesktopModules\ZeusHoteles\Recursos\Upload\ConfirmacionesReservas", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\DatosFacturacion", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\Facturas", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\ImagenesPlano", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\imgHabitacionesPorAtributo", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\Precuentas",
	"DesktopModules\ZeusRecursos\Upload\EnvioDeCorreo",
    "DesktopModules\ZeusRecursos\Upload\Gadgets"


Write-Host "Completado!" -ForegroundColor Blue
