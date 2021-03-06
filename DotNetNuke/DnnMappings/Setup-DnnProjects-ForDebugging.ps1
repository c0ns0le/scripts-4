#requires -version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Configura los proyectos que son Modulos de DNN para que se puedan depurar desde VStudio
.EXAMPLE
.\Setup-DnnProjects-ForDebugging.ps1 -siteName "dev.dnndev.me" -branchName "Dev"
#$siteName, $branchName = "DDD-Trunk.dnndev.me", "Trunk"; $baseFolder = $null
#>
$siteName, $branchName = "DDD-Trunk.dnndev.me", "Trunk"; $baseFolder = $null
#Param([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string]$branchName, [string]$baseFolder)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Stop
$ErrorActionPreference = "Stop"

$siteName = $siteName.ToLower()
if (-not $baseFolder) {
	$baseFolder = $PSScriptRoot
	# numero de folders hacia arriba que hay que navegar para llegar al Root del TFS
	$FolderCountToRoot = 2
	for ($i = 0; $i -lt $FolderCountToRoot; $i++) { $baseFolder = Split-Path $baseFolder -Parent }
}

#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

# references external libraries
. "$PSScriptRoot\Libraries\IIS-Functions.ps1"
. "$PSScriptRoot\Libraries\SymLink-Functions.ps1"
. "$PSScriptRoot\Libraries\Xml-Functions.ps1"
. "$PSScriptRoot\Libraries\TFS-Functions.ps1"

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
	
	if (-not $dnnFileName) {
		$moduleTarget = $xmlproj.Project.Target | ? { $_.Name -eq "AfterBuild" }
		if ($moduleTarget.DependsOnTargets -match 'Package|Module|Library|Skin|Container') {
			$dnnFileName = [IO.Path]::GetFileNameWithoutExtension($project)
		}
	}
	
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


#EnableUserSettings-CsProj $ProjectPath
#Function EnableUserSettings-CsProj([Parameter(Mandatory=$true)][string]$ProjectPath) {
#}


Function FixForDnn-CsProj([Parameter(Mandatory=$true)][string]$ProjectPath) {
<#
.SYNTAX
	Fix project to make it work with DNN without using mappings on TFS
#>
	$xml = [xml](Get-Content $ProjectPath -Raw -Encoding UTF8)

	$wp = $xml.Project.ProjectExtensions.VisualStudio.FlavorProperties.WebProjectProperties
	$dnnLegacyProperties = $xml.Project.PropertyGroup | ? { $_.DNNFileName }

	$isEnabledUserSettings = $wp.SaveServerSettingsInUserFile -eq 'True'
	$hasDnnLegacyProperties = $dnnLegacyProperties -ne $null

	# if no need changes, return
	if ($isEnabledUserSettings -and -not $hasDnnLegacyProperties) { return }
	
	Checkout-TFS $ProjectPath
	
	if (-not $isEnabledUserSettings) { 
		RemoveAllChildren-Xml $wp -ExceptionList 'SaveServerSettingsInUserFile'
		$wp.SaveServerSettingsInUserFile = 'True'
		#AddChild-Xml $xml $wp 'SaveServerSettingsInUserFile' 'True'
	}
	
	if ($hasDnnLegacyProperties) { 
		RemoveAllChildren-Xml $dnnLegacyProperties
		$dnnLegacyProperties.ParentNode.RemoveChild($dnnLegacyProperties) | Out-Null
	}
	
	$xml.Save($ProjectPath)
}


Function FindDnnTypes-CsProj([Parameter(Mandatory=$true)][string[]]$BranchRootFolders, [string[]]$ExcludeProjects) {
	foreach ($branchRootFolder in $branchRootFolders) {
		$projects = Get-ChildItem $branchRootFolder -Include "*.csproj" -Recurse -File | Select -ExpandProperty FullName
		foreach ($project in $projects) { 
			$isExcluded = $false
			$ExcludeProjects | % { if ($project -match [Regex]::Escape($_)) { $isExcluded = $true } }
			if ($isExcluded) { continue }

			$parentFolder = Split-Path $project -Parent
			if (-not (Test-SymLink $parentFolder)) {
				GetDnnInfo-CsProj $project
			}
		}
	}
}

Function GetDnnUrl-CsProj([Parameter(Mandatory=$true)][string]$siteName, [Parameter(Mandatory=$true)][string[]]$branchRootFolders, [string[]]$ExcludeProjects) {
	# ruta fisica del sitio
	$siteRootDir = GetPhysicalPath-SiteApp $siteName

	$projects = @()
	foreach ($branchRootFolder in $branchRootFolders) {
		$projects += FindDnnTypes-CsProj $branchRootFolder $ExcludeProjects
	}
	return $projects
}

