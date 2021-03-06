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
	foreach ($pathItem in $Path) {
		if (Test-Path $pathItem) {
			$items = Get-ChildItem $pathItem -File | Select -ExpandProperty FullName
			
			foreach ($item in $items) {
				Write-Host ("    {0}" -f $item.Replace("$rootFolder\", ''))
				Remove-Item -Path $item -Force
			}
		} 
		else {
			Write-Host ("    {0}" -f $pathItem.Replace("$rootFolder\", '')) -ForegroundColor Red
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
			Write-Host ("    {0}" -f $item.Replace("$rootFolder\", ''))
			Remove-Item -Path $item -Force -Recurse:$Recurse
		}
		else {
			Write-Host ("    {0}" -f $item.Replace("$rootFolder\", '')) -ForegroundColor Red
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
		try {
			if (Test-Path $item -PathType Container) {
				Write-Host ("    {0}" -f $item.Replace("$rootFolder\", ''))
				if (-not $Recurse) {
					if ($item.EndsWith("\*")) { }
					elseif ($item.EndsWith("*")) { }
					elseif ($item.EndsWith("\")) { $item += "*" }
					else { $item += "\*" }
				}
				Get-ChildItem -Path $item -Include $Include -Recurse:$Recurse -File:(-not $Recurse) | 
				% {
					Write-Host ("    {0}" -f $_.FullName.Replace("$rootFolder\", ''))
					Remove-Item $_.FullName -Force -Recurse:$Recurse
				}
			}
			else {
				Write-Host ("    {0}" -f $item.Replace("$rootFolder\", '')) -ForegroundColor Red
			}
		}
		catch {
			Write-Host ("    {0}" -f $item.Replace("$rootFolder\", '')) -ForegroundColor Red
			Write-Host ("        ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Magenta
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
$rootFolder = "C:\inetpub\acuacar.dnndev.me"
If (!(Test-Path $rootFolder -PathType Container)) { throw "Cannot find folder '$rootFolder'" }
Set-Location $rootFolder

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Host $rootFolder
Delete-File `
	"InputTrace.webinfo", "OutputTrace.webinfo",
	"Pago_Log.txt",
	"Resources.zip.manifest",
	"DesktopModules\DesktopModules.7z",
	"DesktopModules\DesktopModulesPagos.7z",
	"DesktopModules\FormularioGenerico2.7z"

"Borrando Contenido de las Carpetas:"
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

Delete-FolderContents -Include "*.7z" -Path "bin"

Delete-FolderContents -Include "Acuacar_Export.*" -Path "Portals\_default"

Delete-FolderContents -Path "DesktopModules\ReportGenerator\Pages\images", "Install\Temp", "Portals\_default\Logs", "Recursos", "tmp"

Delete-Folder `
	"App_Data",
	"Portals\0\menu - copia1", 
	"Portals\0\NewFolder",
	"aspnet_client",
	"Install\Temp", 
	"Log"

#Delete-EmptyFolders $rootFolder

# create empty folders
"Creando Directorios Vacios Requeridos:"
New-Folder `
	"Install\Temp",
	"Portals\_default\Logs"


#-----------------------------------------------------------[BEGIN: Photos]------------------------------------------------------------

"Deleting Photos (Not needed for troubleshooting)"

Delete-FolderContents -Recurse:$false `
			-Path "Portals\0", 
			"Portals\0\Acuacar", 
			"Portals\4"

Delete-FolderContents `
			-Path "Portals\0\DNNGo_PhotoAlbums\1043",
			"Portals\0\Images",
			"Portals\0\xBlog\Export",
			"Portals\0\xBlog\uploads",
			"Portals\4\DNNGo_PhotoAlbums\1949",
			"Portals\4\DNNGo_PhotoAlbums\1951",
			"Portals\4\DNNGo_PhotoAlbums\2033",
			"Portals\4\xBlog\uploads"

Delete-Folder "LicitacionALC-OC-05-AECID-2014", `
			"Portals\0\LicitacionALC-OC-05-AECID-2014",
			"Portals\0\Skins\30467_0_UnZip_DNNGo_10432_Business131+Slider+xBlog+PhotoAlbums+PSD"

#-----------------------------------------------------------[END: Photos]------------------------------------------------------------


Write-Host "Completado!" -ForegroundColor Blue
