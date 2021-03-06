#requires -version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Create necessary mappings on File System in order to avoid mappings folders on TFS Workspace
#>
Param([string]$BranchName = "Trunk")

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop
$ErrorActionPreference = "Stop"

#----------------------------------------------------------[Declarations]----------------------------------------------------------
$Script:ScriptVersion = "1.0"
$ScriptName = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

#-----------------------------------------------------------[Functions]------------------------------------------------------------

. "$PSScriptRoot\Libraries\SymLink-Functions.ps1"

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Settings]------------------------------------------------------------

$BranchName = $BranchName.Replace($ScriptName, "").TrimStart("-") #  remove script name from branch passed in (also leading dashes)
$SourceRoot = [IO.Path]::GetFullPath("$PSScriptRoot\..\..\$BranchName")
$TargetRoot = "C:\inetpub\DotNetNukeTripleD"

# display on screen parameter values
"BranchName: '$BranchName'`nSource: '$SourceRoot'`nTarget = '$TargetRoot'"

# Legend
# {0} = replaced by source File/Folder Name
$Mappings = @(
		@{ Source = "..\General\Templates\MVVM\TemplateKnockoutJs"; Target = "DesktopModules\TemplateKnockoutJs"; ReplaceExistingFileOrFolder = $true },
		@{ Source = "..\General\DevFixes\Dashboard\*";              Target = "Resources\Shared\scripts\{0}"; ReplaceExistingFileOrFolder = $true },
		@{ Source = "Include\*";                                    Target = "Include\{0}"; Exclude = "Etiquetas"; Directory = $true; ReplaceExistingFileOrFolder = $true },
		@{ Source = "Include\Etiquetas\*";                          Target = "App_GlobalResources\{0}"; ReplaceExistingFileOrFolder = $true },
		@{ Source = "Common\TripleD.*";                             Target = "DesktopModules\{0}"; ReplaceExistingFileOrFolder = $true },
		@{ Source = "Modules\*";                                    Target = "DesktopModules\{0}"; Directory = $true; ReplaceExistingFileOrFolder = $true }
	)

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#DeleteMapping-SymLink -SourceRoot $SourceRoot -TargetRoot $TargetRoot -Mappings $Mappings
CreateMapping-SymLink -SourceRoot $SourceRoot -TargetRoot $TargetRoot -Mappings $Mappings

#-----------------------------------------------------------[Extras]------------------------------------------------------------

Write-Host "[Removing Unused Mappings]" -ForegroundColor Blue
if (Test-SymLink "$TargetRoot\bin\BuildScripts") {
	Delete-SymLink -SymName "$TargetRoot\bin\BuildScripts"
}
elseif (Test-Path "$TargetRoot\bin\BuildScripts") {
	Remove-Item "$TargetRoot\bin\BuildScripts" -Force -Recurse
}

Write-Host "[Remove Read-Only Attributes On Referenced Assemblies]" -ForegroundColor Blue
Get-ChildItem "$SourceRoot\Lib","$TargetRoot\bin" -Recurse -ReadOnly | % { "[-R] $($_.FullName)"; $_.IsReadOnly = $false }

Write-Host "[Reverse Symbolic Link from {Dnn}\bin to {Project}\bin]" -ForegroundColor Blue
Create-SymLink -SymName "$SourceRoot\bin" -Path "$TargetRoot\bin" -Force -ReplaceExistingFileOrFolder
