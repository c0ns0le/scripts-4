#requires -version 4
<#
.SYNOPSIS
  Enter description here
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------



Function Create-SymbolicLink($source, $target) {
	$linkName = Split-Path $target -Leaf
	$targetParent = Split-Path $target -Parent
	
	Try {
		Push-Location $targetParent

		if (Test-Path $linkName) {
			# el comando 'rd' remueve links simbólicos sin borrar los archivos de la ruta original
			# NOTA: se debe user el comando 'rd' del símbolo del sistema y no el alias 'rd' de Powershell
			cmd /c RD $linkName

			If (-not $?) {
				throw "No se pudo crear vínculo simbólico $linkName. Es posible que exista un folder físicamente ubicado en esa ruta con el mismo nombre. Por favor verifique y borre el folder manualmente para poder continuar."
			}
		}

		# Ejemplo: vínculo simbólico creado para Descargas <<===>> C:\inetpub\zeusdnn\dev\DesktopModules\ConectorHardware\Descargas
		cmd /c MKLINK /D $linkName $source
	}
	Finally {
		Pop-Location;
	}
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Create-SymbolicLink "C:\inetpub\zeusdnn\dev\DesktopModules\ConectorHardware\Descargas" `
					"C:\TFS\Zeus\Comun\Portales\Dev\ConectoresHardware\ConectoresHardware\Descargas"
