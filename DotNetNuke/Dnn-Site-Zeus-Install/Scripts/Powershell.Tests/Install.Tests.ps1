<#
.SYNOPSIS
  Pruebas Unitarias Para Instalacion de un Sitio Web para uso con DNN
#>
Set-StrictMode -Version latest #ERROR REPORTING ALL
#-----------------------------------------------------------[Init]------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -le 2) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # powershell 2.0

$VerbosePreference = "SilentlyContinue" 	# messages do not appear
#$VerbosePreference = "Continue"			# all verbose messages will appear in the output

$TestingSourceName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$TestingSourceDir = (Resolve-Path "$PSScriptRoot\..\Powershell").Path
$TestingSourcePath = Join-Path $TestingSourceDir $TestingSourceName

#-----------------------------------------------------------[Include]------------------------------------------------------------

# WARNING: on this case, script is called below as it executes when called
#. $TestingSourcePath

# Loading Helper Libraries to Setup/Teardown
. "$PSScriptRoot\..\Powershell\Lib-General.ps1"
. "$PSScriptRoot\..\Powershell\Lib-IIS.ps1"

# extra script for database routines (WARNING: requires sqlcmd installed)
. "$PSScriptRoot\..\Helpers\Lib-Database.ps1"


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Remove-AllItemsCreated {
	Remove-Site $SiteName
	Remove-AppPool $AppPoolName
	Remove-Folder $SitePhysicalPath
	Remove-SqlServerDb -Name $DnnDatabaseName -Server $DnnDatabaseServerName -User $dbAdminUser -Password $dbAdminPassword
	Remove-User $TestUserName
}

Function Test-Setup {
	#cleanup
	Remove-AllItemsCreated
	
	# re-create
	New-User -UserName $TestUserName -Password $TestPassword
	
	# empty database for dnn (delete and re-create)
	New-SqlServerDb -Name $DnnDatabaseName -Server $DnnDatabaseServerName `
			-User $dbAdminUser -Password $dbAdminPassword -Force `
			-OwnerWindowsUserName "$env:COMPUTERNAME\$TestUserName"
}

Function Test-Teardown {
	Remove-AllItemsCreated
}




#-----------------------------------------------------------[Data]------------------------------------------------------------
# Windows Account
$TestUserName, $TestPassword = "temphost", 'abc123$'
$dbAdminUser, $dbAdminPassword = $null, $null # DBA (NULL = integrated security)

# Folders
#$DnnInstallZip = "E:\DNN_Platform_07.03.04_Install.zip"
# cloud
if ($env:COMPUTERNAME -eq "WIN2012") {
	$DnnInstallZip = "$env:USERPROFILE\Downloads\DNN_Platform_07.03.04_Install.zip"
	$ExtraModulesFolder = "$env:USERPROFILE\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\ExtraModules"
	$DnnDatabaseServerName = "$env:COMPUTERNAME\SQLEXPRESS"
} 
elseif ($env:COMPUTERNAME -eq "DEV04") {
	$DnnInstallZip = "D:\Instaladores\DotNetNuke\07.03.04\DNN_Platform_07.03.04_Install.zip"
	$ExtraModulesFolder = "$env:USERPROFILE\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\ExtraModules"
	$DnnDatabaseServerName = "$env:COMPUTERNAME\SQL2014"
}
else {
	$DnnInstallZip = "D:\Instaladores\DotNetNuke\07.03.04\DNN_Platform_07.03.04_Install.zip"
	$ExtraModulesFolder = "$env:USERPROFILE\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\ExtraModules"
	$DnnDatabaseServerName = "$env:COMPUTERNAME\SQL2012"
}

$Destination = "C:\Zeus Software\web"

# 1: Delete site/pool if it already exists
$Force = 0
# IIS ********************************************************
# AppPool
$AppPoolName = "test-portal"
$AppPoolUserName = $TestUserName
$AppPoolPassword = $TestPassword
$AppPoolEnable32BitAppOnWin64 = 1
# Web Site
$SiteName = $AppPoolName
$SitePhysicalPath = $Destination
$SitePoolName = $AppPoolName
$SiteIPAddress = ""
$SiteAlias = "$SiteName.dnndev.me"
$SitePort = 80
$SiteMaxUrlSegments = 120
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
$DnnDatabaseName = $SiteName
$DnnDatabaseObjectQualifier = "dnn"
$DnnDatabaseUsername = 'sa'			# for Integrated Security: user,password = $null, $null
$DnnDatabasePassword = 'abc123$'
# 3. Portal Settings
$DnnWebsiteTitle = "[Test] Sitio Web Dnn"
$DnnTemplate = "Blank Website.template"
$DnnLanguage = "es-ES"

# Debugging *******************************
#cls; Remove-AllItemsCreated; exit


#-----------------------------------------------------------[Tests]------------------------------------------------------------


#cls;Invoke-Pester -TestName "Install"
Describe "Install" {
    Test-Setup
	
	It "Install-2-WebSite" {
		& "$TestingSourceDir\Install-2-Website.ps1" -DnnInstallZip $DnnInstallZip -Destination $Destination `
			    -ExtraModulesFolder $ExtraModulesFolder `
			    -Force $Force `
			    <#App Pool#>-AppPoolName $AppPoolName `
			    -AppPoolUserName $AppPoolUserName `
			    -AppPoolPassword $AppPoolPassword `
			    -AppPoolEnable32BitAppOnWin64 $AppPoolEnable32BitAppOnWin64 `
			    <#Web Site#>-SiteName $SiteName `
			    -SiteIPAddress $SiteIPAddress `
			    -SiteAlias $SiteAlias `
			    -SitePort $SitePort `
			    -SiteMaxUrlSegments $SiteMaxUrlSegments `
			    <#web.config#>-MaxRequestMB $MaxRequestMB `
			    -RuntimeExecutionTimeout $RuntimeExecutionTimeout `
			    -RuntimeRequestLengthDiskThreshold $RuntimeRequestLengthDiskThreshold `
			    -RuntimeMaxUrlLength $RuntimeMaxUrlLength `
			    -RuntimeRelaxedUrlToFileSystemMapping $RuntimeRelaxedUrlToFileSystemMapping `
			    -RuntimeMaxQueryStringLength $RuntimeMaxQueryStringLength `
			    -ProviderName $ProviderName `
			    -ProviderEnablePasswordRetrieval $ProviderEnablePasswordRetrieval `
			    -ProviderMinRequiredPasswordLength $ProviderMinRequiredPasswordLength `
			    -ProviderPasswordFormat $ProviderPasswordFormat
    }
	
	It "Install-3-Dnn" {
		& "$TestingSourceDir\Install-3-Dnn.ps1" -DnnRootUrl $DnnRootUrl `
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
	}
	
	Test-Teardown
}
