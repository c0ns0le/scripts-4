<#
.SYNOPSIS
  Instalar pre-rrequisitos para instalar la aplicación web 

.EXAMPLE
SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File
%PS% "E:\Setup.Dnn\Scripts\Powershell\Run-Install-Requirements.ps1"
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$ErrorActionPreference = "Stop" # Set Error Action to Stop
$Script:ScriptVersion = "1.0"   # Script Version

#-----------------------------------------------------------[Compatibility]------------------------------------------------------------
if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # PS 2.0 compatibility


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Write-Log($Text) {
	"[{1}] {0}" -f $Text, (Get-Date -Format 'HH:mm:ss')
}

Function GetOSVersion-Enviroment {
  <# Operating System Version
  	# http://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx
		Windows 10	10.0*
		Windows Server 2016 Technical Preview	10.0*
		Windows 8.1	6.3*
		Windows Server 2012 R2	6.3*
		Windows 8	6.2
		Windows Server 2012	6.2
		Windows 7	6.1
		Windows Server 2008 R2	6.1
		Windows Server 2008	6.0
		Windows Vista	6.0
		Windows Server 2003 R2	5.2
		Windows Server 2003	5.2
		Windows XP 64-Bit Edition	5.2
		Windows XP	5.1
		Windows 2000	5.0
	#>
	$osVersion = [Environment]::OSVersion.Version
	return $osVersion
}

Function Install-DotNet451 {
	$packageName = 'dotNET 4.5.1'
	$validExitCodes = @(0, 3010)

	if (Test-Path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\SKUs\.NETFramework,Version=v4.5.1") {
		Write-Warning "$packageName ya está instalado en su maquina."
		return
	}

	$osVersion  = GetOSVersion-Enviroment
	if ($osVersion -lt [Version]'6.1') { # < 'Windows Server 2008 R2' / 'Windows 7'
		throw "$packageName not supported on your OS."
	}
	elseif ($osVersion -ge [Version]'6.3') { # >= 'Windows Server 2012 R2' / 'Windows 8.1'
		Write-Warning '$packageName ya está instalado por defecto en su S.O. (Sistema Operativo)'
		return
	}
	else {
		Write-Log "Instalar: .NET Framework 4.5.1"
		# para Windows Vista SP2, Windows 7 SP1, Windows 8, Windows Server 2008 SP2, Windows Server 2008 R2 SP1 y Windows Server 2012
		NDP451-KB2858728-x86-x64-AllOS-ENU.exe /Passive /NoRestart /Log "$PSScriptRoot\$packageName.log"
		
		Write-Log "Instalar: Paquete de idioma de .NET Framework 4.5.1"
		# para Windows Vista SP2, Windows 7 SP1, Windows 8, Windows Server 2008 SP2, Windows Server 2008 R2 SP1 y Windows Server 2012
		NDP451-KB2858728-x86-x64-AllOS-ESN.exe /Passive /NoRestart /Log "$PSScriptRoot\$packageName_lang.log"
		Write-Log "Completado"
	}
}

Function Install-Powershell4 {
	$packageName = 'Powershell 4.0'
	$validExitCodes = @(0, 3010) # 2359302 occurs if the package is already installed.

	if ($PSVersionTable -and ($PSVersionTable.PSVersion -ge [Version]'4.0'))
	{
		Write-Warning "$packageName ya esta instalado en su maquina."
		return
	}

	$osVersion  = GetOSVersion-Enviroment
	Write-Log "Instalar: $packageName"
	if ($osVersion -lt [Version]'6.1') { # < 'Windows Server 2008 R2' / 'Windows 7'
		throw "$packageName not supported on your OS."
	}
	elseif ($osVersion -eq [Version]'6.1') { # == 'Windows Server 2008 R2' / 'Windows 7'
		& Windows6.1-KB2819745-x64-MultiPkg.msu /quiet /norestart /log:"$PSScriptRoot\$packageName.Install.log"
	}
	elseif ($osVersion -eq [Version]'6.2') { # >= 'Windows Server 2012' / 'Windows 8'
		& Windows8-RT-KB2799888-x64.msu /quiet /norestart /log:"$PSScriptRoot\$packageName.Install.log"
	} 
	elseif ($osVersion -ge [Version]'6.3') { # >= 'Windows Server 2012 R2' / 'Windows 8.1'
		Write-Warning '$packageName ya viene instalado con el S.O. (Sistema Operativo).'
		return
	}
	Write-Log "Completado"

	Write-Warning "ADVERTENCIA: $packageName requiere que se reinicie la máquina para completar la instalación."
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$reqFolder = "$PSScriptRoot\Packages\Requirements"

Push-Location "$reqFolder\dotNet4.5.1"
[Environment]::CurrentDirectory = "$reqFolder\dotNet4.5.1"
"Get-Location: " + (Get-Location).Path
"CurrentDirectory: " + [Environment]::CurrentDirectory
Install-DotNet451
Pop-Location

Push-Location "$reqFolder\Powershell4.0"
Get-Location
Install-Powershell4
Pop-Location
