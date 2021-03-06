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
$Script:ScriptVersion = "14.1.SP12"

#region Functions
#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Translate([string]$text, [string]$from, [string]$to) {
<#
.SYNOPSIS
	Port of Translate() PL/SQL function
.EXAMPLE
	Translate "lós pájaros cantán canción de úrsula" "áéíóú" "aeiou"
.CODE
public static string Translate(string text, string from, string to)
{
    StringBuilder sb = new StringBuilder();
    foreach (char ch in text)
    {
        int i = from.IndexOf(ch);
        if (from.IndexOf(ch) < 0) { sb.Append(ch); }
        else { if (i >= 0 && i < to.Length) { sb.Append(to[i]); } }
    }
    return sb.ToString();
}
#>
	$sb = New-Object -TypeName "System.Text.StringBuilder"
	foreach ($ch in $text.ToCharArray()) {
		$i = $from.IndexOf($ch)
		if ($from.IndexOf($ch) -lt 0) { $sb.Append($ch) | Out-Null } 
		elseif (($i -ge 0) -and ($i -lt $to.Length)) { $sb.Append($to[$i]) | Out-Null }
	}
	$sb.ToString()
}


Function Delete-File {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path
	)
	"Borrando Archivos..."
	foreach ($item in $Path) {
		if (Test-Path $item) {
			Write-Host "    $($item.Replace($Script:RootFolderWebSite, ''))"
			Remove-Item -Path $item -Force
		} 
		else {
			Write-Host "    $($item.Replace($Script:RootFolderWebSite, ''))" -ForegroundColor Red
		}
	}
}

Function Delete-Folder {
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path,
	[switch]$Recurse = $true
	)
	"Borrando Carpetas Específicas Enteras..."
	foreach ($item in $Path) {
		if (Test-Path $item -PathType Container) {
			Write-Host "    $($item.Replace($Script:RootFolderWebSite, ''))"
			Remove-Item -Path $item -Force -Recurse:$Recurse -ErrorAction Continue
		}
		else {
			Write-Host "    $($item.Replace($Script:RootFolderWebSite, ''))" -ForegroundColor Red
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
			Write-Host "    $($item.Replace($Script:RootFolderWebSite, ''))"
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
					Write-Host "        $($_.FullName.Replace($Script:RootFolderWebSite, ''))"
					Remove-Item $_.FullName -Force -Recurse:$Recurse
				}
			}
		}
		else {
			Write-Host "    $($item.Replace($Script:RootFolderWebSite, ''))" -ForegroundColor Red
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
	Get-ChildItem -Path $Path -Directory -Recurse | 
		? { (Get-ChildItem -Path $_.FullName -Recurse -File) -eq $null } | 
	% {
		Write-Host "    $($_.FullName.Replace($Script:RootFolderWebSite, ''))"
		Remove-Item $_.FullName -Force -Recurse
	}
}

Function Get-RegexForWeirdFileNames {
<#
.SYNOPSIS
	Obtiene regex para obtener nombres de archivos con caracteres extraños que hacen que la generacion de paquetes de DNN tenga errores
	y quedaron de compilaciones inválidas anteriormente
#>
Param(
	[string]$ExceptionList
	)

	$lastValidChar = "}"
	$firstInvalid = [int][char]$lastValidChar + 1
	
	# build pattern list of invalid char
	$pattern = ("[\u00{0:X}" -f $firstInvalid)
	if ($ExceptionList) {
		<#  Original Regex
			the following code did NOT work:       
				$_.FullName -match "[\u007E-\u9999]"
			
			it was replaced by using Regex object as shown on final code below.
			
		Regex generated with following code:

			$lastValidChar = "}"
			"{0} [\u00{0:X}-\u9999]" -f ([int]$lastValidChar[0]+1)
					"áéíóúñÁÉÍÓÚÑ".ToCharArray() | % { Write-Host -NoNewLine "[" } { Write-Host -NoNewLine ("\u00{0:X}" -f [int]$_[0]) } { Write-Host "]" }

		OUTPUT: 126 [\u007E-\u9999]
		#>
		$exceptions = $ExceptionList.ToCharArray() | % { [int]$_ } | Sort-Object
		$i = 0
		$exceptions | % { 
			$i++
			if ($i -eq 1) {
				$pattern += ("\u00{0:X}" -f $firstInvalid)
			}
			$pattern += ("-\u00{0:X}\u00{1:X}" -f ($_ - 1), ($_ + 1))
		}
	}
	$pattern += "-\u9999]"
	
	$pattern
}



