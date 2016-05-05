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
Delete-FolderContents "bin" `
	-Include "Zeus*"

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
	#security bug on DNN 7.3.4
	# Hay un bug conocido en la versión 7.3.4 que un attacker podria reiniciar la contraseña del host e ingresar al sitio como admin.
	# Para mitigar esta situacion mientras se actualiza, es necesario borrar los siguientes archivos:
	"Install\install.*",
	"Install\InstallWizard.*",
	"Install\UpgradeWizard.*",
	"Install\WizardUser.*",
	#
	"\Portals\_default\admin.template",
	"Portals\_default\zeusdnn.template",
	"Portals\_default\zeusdnnrepo.template"

Delete-Folder `
	"App_Data",
	"controls\Config\Backup*",
	"Install\Temp", 
	"DesktopModules\DnnModules*",
	"DesktopModules\AuthenticationServices\Zeus*",
	"DesktopModules\Zeus*",
	"DesktopModules\SimpleRedirect*",
	"Portals\_default\Containers\Zeus*",
	"Portals\_default\Logs",
	"Portals\_default\Skins\Zeus*",
	"ZeusFingerprint"

Delete-EmptyFolders $rootFolder

# create empty folders
"Creando Directorios Vacios Requeridos:"
New-Folder `
	"Install\Temp"

Write-Host "Completado!" -ForegroundColor Blue
