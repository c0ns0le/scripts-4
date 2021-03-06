##requires -version 4
<#
.SYNOPSIS
 	Dado un archivo zip de DNN, Crea y configura sitio web en IIS para montar DNN
#>
Param(
	[Parameter(Mandatory=$true)][string]$DnnInstallZip,
	[Parameter(Mandatory=$true)][string]$Destination,
	[string]$ExtraModulesFolder,
	[bool]$Force = 0,
	# App Pool
	[Parameter(Mandatory=$true)][string]$AppPoolName,
	[string]$AppPoolUserName, 
	[string]$AppPoolPassword,
	[int]$AppPoolEnable32BitAppOnWin64 = 1,
	# Web Site
	[Parameter(Mandatory=$true)][string]$SiteName, 
	[string]$SiteIPAddress,
	[string]$SiteAlias,
	[int]$SitePort = 80,
	[int]$SiteMaxUrlSegments = 120,
	# web.config changes
	$MaxRequestMB = 100,
	$RuntimeExecutionTimeout = 1200,
	$RuntimeRequestLengthDiskThreshold = 90000,
	$RuntimeMaxUrlLength = 5000,
	$RuntimeRelaxedUrlToFileSystemMapping = "true",
	$RuntimeMaxQueryStringLength = 50000,
	$ProviderName = "AspNetSqlMembershipProvider",
	$ProviderEnablePasswordRetrieval = "true",
	$ProviderMinRequiredPasswordLength = 6,
	$ProviderPasswordFormat = "Encrypted"
)
Set-StrictMode -Version latest  # Error Reporting: ALL
#---------------------------------------------------------[Initializations]------------------------------------------------------
 
$ErrorActionPreference = "Stop" # Set Error Action to Stop
$Script:ScriptVersion = "1.0"   # Script Version

#-----------------------------------------------------------[Include]------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -le 2) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Definition -Parent } # powershell 2.0

.  "$PSScriptRoot\Lib-General.ps1"
.  "$PSScriptRoot\Lib-IIS.ps1"
.  "$PSScriptRoot\Lib-Dnn.ps1"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Stopwatch

New-DnnSite -DnnInstallZip $DnnInstallZip -Destination $Destination `
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

Stop-Stopwatch