Function Delete-FilesWithWeirdFileNames {
<#
.SYNOPSIS
	Borra archivos que tienen nombres con caracteres extraños que hacen que la generacion de paquetes de DNN tenga errores
#>
Param(
	[Parameter(Mandatory=$true)]
	[string[]]$Path,
	[switch]$Recurse = $true
	)

	Write-Host "Borrando Archivos con Nombres Invalidos de Compilaciones Viejas:"

	# remove all files with invalid names that were left as part of wrong compilation of DNN packages
	$pattern = [Regex](Get-RegexForWeirdFileNames "áéíóúñÁÉÍÓÚÑ")
	$weirdFiles = Get-ChildItem $Path -Include "*" -Recurse | ? { $pattern.IsMatch($_.FullName) }
	$weirdFiles | 
	% { 
		$item = $_
		$i++
		# write file name with details on invalid char found
		Write-Host "    [$i] $($item.FullName.Replace($Script:RootFolderWebSite, '')) [" -NoNewline
		$pattern.Matches($item.FullName) | % { Write-Host ("'{0}' 0x{1:X4}" -f $_.Value, [int][char]$_.Value) -NoNewline }
		Write-Host "]"
		# delete file/folder
		if (Test-Path $item.FullName) { # in case it is a child item within a parent folder just deleted
			Remove-Item $item.FullName -Force -Recurse
		}
	}

	# delete files with accent vowels (áéíóú) on which there's another corresponding file with same name but without accented vowel
	$pattern = [Regex](Get-RegexForWeirdFileNames "ñÑ")
	$DoubtfulFiles = Get-ChildItem $Path -Include "*" -Recurse | ? { $pattern.IsMatch($_.FullName) }
	$DoubtfulFiles |
	% {
		$item = $_
		$cleanName = Translate $item.FullName "áéíóúüÁÉÍÓÚÜ" "aeiouuAEIOUU"
		
		# if there's another corresponding file with a clean name, delete this one
		# NOTE: There are cases on which file was intentionally left with accent, especially for some images.
		if (Test-Path $cleanName) {
			$i++
			# write file name with details on invalid char found
			Write-Host ("    [{0:000}]   {1} [" -f $i, $item.FullName.Replace($Script:RootFolderWebSite, '')) -NoNewline
			$pattern.Matches($item.FullName) | % { Write-Host ("'{0}' 0x{1:X4}" -f $_.Value, [int][char]$_.Value) -NoNewline }
			Write-Host "]"
			# write correct path found
			Write-Host "     FOUND: $($cleanName.Replace($Script:RootFolderWebSite, ''))" -ForegroundColor Blue
			
			# delete file/folder
			if (Test-Path $item.FullName) { # in case it is a child item within a parent folder just deleted
				Remove-Item $item.FullName -Force -Recurse
			}
		}
		
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
			Write-Host "    $($_.Replace($Script:RootFolderWebSite, ''))"
			New-Item $_ -ItemType Directory -Force | Out-Null
		}
		else {
			Write-Host "    $($_.Replace($Script:RootFolderWebSite, ''))" -ForegroundColor Red
		}
	}
}
#endregion

