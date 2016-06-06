<#
.SYNOPSIS
	Testing Installation Scripts

.EXAMPLE
-- run test script
SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File
%PS% "E:\Setup.Dnn\Scripts\Powershell.Tests\Tests.ps1"

-- create symbolic link
#CD C:\Temp\TempShared & mklink /D "Setup.Dnn" "C:\TFS\Zeus\Comun\Setup.Dnn"
Push-Location "C:\Temp\TempShared"; New-Item -ItemType SymbolicLink -Name "Setup.Dnn" -Target "C:\TFS\Zeus\Comun\Setup.Dnn"; Pop-Location

-- on vbox
NET USE F: \\vboxsrv\TempShared /P:Yes

-- install .NET 4.0
E:\dotNetFx40_SilentInstall.cmd
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initializations]--------------------------------------------------------

# Set the output level to verbose (display all Write-Verbose messages)
$global:VerbosePreference = "Continue"

#--------------------------------------------------------[Include]-----------------------------------------------------
if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent }

 "$PSScriptRoot\..\Powershell\Lib-General.ps1"
. "$PSScriptRoot\..\Powershell\Lib-IIS.ps1"
. "$PSScriptRoot\..\Powershell\Lib-Dnn.ps1"

#------------------------------------------------------[Functions]-----------------------------------------------------

#region Test Helpers
# extra for testing
. "$PSScriptRoot\..\Helpers\Lib-Database.ps1"

Function Create-TestUserIIS($TestUserName, $TestPassword) {
	<# 
	https://chocolatey.org/packages/carbon
	cinst carbon -y
	#>
	
	# WARNING: temporary
	Remove-User $TestUserName
	New-User -UserName $TestUserName -Password "abc123$"
	#Add-GroupMember -Name "IIS_IUSRS" -Member $TestUserName
}

Function Test-CleanupAll {
	Remove-Site $SiteName
	Start-Sleep -Milliseconds 100
	Remove-AppPool $AppPoolName
	Remove-Folder $SitePhysicalPath
	Remove-Database -Name $dbName -Server $dbServer -User $dbAdminUser -Password $dbAdminPassword
	Remove-User $TestUserName
}
#endregion  Test Helpers

#----------------------------------------------------------[Pre]----------------------------------------------------------
Clear-Host

#-------------------- Settings for Unit Testing Only ----------------------
# used for database creation / deleting while testing
$dbAdminUser, $dbAdminPassword = $null, $null  # Integrated Security
# Windows Account
$TestUserName, $TestPassword = "temphost", 'abc123$'

#-------------------- Global Settings ----------------------
# Dnn
#$DnnInstallZip = "E:\DNN_Platform_07.03.04_Install.zip"
$DnnInstallZip = "$env:USERPROFILE\Downloads\DNN_Platform_07.03.04_Install.zip"
$Destination = "C:\Zeus Software\web"
$ExtraModulesFolder = "$env:USERPROFILE\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\ExtraModules"
# AppPool
$AppPoolName = "zeusdnn"
$AppPoolUserName = $TestUserName
$AppPoolPassword = $TestPassword
$AppPoolEnable32BitAppOnWin64 = 1
# Web Site
$SiteName = "hotel-portal"
$SitePhysicalPath = $Destination
$SitePoolName = $AppPool.Name
$SiteAlias = "portal.dnndev.me"
$SitePort = 80
# Dnn Site
$DnnRootUrl = "{0}://{1}:{2}" -f "http", $SiteAlias, $SitePort
# Database Credentials
$dbName = "zeusweb"
$dbServer = "$env:COMPUTERNAME\SQLEXPRESS"
$dbUser, $dbPassword = $null, $null  # Integrated Security

#-------------------- Create Computer Testing Account ----------------------
Create-TestUserIIS $TestUserName $TestPassword
#List-User

#-------------------- Install IIS ----------------------
#TODO: Remove -WhatIf
Install_IIS-WinComponents -WhatIf

#-------------------- Empty Dnn Database ----------------------
# create database (delete and re-create)
New-SqlServerDb -Name $dbName -Server $dbServer -User $dbAdminUser -Password $dbAdminPassword -Force $true

#-------------------- Extracting ----------------------
if (-not (Test-Path $Destination -PathType Container)) {
	Extract-ZipFile $SourceZip $Destination
}

#New-AppPool -Name $AppPool.Name -UserName $AppPool.UserName -Password $AppPool.Password -Enable32BitAppOnWin64 $AppPool.Enable32BitAppOnWin64
#New-Site -Name $Site.Name -physicalPath $Site.physicalPath -poolName $Site.poolName -Alias $Site.Alias -Port $Site.Port

Create-DnnSite -DnnInstallZip $DnnInstallZip -Destination $Destination `
    -ExtraModulesFolder $ExtraModulesFolder `
    -Force $Force `
	# web.config changes
    -MaxRequestMB $MaxRequestMB `
    -RuntimeExecutionTimeout $RuntimeExecutionTimeout `
    -RuntimeRequestLengthDiskThreshold $RuntimeRequestLengthDiskThreshold `
    -RuntimeMaxUrlLength $RuntimeMaxUrlLength `
    -RuntimeRelaxedUrlToFileSystemMapping $RuntimeRelaxedUrlToFileSystemMapping `
    -RuntimeMaxQueryStringLength $RuntimeMaxQueryStringLength `
    -ProviderName $ProviderName `
    -ProviderEnablePasswordRetrieval $ProviderEnablePasswordRetrieval `
    -ProviderMinRequiredPasswordLength $ProviderMinRequiredPasswordLength `
    -ProviderPasswordFormat $ProviderPasswordFormat `
	# App Pool
    -AppPoolName $AppPoolName `
    -AppPoolUserName $AppPoolUserName `
    -AppPoolPassword $AppPoolPassword `
    -AppPoolEnable32BitAppOnWin64 $AppPoolEnable32BitAppOnWin64 `
	#
    -SiteName $SiteName `
    -SitePhysicalPath $SitePhysicalPath `
    -SiteAlias $SiteAlias `
    -SitePort $SitePort `
    -SiteMaxUrlSegments $SiteMaxUrlSegments
exit



#----------------------------------------------------------[Main]----------------------------------------------------------

#Get-DotNetVersion
#exit

<#
Push-Location "C:\Temp\TempShared"; New-Item -ItemType SymbolicLink -Name "Setup.Dnn" -Target "C:\TFS\Zeus\Comun\Setup.Dnn"; Pop-Location
-- on vbox
NET USE E: \\vboxsrv\TempShared /P:Yes
E:\dotNetFx40_SilentInstall.cmd

NET USE E: \\vboxsrv\TempShared /P:Yes
SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File
%PS% "E:\Setup.Dnn\Scripts\Powershell.Tests\Tests.ps1"
#>
#$VerbosePreference = "SilentlyContinue" # messages do not appear
$VerbosePreference = "Continue"			# all verbose messages will appear in the output

# TODO: add this one
Write-Host "Disabling IE ESC..."
.\Disable-InternetExplorerESC.ps1
"OK"
exit;


.\Install-IIS.ps1
exit;

