#requires -version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Configura los proyectos que son Modulos de DNN para que se puedan depurar desde VStudio
.EXAMPLE
.\Setup-DnnProjects-ForDebugging.ps1 -siteName "dev.dnndev.me" -branchName "Dev"
$siteName, $branchName = "dev.dnndev.me", "Dev"; $baseFolder = $PSScriptRoot
#>
Param([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string]$branchName, [string]$baseFolder)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Stop
$ErrorActionPreference = "Stop"

$siteName = $siteName.ToLower()
if (-not $baseFolder) {
	$baseFolder = $PSScriptRoot
	# numero de folders hacia arriba que hay que navegar para llegar al Root del TFS
	$FolderCountToRoot = 3
	for ($i = 0; $i -lt $FolderCountToRoot; $i++) { $baseFolder = Split-Path $baseFolder -Parent }
}

#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

# references external libraries
. "$PSScriptRoot\Libraries\IIS-Functions.ps1"
. "$PSScriptRoot\Libraries\SymLink-Functions.ps1"

#region Functions
#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init {
	Clear-Host
}

#region CsProjUser
Function CheckIsOK-CsProjUser($csprojUserPath, $IISAppRootUrl, $IISUrl) {
	$xml = [xml](Get-content $csprojUserPath -Encoding UTF8)
	$webProps = $xml.Project.ProjectExtensions.VisualStudio.FlavorProperties.WebProjectProperties
	return ($webProps.IISAppRootUrl -eq $IISAppRootUrl) -and ($webProps.IISUrl -eq $IISUrl)
}

Function CreateOrUpdate-CsProjUser($csprojUserPath, $siteName, $virtualPath) {
	# remove leading '/'
	if ($virtualPath -match '^/') { $virtualPath = $virtualPath.Substring(1); }
	
	$IISAppRootUrl = "http://$siteName/"
	$IISUrl = "$IISAppRootUrl$virtualPath"
	
	$fileExist = Test-Path $csprojUserPath
	
	if ($fileExist -and (CheckIsOK-CsProjUser $csprojUserPath $IISAppRootUrl $IISUrl)) {
		return "OK"
	}
	
	$csprojUserContents = @"
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <UseIISExpress>false</UseIISExpress>
  </PropertyGroup>
  <ProjectExtensions>
    <VisualStudio>
      <FlavorProperties GUID="{349c5851-65df-11da-9384-00065b846f21}">
        <WebProjectProperties>
          <StartPageUrl>
          </StartPageUrl>
          <StartAction>NoStartPage</StartAction>
          <AspNetDebugging>True</AspNetDebugging>
          <SilverlightDebugging>False</SilverlightDebugging>
          <NativeDebugging>False</NativeDebugging>
          <SQLDebugging>False</SQLDebugging>
          <ExternalProgram>
          </ExternalProgram>
          <StartExternalURL>
          </StartExternalURL>
          <StartCmdLineArguments>
          </StartCmdLineArguments>
          <StartWorkingDirectory>
          </StartWorkingDirectory>
          <EnableENC>False</EnableENC>
          <AlwaysStartWebServerOnDebug>True</AlwaysStartWebServerOnDebug>
          <UseIIS>True</UseIIS>
          <AutoAssignPort>True</AutoAssignPort>
          <DevelopmentServerPort>5794</DevelopmentServerPort>
          <DevelopmentServerVPath>/</DevelopmentServerVPath>
          <IISUrl>$IISUrl</IISUrl>
          <OverrideIISAppRootUrl>True</OverrideIISAppRootUrl>
          <IISAppRootUrl>$IISAppRootUrl</IISAppRootUrl>
          <NTLMAuthentication>False</NTLMAuthentication>
          <UseCustomServer>False</UseCustomServer>
          <CustomServerUrl>
          </CustomServerUrl>
        </WebProjectProperties>
      </FlavorProperties>
    </VisualStudio>
  </ProjectExtensions>
</Project>
"@
	if (-not $fileExist) {
		New-Item -Path $csprojUserPath -ItemType File -Force | Out-Null
	}
	Set-Content -Path $csprojUserPath -Value $csprojUserContents -Encoding UTF8 -Force
	return "Updated"
}
#endregion CsProjUser