Function Resolve-RootFolderWebSite_BasedOnThisScriptName {
	# 'C:\...\VersionX\Clean-Website_Setup_zeusdnn.ps1' -replace '.*_Setup_(.+)\.ps1$', '$1'
	$folderWebSiteName = ($MyInvocation.ScriptName -replace '.*_Setup_(.+)\.ps1$', '$1')
	$Script:RootFolderWebSite = "$PSScriptRoot\$folderWebSiteName"
	If (!(Test-Path $Script:RootFolderWebSite -PathType Container)) { throw "Cannot find folder '$Script:RootFolderWebSite'" }
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
#$EnvironmentTarget = "Setup"
$EnvironmentTarget = "Testing"

#Resolve-RootFolderWebSite_BasedOnThisScriptName

#$Script:RootFolderWebSite = "$PSScriptRoot\ligerasdnn"
#$Script:RootFolderWebSite = "$PSScriptRoot\ligerasdnncopy"
#$Script:RootFolderWebSite = "$PSScriptRoot\stagednn"
#$Script:RootFolderWebSite = "$PSScriptRoot\testdnn"
#$Script:RootFolderWebSite = "$PSScriptRoot\zeusdnn"


#-----------------------------------------------------------[Execution]------------------------------------------------------------

Set-Location $Script:RootFolderWebSite
Write-Host $Script:RootFolderWebSite

"Borrando Codigo Fuente..."
Delete-FolderContents "DesktopModules\*Zeus*", "DesktopModules\AuthenticationServices\Zeus", 
					  "DesktopModules\Deployer", "DesktopModules\SimpleRedirect" `
		-Include `
			"*.sln", "*.suo", "*.csproj", "*.vbproj", "*.user", "*.Publish.xml", "*.tmp",
			"*.Debug.config", "*.Release.config", "*.CodeAnalysisLog.xml", "*.lastcodeanalysissucceeded", 
			"*.testsettings", "*.vsmdi", "*.bat", "*.cd", "*.cs", "*.vb",
			"ReleaseNotes.txt", "License.txt",
			"_Mappings*",
			# tfs
			"*.vssscc", "*.vspscc",
			# files
			"packages.config", "web.config",
			"_TestFastReport.ascx", "_TestInforme.frx",
			# subfolders
			".nuget", "bin", "obj", "jar", "BuildScripts", "App_Base", "App_Core",
			"install", "ResourcesZip", "Resources.Zip", "Package", "packages", "Properties", "TestResults", "Service References" `
		#-Exclude "ZeusRecursos\.*"

"Limpiando Carpeta bin..."
Delete-FolderContents "bin" `
	-Include ("*.xml", "*.dnn",
		"*.lastcodeanalysissucceeded", "Resources.zip.manifest",
		"*FrameworkDAL.*", "ZeusTools*",
		# 
		"_Borrar*", "Dummy*",
		# pdb for DNN
		"ClientDependency.Core.pdb", "CountryListBox.pdb", "DotNetNuke*.pdb", "Lucene*.pdb",  "WillStrohl*.pdb",
		# fingerprint digitalpersona
		"DPFP*.dll", "dpHFtrEx.dll", "dpHMatch.dll",
		# griaule
		"GriauleFingerprintLibrary.dll",
		# zeus back
		"Zeus.Back*", 
		# zeus clubes
		"*Clubes*.*",
		# signalR
		# ******** TODO: remover esta linea cuando se integra modulo de Interfaces Externas (Conectores Hardware) pues este modulo instala SignalR
		"*SignalR*"
		)

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
	"Portals\_default\*_test.template",
	"DesktopModules\ZeusInteligEmp\ZeusInteligEmpCore_01.00.00_Install.zip",
	"App_Browsers\*Default.browser*",
	#security bug on DNN 7.3.4
	# Hay un bug conocido en la versión 7.3.4 que un attacker podria reiniciar la contraseña del host e ingresar al sitio como admin.
	# Para mitigar esta situacion mientras se actualiza, es necesario borrar los siguientes archivos:
	"Install\install.*",
	"Install\InstallWizard.*",
	"Install\UpgradeWizard.*",
	"Install\WizardUser.*"

Delete-Folder `
	("App_Data",
	"controls\Config\Backup*",
	"Install\Temp", 
	"DesktopModules\bin",
	"DesktopModules\DnnModulesClubes",
	"DesktopModules\DnnModulesHoteles",
	"DesktopModules\ZeusClubes",
	"DesktopModules\ZeusTecnologia.ZeusClubesHipica",
	"DesktopModules\ZeusTecnologia.ZWClubes",
	"DesktopModules\ZeusInteligEmp\Addons\Clubes",
	"DesktopModules\ZeusInteligEmp\Addons\ControlEspacio",
	# la carpeta postouch no se debe limpiar de ahora en adelante para Front
	#"DesktopModules\ZeusPosTouch",
	"DesktopModules\ZeusRecursos\xbap",
	"Portals\_default\Containers\ZeusClubesSkin",
	"Portals\_default\Logs",
	"Portals\_default\Skins\ZeusClubesSkin",
	"ZeusFingerprint")

Delete-FilesWithWeirdFileNames $Script:RootFolderWebSite

Delete-EmptyFolders $Script:RootFolderWebSite

# create empty folders
"Creando Directorios Vacios Requeridos:"
New-Folder `
	"Install\Temp",
	"DesktopModules\ZeusHoteles\Recursos\Upload\ConfirmacionesReservas", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\DatosFacturacion", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\Facturas", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\ImagenesPlano", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\imgHabitacionesPorAtributo", 
	"DesktopModules\ZeusHoteles\Recursos\Upload\Precuentas",
	"DesktopModules\ZeusRecursos\Upload\EnvioDeCorreo"

# solo aplica para el sitio donde se genera el instalador
if ($EnvironmentTarget -eq "Setup") {
	Delete-FolderContents -Path "DesktopModules\ZeusRecursos\Upload" -Exclude "\\Gadgets\b" # regexp

	Delete-Folder `
		("DesktopModules\ZeusInteligEmp\Addons\PosAdmin",
		"DesktopModules\ZeusPosAdmin",
		"DesktopModules\ZeusHoteles\Recursos\Upload")

	"Replacing favicon.ico with Zeus Logo..."
	$iconFile = "C:\TFS\Zeus\3_Stage\Comun\Instaladores\Web\LogoZeus.ico"
	if (Test-Path $iconFile) {
		Copy-Item $iconFile "favicon.ico" -Force
	}
}


Write-Host "Completado!" -ForegroundColor Blue


