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
	[string[]]$Exclude = $null,
	[switch]$Recurse = $true
	)
	
	$root = (Get-Location).Path
	
	foreach ($item in $Path) {
		if (Test-Path $item -PathType Container) {
			Write-Host "    $($item.Replace($rootFolder, ''))"
			Get-ChildItem -Path $item -Include $Include -Recurse:$Recurse | 
			% {
				$file = $_.FullName.Replace("$root\", "")
				$isExcluded = $false
				foreach ($excludeItem in $Exclude) {
					if ($file -match $excludeItem) { 
						$isExcluded = $true; 
						break; 
					}
				}
				if (-not $isExcluded) {
					Write-Host "        $($_.FullName.Replace($rootFolder, ''))"
					Remove-Item $_.FullName -Force -Recurse:$Recurse
				}
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
$rootFolder = "$PSScriptRoot\testdnnclubes"
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
			"_Mappings*",
			# files
			"packages.config", "web.config",
			"_TestFastReport.ascx", "_TestInforme.frx",
			# subfolders
			".nuget", "bin", "obj", "BuildScripts", "App_Base", "App_Core", 
			"install", "ResourcesZip", "Resources.Zip", "Package", "packages", "Properties", "TestResults", "Service References" `
		-Exclude "ZeusRecursos\*"

Delete-FolderContents "bin" `
	-Include "*.xml", 
		# pdb for DNN
		"ClientDependency.Core.pdb", "CountryListBox.pdb", "DotNetNuke*.pdb", "Lucene*.pdb",  "WillStrohl*.pdb",
		#
		"Zeus.Back*"
		# ADVERTENCIA: borrar lo de hoteles (futuro)
		#"Zeus.Front.Hoteles*"

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
	"bin\Dummy.NoCopiar*", 
	"bin\ZeusRecursos.dnn",
	"Portals\_default\*_test.template",
	"DesktopModules\ZeusInteligEmp\ZeusInteligEmpCore_01.00.00_Install.zip",
	#security bug on DNN 7.3.4
	# Hay un bug conocido en la versión 7.3.4 que un attacker podria reiniciar la contraseña del host e ingresar al sitio como admin.
	# Para mitigar esta situacion mientras se actualiza, es necesario borrar los siguientes archivos:
	"Install\install.*",
	"Install\InstallWizard.*",
	"Install\UpgradeWizard.*",
	"Install\WizardUser.*"

Delete-FolderContents -Path "DesktopModules\ZeusRecursos\Upload" `
	-Exclude "\\Gadgets\b"

Delete-Folder `
	"App_Data",
	"controls\Config\Backup*",
	"Install\Temp", 
	"DesktopModules\DnnModulesClubes",
	"DesktopModules\DnnModulesHoteles",
	"DesktopModules\ZeusInteligEmp\Addons\Hoteles",
	"DesktopModules\ZeusInteligEmp\Addons\PosAdmin",
	"DesktopModules\ZeusPosAdmin",
	"DesktopModules\ZeusPosTouch",
	"DesktopModules\ZeusHoteles",
	"DesktopModules\ZeusHotelesControlesUsuario",
	"DesktopModules\ZeusTecnologia.ZWDomicilios",
	"DesktopModules\ZeusTecnologia.ZWHoteles",
	"DesktopModules\ZeusTecnologia.ZWPOS",
	"DesktopModules\ZeusRecursos\xbap",
	"Portals\_default\Logs",
	"ZeusFingerprint"

Delete-EmptyFolders $rootFolder

# create empty folders
"Creando Directorios Vacios Requeridos:"
New-Folder `
	"Install\Temp",
	"DesktopModules\ZeusRecursos\Upload\EnvioDeCorreo"

"Replacing favicon.ico with Zeus Logo..."
Copy-Item "C:\TFS\Zeus\3_Stage\Comun\Instaladores\Web\LogoZeus.ico" "favicon.ico" -Force

Write-Host "Completado!" -ForegroundColor Blue


