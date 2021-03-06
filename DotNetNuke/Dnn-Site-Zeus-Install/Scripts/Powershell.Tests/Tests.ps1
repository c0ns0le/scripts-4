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


Push-Location "C:\Temp\TempShared"; New-Item -ItemType SymbolicLink -Name "Setup.Dnn" -Target "C:\TFS\Zeus\Comun\Setup.Dnn"; Pop-Location
-- on vbox
NET USE E: \\vboxsrv\TempShared /P:Yes
E:\dotNetFx40_SilentInstall.cmd

NET USE E: \\vboxsrv\TempShared /P:Yes
%PS% "E:\Setup.Dnn\Scripts\Powershell.Tests\Tests.ps1"
SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File
%PS% "E:\Setup.Dnn\Scripts\Powershell.Tests\Tests.ps1"
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initializations]--------------------------------------------------------

# Set the output level to verbose (display all Write-Verbose messages)
$global:VerbosePreference = "Continue"

#--------------------------------------------------------[Include]-----------------------------------------------------
if (!$Script:PSScriptRoot) { $Script:PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent }

. "$PSScriptRoot\..\Powershell\Lib-General.ps1"
. "$PSScriptRoot\..\Powershell\Lib-IIS.ps1"
. "$PSScriptRoot\..\Powershell\Lib-Dnn.ps1"

#------------------------------------------------------[Functions]-----------------------------------------------------

#region Test Helpers
# extra for testing
. "$PSScriptRoot\..\Helpers\Lib-Database.ps1"

Function New-TestingAccount($TestUserName, $TestPassword) {
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
	Remove-AppPool $AppPoolName
	Remove-Folder $SitePhysicalPath
	Remove-SqlServerDb -Name $DnnDatabaseName -Server $DnnDatabaseServerName -User $dbAdminUser -Password $dbAdminPassword
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
# IIS ********************************************************
# AppPool
$AppPoolName = "zeusweb"
$AppPoolUserName = $TestUserName
$AppPoolPassword = $TestPassword
$AppPoolEnable32BitAppOnWin64 = 1
# Web Site
$SiteName = "hotel-portal"
$SitePhysicalPath = $Destination
$SitePoolName = $AppPoolName
$SiteAlias = "portal.dnndev.me"
$SitePort = 80
# Web.Config
$MaxRequestMB = 100
$RuntimeExecutionTimeout = 1200
$RuntimeRequestLengthDiskThreshold = 90000
$RuntimeMaxUrlLength = 5000
$RuntimeRelaxedUrlToFileSystemMapping = "true"
$RuntimeMaxQueryStringLength = 50000
$ProviderName = "AspNetSqlMembershipProvider"
$ProviderEnablePasswordRetrieval = "true"
$ProviderMinRequiredPasswordLength = 6
$ProviderPasswordFormat = "Encrypted"
# Dnn Site ***************************************************
$DnnRootUrl = "{0}://{1}:{2}" -f "http", $SiteAlias, $SitePort
# 1. Super User
$DnnUsername = "host"
$DnnPassword = 'abc123$'
$DnnEmail = "host@change.me"
# 2. Database Credentials
$DnnDatabaseServerName = "$env:COMPUTERNAME\SQLExpress"
$DnnDatabaseName = $SiteName
$DnnDatabaseObjectQualifier = "dnn_"
$DnnDatabaseUsername = $null			# for Integrated Security: user,password are null
$DnnDatabasePassword = $null
# 3. Portal Settings
$DnnWebsiteTitle = "Sitio Web Dnn"
$DnnTemplate = "Blank Website.template"
$DnnLanguage = "es-ES"

#-------------------- Testing Items ----------------------
# create testing account on account
New-TestingAccount $TestUserName $TestPassword
# empty database for dnn (delete and re-create)
New-SqlServerDb -Name $DnnDatabaseName -Server $DnnDatabaseServerName -User $dbAdminUser -Password $dbAdminPassword -Force $true

#----------------------------------------------------------[Main]----------------------------------------------------------

#-------------------- Install IIS ----------------------
#TODO: Remove -WhatIf
Install_IIS-WinComponents -WhatIf

#-------------------- Extracting ----------------------
if (-not (Test-Path $Destination -PathType Container)) {
	Extract-ZipFile $SourceZip $Destination
}

#New-AppPool -Name $AppPool.Name -UserName $AppPool.UserName -Password $AppPool.Password -Enable32BitAppOnWin64 $AppPool.Enable32BitAppOnWin64
#New-Site -Name $Site.Name -physicalPath $Site.physicalPath -poolName $Site.poolName -Alias $Site.Alias -Port $Site.Port

New-DnnSite -DnnInstallZip $DnnInstallZip -Destination $Destination `
    -ExtraModulesFolder $ExtraModulesFolder `
    -Force $Force `
	# App Pool
    -AppPoolName $AppPoolName `
    -AppPoolUserName $AppPoolUserName `
    -AppPoolPassword $AppPoolPassword `
    -AppPoolEnable32BitAppOnWin64 $AppPoolEnable32BitAppOnWin64 `
	# Web Site
    -SiteName $SiteName `
    -SitePhysicalPath $SitePhysicalPath `
    -SiteAlias $SiteAlias `
    -SitePort $SitePort `
    -SiteMaxUrlSegments $SiteMaxUrlSegments
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

InstallWizard-DnnSite -DnnRootUrl $DnnRootUrl `
    -DnnUsername $DnnUsername `
    -DnnPassword $DnnPassword `
    -DnnEmail $DnnEmail `
    -DnnDatabaseServerName $DnnDatabaseServerName `
    -DnnDatabaseName $DnnDatabaseName `
    -DnnDatabaseObjectQualifier $DnnDatabaseObjectQualifier `
    -DnnDatabaseUsername $DnnDatabaseUsername `
    -DnnDatabasePassword $DnnDatabasePassword `
    -DnnWebsiteTitle $DnnWebsiteTitle `
    -DnnTemplate $DnnTemplate `
    -DnnLanguage $DnnLanguage