#region CsProj Files
Function GetDnnInfo-CsProj([Parameter(Mandatory=$true)][string]$project) {
	$xmlproj = [xml](Get-Content $project -Raw -Encoding UTF8)
	$projTypes = $xmlproj.Project.PropertyGroup | % { if ($_.ProjectTypeGuids) { $_.ProjectTypeGuids } }
	# not a web project
	if ($projTypes -notlike "*00065b846f21};*") { return }
	
	# get DNNFileName property from project
	$dnn1 = $xmlproj.Project.PropertyGroup | % { if ($_.DNNFileName) { $_.DNNFileName } }
	$dnn2 = $xmlproj.Project.Choose.When.PropertyGroup | % { if ($_.DNNFileName) { $_.DNNFileName } }
	$dnnFileName = &{if ($dnn1) { $dnn1 } else { $dnn2 }}
	
	# it must exist
	if (-not $dnnFileName) { return }

	# fill out a few properties
	$projectName = Split-Path $project -Leaf
	$projFolder = Split-Path $project -Parent
	$dnnManifestPath = "$projFolder\$dnnFileName.dnn"

	# check for special package types
	$dnnPackageType = $null
	if ($dnnManifestPath -like "*\Skin\*") { $dnnPackageType = "Skin" }
	if ($dnnManifestPath -like "*\Container\*") { $dnnPackageType = "Container" }
	
	if (-not (Test-Path $dnnManifestPath)) { 
		if ($dnnManifestPath -notlike "*\Container\*") { throw "Cannot find '$dnnManifestPath' referenced on '$project'" }
		
		$dnnManifestPath = $dnnManifestPath.Replace("\Container\", "\Skin\")
		if (-not (Test-Path $dnnManifestPath)) { throw "Cannot find '$dnnManifestPath' referenced on '$project'" }
	}

	# load dnn manifest
	$xmldnn = [xml](Get-Content $dnnManifestPath -Raw -Encoding UTF8)

	# NOTE: special case for Skins/Containers
	$xmlPackage = $xmldnn.dotnetnuke.packages.package
	if ($dnnPackageType) {
		$xmlPackage = $xmldnn.dotnetnuke.packages.package | ? { $_.type -eq $dnnPackageType } 
		if (-not $xmlPackage) { throw "Cannot find node packages/package[@type='$dnnPackageType']" }
	}
	
	# find xpath: component[@type='ResourceFile']/basePath
	$resourceNode = $xmlPackage.components.component | ? { $_.type -eq "ResourceFile" }
	if (-not $resourceNode) { throw "Missing <component type='ResourceFile'> on '$dnnManifestPath'" }
	$dnnBasePath = $resourceNode.resourceFiles.basePath
	if (-not $dnnBasePath) { 
		Write-Warning "Missing <basePath> under <component type='ResourceFile'> on '$dnnManifestPath'"
	}
	# Example: Recursos\Externos\ZeusReferenciasExternas.csproj
	if ($dnnBasePath -eq "bin") { 
		Write-Warning "Skipping <basePath>$dnnBasePath</basePath> under <component type='ResourceFile'> on '$dnnManifestPath'"
		$dnnBasePath = $null
	}
	
	# do not need virtualdir for those without basePath
	if (-not $dnnBasePath) { return }

	# convert to virtual path and add leading slash if missing
	$dnnBasePath = $dnnBasePath.Replace("\", "/")
	if (-not $dnnBasePath.StartsWith("/")) { $dnnBasePath = "/$dnnBasePath" }
	
	# return object with properties
	New-Object PSObject -Property @{
			ProjectPath = $project
			ProjectDir = $projFolder
			DnnVirtualDir = $dnnBasePath
			DnnFullPath = $dnnManifestPath
			DnnPackageType = $xmlPackage.type
			#Name = $projectName
			#NameWithoutExtension = [IO.Path]::GetFileNameWithoutExtension($project)
			#DnnFileName = $dnnFileName
			#RelativePath = $project.Replace("$branchRootFolder\", "")
	}
}

Function FindDnnTypes-CsProj([Parameter(Mandatory=$true)][string[]]$BranchRootFolders) {
	foreach ($branchRootFolder in $branchRootFolders) {
		$projects = Get-ChildItem $branchRootFolder -Include "*.csproj" -Recurse -File | Select -ExpandProperty FullName
		foreach ($project in $projects) { 
			$parentFolder = Split-Path $project -Parent
			if (-not (Test-SymLink $parentFolder)) {
				GetDnnInfo-CsProj $project
			}
		}
	}
}

Function FixDnnUrl-CsProj([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string[]]$branchRootFolders, [string[]]$ExcludeProjects) {
	# 1. borrar munditos ("Applications") que Visual Studio haya creado
	# 2. si DesktopModules esta virtualizado, lo desvirtualiza (Generalmente hecho por Visual Studio cuando se intenta depurar y no se ha configurado el modulo de DNN)
	List-SiteApp $siteName | Delete-SiteApp
	if (Exist-VirtualDir $siteName "/DesktopModules") { Delete-VirtualDir "$siteName/DesktopModules" }

	# ruta fisica del sitio
	$siteRootDir = GetPhysicalPath-SiteApp $siteName

	# obtiene todos los directorios virtuales debajo del sitio
	# obtiene todos los enlaces simbolicos que existan
	$virtualDirsLeft = [Collections.ArrayList](List-VirtualDir $siteName)
	$symLinksLeft = [Collections.ArrayList](List-SymLink (@($siteRootDir) + $branchRootFolders))

	foreach ($branchRootFolder in $branchRootFolders) {
		$projects = FindDnnTypes-CsProj $branchRootFolder
		foreach ($project in $projects) {
			$sitePath = Join-Path $siteRootDir ($project.DnnVirtualDir -replace '/','\')
			$vdirPath = "$siteName$($project.DnnVirtualDir)"

			$isExcluded = $false
			$ExcludeProjects | % { if ($project -match [Regex]::Escape($_)) { $isExcluded = $true } }
			if ($isExcluded) { continue }

			# va limpiando de la lista los directorios virtuales/enlaces simbolicos siendo usados
			if ($virtualDirsLeft -contains $vdirPath) {  $virtualDirsLeft.Remove($vdirPath) } 
			if ($symLinksLeft -contains $sitePath) {  $symLinksLeft.Remove($sitePath) } 
			if ($symLinksLeft -contains $project.ProjectDir) { $symLinksLeft.Remove($project.ProjectDir) } 
			
			$project.ProjectPath
			# 1. create virtual dir
			# 2. create sym-link 
			# 3. create '.csproj.user'
			$responseVdir = Create-VirtualDir -siteName $siteName -virtualPath $project.DnnVirtualDir -physicalPath $project.ProjectDir
			$responseSymLink = Create-SymLink -SymName $sitePath -Path $project.ProjectDir -Force -ReplaceExistingFileOrFolder
			$responseCsprojUser = CreateOrUpdate-CsProjUser -csprojUserPath "$($project.ProjectPath).user" -siteName $siteName -virtualPath $project.DnnVirtualDir
			"    [VDIR: $responseVdir; SymLink: $responseSymLink; .csproj.user: $responseCsprojUser]"
		}
	}
	
	# remove special nested mappings
	$symLinksLeft = $symLinksLeft | ? { $_ -notmatch '\\Recursos' -and $_ -notmatch "\\Addons" }
	
	# borra directorios virtuales/enlaces simbolicos que ya no se usan
	$virtualDirsLeft | Delete-VirtualDir
	$symLinksLeft | Delete-SymLink
}
#UNIT-TEST
#Init; List-SymLink "C:\inetpub\zeusdnn\dev"; exit
#endregion CsProjects


Function FindBranch-Folders([Parameter(Mandatory=$true)][string]$baseFolder, [Parameter(Mandatory=$true)][string]$branchName) {
	$cacheDirs = @()
	Get-ChildItem $baseFolder -Include $branchName -Recurse -Directory | % { 
		$dir = $_.FullName
		$dir = $dir -replace "(\\$branchName)\b.+`$", '$1'
		if ($cacheDirs -notcontains $dir) { 
			$cacheDirs += $dir; 
			# send response to stream as they're selected
			$dir
		}
	}
}
#endregion

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Init
"SiteName: '$siteName'"
"BranchName: '$branchName'"
"BaseFolder: '$baseFolder'"

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# si el sitio no existe, sale
if (-not (Exist-Site $siteName)) { 
	"No web site '$siteName' found. Exiting..."
	Exit
}

$branchRootFolders = FindBranch-Folders $baseFolder $branchName

FixDnnUrl-CsProj $siteName $branchRootFolders -ExcludeProjects @("InteligEmp.Recursos")
