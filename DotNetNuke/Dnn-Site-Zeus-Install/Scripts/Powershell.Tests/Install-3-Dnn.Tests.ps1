<#
.SYNOPSIS
  Pruebas Unitarias Para Invocar Asistente de Instalación de DNN
#>
Set-StrictMode -Version latest #ERROR REPORTING ALL
#-----------------------------------------------------------[Init]------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -le 2) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # powershell 2.0

$TestingSourceName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$TestingSourceDir = (Resolve-Path "$PSScriptRoot\..\Powershell").Path
$TestingSourcePath = Join-Path $TestingSourceDir $TestingSourceName

#-----------------------------------------------------------[Include]------------------------------------------------------------

# WARNING: on this case, script is called below as it executes when called
#. $TestingSourcePath

# Loading Helper Libraries to Setup/Teardown
. "$PSScriptRoot\..\Powershell\Lib-General.ps1"
. "$PSScriptRoot\..\Powershell\Lib-IIS.ps1"


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Remove-ItemsCreated {
	Remove-Site $SiteName
	Remove-AppPool $AppPoolName
	Remove-Folder $SitePhysicalPath
	Remove-User $TestUserName
}

Function Test-Setup {
	#cleanup
	Remove-ItemsCreated
	
	# re-create
	New-User -UserName $TestUserName -Password "abc123$"
	#Add-GroupMember -Name "IIS_IUSRS" -Member $TestUserName
}

Function Test-Teardown {
	Remove-ItemsCreated
}




#-----------------------------------------------------------[Data]------------------------------------------------------------
# Windows Account
$TestUserName, $TestPassword = "temphost", 'abc123$'

# Folders
#$DnnInstallZip = "E:\DNN_Platform_07.03.04_Install.zip"
$DnnInstallZip = "$env:USERPROFILE\Downloads\DNN_Platform_07.03.04_Install.zip"
$ExtraModulesFolder = "$env:USERPROFILE\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\ExtraModules"
$Destination = "C:\Zeus Software\web"

# 1: Delete site/pool if it already exists
$Force = 0
# IIS ********************************************************
# AppPool
$AppPoolName = "hotel-portal"
$AppPoolUserName = $TestUserName
$AppPoolPassword = $TestPassword
$AppPoolEnable32BitAppOnWin64 = 1
# Web Site
$SiteName = $AppPoolName
$SitePhysicalPath = $Destination
$SitePoolName = $AppPoolName
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

#-----------------------------------------------------------[Tests]------------------------------------------------------------


#Invoke-Pester -TestName "Install-2-WebSite"
Describe "Install-2-WebSite" {
    Test-Setup
	
	It "Common Installation" {
		& $TestingSourcePath -DnnInstallZip $DnnInstallZip -Destination $Destination `
			    -ExtraModulesFolder $ExtraModulesFolder `
			    -Force $Force `
			    <#App Pool#>-AppPoolName $AppPoolName `
			    -AppPoolUserName $AppPoolUserName `
			    -AppPoolPassword $AppPoolPassword `
			    -AppPoolEnable32BitAppOnWin64 $AppPoolEnable32BitAppOnWin64 `
			    <#Web Site#>-SiteName $SiteName `
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
	
	Test-Teardown
}