Function FixDnnUrl-CsProj {
Param(
	[Parameter(Mandatory=$true)][string]$siteName, 
	[Parameter(Mandatory=$true)][object[]]$projects, 
	[Parameter(Mandatory=$true)][string[]]$branchRootFolders, 
	$ExtraMappings = $null, 
	[Switch]$IncludeFileSymLink = $false, 
	[Switch]$ReverseMapToBin = $false
)
	# 1. borrar munditos ("Applications") que Visual Studio haya creado
	# 2. si DesktopModules esta virtualizado, lo desvirtualiza (Generalmente hecho por Visual Studio cuando se intenta depurar y no se ha configurado el modulo de DNN)
	List-SiteApp $siteName | Delete-SiteApp
	if (Exist-VirtualDir $siteName "/DesktopModules") { Delete-VirtualDir "$siteName/DesktopModules" }

	# ruta fisica del sitio
	$siteRootDir = GetPhysicalPath-SiteApp $siteName

	# 1. obtiene todos los directorios virtuales debajo del sitio
	# 2. obtiene todos los enlaces simbolicos que existan
	$virtualDirsLeft = [Collections.ArrayList]([string[]](List-VirtualDir $siteName))
	
	[string[]]$symLinksLeft1 = List-SymLink $siteRootDir -IncludeFileSymLink:$IncludeFileSymLink
	[string[]]$symLinksLeft2 = List-SymLink $branchRootFolders
	
	$symLinksLeft = [Collections.ArrayList]($symLinksLeft1 + $symLinksLeft2)

	Write-Host "[Remove Read-Only Attributes On Referenced Assemblies]" -ForegroundColor Blue
	$libs = @("$siteRootDir\bin")
	$branchRootFolders | % { if (Test-Path "$_\Lib" -PathType Container) { $libs += "$_\Lib" } }
	Get-ChildItem $libs -Recurse -ReadOnly | % { "[-R] $($_.FullName)"; $_.IsReadOnly = $false }


	if ($ReverseMapToBin) {
		Write-Host "[Reverse Symbolic Link from {Dnn}\bin to {Project}\bin]" -ForegroundColor Blue
		$responseSymLink = Create-SymLink -SymPath "$SourceRoot\bin" -Path "$TargetRoot\bin" -Force -ReplaceExistingFileOrFolder
		"$($responseSymLink): $TargetRoot\bin"
	}


	if ($ExtraMappings) {
		#Delete-DnnMapping -SourceRoot $branchRootFolders[0] -TargetRoot $siteRootDir -Mappings $ExtraMappings
		Create-DnnMapping -SourceRoot $branchRootFolders[0] -TargetRoot $siteRootDir -Mappings $ExtraMappings -symLinksLeft $symLinksLeft
	}

	foreach ($project in $projects) {
		$sitePath = Join-Path $siteRootDir ($project.DnnVirtualDir -replace '/','\')
		$vdirPath = "$siteName$($project.DnnVirtualDir)"

		# va limpiando de la lista los directorios virtuales/enlaces simbolicos siendo usados
		if ($virtualDirsLeft -contains $vdirPath) { $virtualDirsLeft.Remove($vdirPath) } 
		if ($symLinksLeft -contains $sitePath) { $symLinksLeft.Remove($sitePath) } 
		if ($symLinksLeft -contains $project.ProjectDir) { $symLinksLeft.Remove($project.ProjectDir) } 
		
		$project.ProjectPath
		# 1. create virtual dir
		# 2. create sym-link 
		# 3. create '.csproj.user'
		FixForDnn-CsProj $project.ProjectPath
		$responseVdir = Create-VirtualDir -siteName $siteName -virtualPath $project.DnnVirtualDir -physicalPath $project.ProjectDir
		$responseSymLink = Create-SymLink -SymPath $sitePath -Path $project.ProjectDir -Force -ReplaceExistingFileOrFolder
		$responseCsprojUser = CreateOrUpdate-CsProjUser -csprojUserPath "$($project.ProjectPath).user" -siteName $siteName -virtualPath $project.DnnVirtualDir
		"    [VDIR: $responseVdir; SymLink: $responseSymLink; .csproj.user: $responseCsprojUser]"
	}
	
	# remove special nested mappings
	$symLinksLeft = $symLinksLeft | ? { $_ -notmatch '\\Recursos' -and $_ -notmatch "\\Addons" }
	
	# borra directorios virtuales/enlaces simbolicos que ya no se usan
	if ($virtualDirsLeft) { $virtualDirsLeft | Delete-VirtualDir }
	if ($symLinksLeft) { $symLinksLeft | Delete-SymLink }
}
#UNIT-TEST
#Init; List-SymLink "C:\inetpub\zeusdnn\dev"; exit
#endregion CsProjects

#region Mappings
Function Exec-DnnMapping($SourceRoot, $TargetRoot, $Mappings, [Switch]$Delete = $false, [Collections.ArrayList]$symLinksLeft = $null) {
	foreach ($Mapping in $Mappings) {
		$Sources = @()
		if ($Mapping.Source -match '\*$') { 
			$sourcePattern = "$SourceRoot\$($Mapping.Source)"
			# when adding mapping, default mode changes to '-Recurse' when using '...\*'
			if ($Mapping.Exclude) {
				# when '*' is removed, the '-Recurse' goes back to $false
				$sourcePattern = $sourcePattern -replace '\*$', ''
			}
			
			$Sources = Get-ChildItem $sourcePattern -Exclude $Mapping.Exclude -Directory:($Mapping.Directory -eq $true) | 
						Select -ExpandProperty FullName 
		}
		else { $Sources = [IO.Path]::GetFullPath("$SourceRoot\$($Mapping.Source)") }
		
		foreach ($itemSource in $Sources) {
			$itemTarget = "$TargetRoot\$($Mapping.Target)"
			# replace {0} by Name
			if ($itemTarget -like "*{0}*") {
				$Name = [IO.Path]::GetFileName($itemSource)
				$itemTarget = $itemTarget -f $Name
			}
			# delete symbolic link
			if ($Delete) {
				if (Test-SymLink $itemTarget) { Delete-SymLink $itemTarget }
				elseif (Test-Path $itemTarget) { "Not a symbolic link: '$itemTarget'" }
				else { "Not found: $itemTarget" }
			}
			# create symbolic link
			else {
				$responseSymLink = Create-SymLink $itemSource $itemTarget -Force -ReplaceExistingFileOrFolder:$Mapping.ReplaceExistingFileOrFolder
				"$($responseSymLink): $itemTarget"
				# remove from cached list of existing sym-links
				if ($symLinksLeft -contains $itemTarget) {  $symLinksLeft.Remove($itemTarget) } 
			}
		}
	}
}

Function Create-DnnMapping($SourceRoot, $TargetRoot, $Mappings, [Collections.ArrayList]$symLinksLeft = $null) {
	Write-Host "[Create-DnnMapping]" -ForegroundColor Blue
	Exec-DnnMapping $SourceRoot $TargetRoot $Mappings -symLinksLeft $symLinksLeft
}

Function Delete-DnnMapping($SourceRoot, $TargetRoot, $Mappings) {
	Write-Host "[Delete-DnnMapping]" -ForegroundColor Blue
	Exec-DnnMapping $SourceRoot $TargetRoot $Mappings -Delete
}
#endregion


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

# display on screen parameter values
"SiteName: '$siteName'"
"BranchName: '$branchName'"


#-----------------------------------------------------------[Settings]------------------------------------------------------------

# Legend
# {0} = replaced by source File/Folder Name
$ExtraMappings = @(
		@{ Source = "..\General\DevFixes\Dashboard\*";              Target = "Resources\Shared\scripts\{0}"; ReplaceExistingFileOrFolder = $true },
		@{ Source = "Include\*";                                    Target = "Include\{0}"; Exclude = "Etiquetas"; Directory = $true; ReplaceExistingFileOrFolder = $true },
		@{ Source = "Include\Etiquetas\*";                          Target = "App_GlobalResources\{0}"; ReplaceExistingFileOrFolder = $true }
		#@{ Source = "..\General\Templates\MVVM\TemplateKnockoutJs"; Target = "DesktopModules\TemplateKnockoutJs"; ReplaceExistingFileOrFolder = $true },
		#@{ Source = "Common\TripleD.*";                             Target = "DesktopModules\{0}"; ReplaceExistingFileOrFolder = $true },
		#@{ Source = "Modules\*";                                    Target = "DesktopModules\{0}"; Directory = $true; ReplaceExistingFileOrFolder = $true }
	)

# si el sitio no existe, sale
if (-not (Exist-Site $siteName)) { 
	"No web site '$siteName' found. Exiting..."
	Exit
}

$TargetRoot = Join-Path $baseFolder $branchName

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Host "[Resolve Mappings]" -ForegroundColor Blue
$projects = GetDnnUrl-CsProj -siteName $siteName -branchRootFolders $TargetRoot -ExcludeProjects @('\Old\')
FixDnnUrl-CsProj -siteName $siteName -projects $projects -branchRootFolders $TargetRoot -ExtraMappings $ExtraMappings -IncludeFileSymLink -ReverseMapToBin


#-----------------------------------------------------------[Extras]------------------------------------------------------------

# old mapping in DDD
Write-Host "[Removing Unused Mappings]" -ForegroundColor Blue
if (Test-SymLink "$TargetRoot\bin\BuildScripts") { Delete-SymLink -SymPath "$TargetRoot\bin\BuildScripts" }
elseif (Test-Path "$TargetRoot\bin\BuildScripts") { Remove-Item "$TargetRoot\bin\BuildScripts" -Force -Recurse }
