##requires -version 4
<#
.SYNOPSIS
  Unzip site and create with specified parameters
#>
Param(
	$SourceZip,
	$PhysicalPath
)
#-----------------------------------------------------------[Param]------------------------------------------------------------
$UserName, $Password = "temphost", 'abc123$'
$SourceZip, $PhysicalPath = "E:\DNN_Platform_07.03.04_Install.zip", "C:\Zeus Software\web"
$AppPool = @{ Name = "zeusdnn"; UserName = $UserName; Password = $Password; Enable32BitAppOnWin64 = 1 }
$Site = @{ Name = "hotel-portal"; physicalPath = $PhysicalPath; poolName = $AppPool.Name; Alias = "portal.dnndev.me"; Port = 80 }

#--------------------------------------------------------[Include]-----------------------------------------------------
if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # PS 2.0 compatibility

.  "$PSScriptRoot\Lib-General.ps1"
.  "$PSScriptRoot\Lib-IIS.ps1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------

# extracting
if (-not (Test-Path $PhysicalPath -PathType Container)) {
	Extract-ZipFile $SourceZip $PhysicalPath
}

# creating site
Create-AppPoolIIS -Name $AppPool.Name -UserName $AppPool.UserName -Password $AppPool.Password -Enable32BitAppOnWin64 $AppPool.Enable32BitAppOnWin64
Create-SiteIIS -Name $Site.Name -physicalPath $Site.physicalPath -poolName $Site.poolName -Alias $Site.Alias -Port $Site.Port
# configuring
UpdateAll-ConfigIIS -SiteName $Site.Name

#TODO: rename {dnnRoot}\install\install* to Install*.old
