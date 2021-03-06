#requires -Version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Instala Skin en Dnn local
.EXAMPLE
	Set sym link to another folder

$targetFile = "C:\Compartido\Acuacar\SkinPro\InstallSkin-DnnLocal.ps1"
Push-Location (Split-Path $targetFile -Parent)
New-Item -ItemType SymbolicLink `
		-Name (Split-Path $targetFile -Leaf) -Target "C:\Users\PEscobar\Documents\GitHub\scripts\DotNetNuke\Installing-Modules\InstallSkin-DnnLocal.ps1"
Pop-Location

.EXAMPLE
	Call to install certain module given the zip file with the extension

.\InstallSkin-DnnLocal.ps1 -dnnRootPath "C:\inetpub\acuacar.dnndev.me" -dnnRootUrl "acuacar.dnndev.me" `
			-dnnModulePath "C:\Compartido\Acuacar\SkinPro\34762_0_Professional15ColorsTheme\ProfessionalTheme.zip"

.EXAMPLE
	Testing Params
	
[Parameter(Mandatory=$true)][string]$dnnRootPath = "C:\inetpub\acuacar.dnndev.me",
[Parameter(Mandatory=$true)][string]$dnnRootUrl = "acuacar.dnndev.me",
[Parameter(Mandatory=$true)][string]$dnnModulePath = "C:\Compartido\Acuacar\SkinPro\34762_0_Professional15ColorsTheme\ProfessionalTheme.zip"

.EXAMPLE
	Original Params

[Parameter(Mandatory=$true)][string]$dnnRootPath,
[Parameter(Mandatory=$true)][string]$dnnRootUrl,
[Parameter(Mandatory=$true)][string]$dnnModulePath
#>
Param(
[string]$dnnRootPath = "C:\inetpub\acuacar.dnndev.me",
[string]$dnnRootUrl = "acuacar.dnndev.me",
[string]$dnnModulePath = "C:\Compartido\Acuacar\SkinPro\34762_0_Professional15ColorsTheme\ProfessionalTheme.zip"
)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function FormatUrl($url) {
	if ($url -notcontains ":") { $url = "http://$dnnRootUrl" }
	return $url
}

Function Cleanup-InstallFolder([string]$dnnRootPath) {
	Get-ChildItem (Join-Path $dnnRootPath "Install") -Include *.zip,*.resources -Recurse | % {
		if ($_.Name -notlike "DotNetNuke.install.config.resources") {
			$relativePath = $_.FullName.Replace("$dnnRootPath\", "")
			Write-Host "[DELETED] $relativePath" -ForegroundColor Magenta
			Remove-Item $_.FullName -Force
		}
	}
}

Function CopyTo-InstallFolder([string]$dnnRootPath, [string]$filePath, $targetSubfolder = "Module") {
	$targetFolder = (Join-Path $dnnRootPath "Install")
	if ($targetSubfolder) { $targetFolder = (Join-Path $targetFolder $targetSubfolder) }
	$targetFile = Join-Path $targetFolder (Split-Path $filePath -Leaf)

	"[COPY] {0}" -f $targetFile.Replace("$dnnRootPath\", "")
	Copy-Item -Path $filePath -Destination $targetFile -Force
}

Function InstallResources-InstallFolder([string]$dnnRootUrl) {
	$installUrl = "$dnnRootUrl/Install/Install.aspx?mode=InstallResources"
	"[OPEN] $installUrl"
	Start-Process $installUrl
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
$dnnRootUrl = FormatUrl $dnnRootUrl

#-----------------------------------------------------------[Execution]------------------------------------------------------------


#Cleanup-InstallFolder $dnnRootPath
#CopyTo-InstallFolder $dnnRootPath $dnnModulePath
#InstallResources-InstallFolder $dnnRootUrl

# updated skin
robocopy "C:\Compartido\Acuacar\SkinUpdated\_default\Containers\Professional" "$dnnRootPath\Portals\_default\Containers\Professional" /MIR
robocopy "C:\Compartido\Acuacar\SkinUpdated\_default\Skins\Professional" "$dnnRootPath\Portals\_default\Skins\Professional" /MIR

"[OPEN] $dnnRootUrl"
Start-Process $dnnRootUrl

Write-Host "OK" -ForegroundColor DarkGreen
