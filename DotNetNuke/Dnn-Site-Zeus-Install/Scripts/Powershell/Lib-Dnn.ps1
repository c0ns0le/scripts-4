##requires -version 4
<#
.SYNOPSIS
  	Funciones para instalacion de DotNetNuke
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#-----------------------------------------------------------[Functions]------------------------------------------------------------

#region Invoke REST web services

Function Call-Rest([Parameter(Mandatory=$true)]$Url, $body, $sessionId, $method = "Post", $TimeoutSec = 0, $FailCondition = $null, $FailMessage = $null) {
	# verbose preference (scope: this method)
	$VerbosePreference = "SilentlyContinue" # messages do not appear

	Write-Host (Get-Indented ([Uri] $Url).AbsolutePath)
	$response = $null
	try	{
		$jsonBody = &{ if ($body) { ConvertTo-Json ($body) }}
		$response = Invoke-RestMethod -Method $method -Uri $Url -Body $jsonBody -ContentType 'application/json; charset=UTF-8' -WebSession $sessionId -TimeoutSec $TimeoutSec
	}
	catch {
		if ($_.ErrorDetails) {
			$e = ConvertFrom-Json $_.ErrorDetails
			Write-Warning (Get-Indented $e.Message -ForegroundColor Red)
			Write-Warning (Get-Indented $e.StackTrace -ForegroundColor Red)
		}
		throw
	}

	if ($FailCondition) {
		$failed = & $FailCondition $response
		if ($FailMessage.GetType().Name -eq "ScriptBlock") { $message = & $FailMessage $response }
		else { $message = $FailMessage }
		if ($failed) { throw $message }
	}
	$response
}

#endregion


#region Configure Dnn Site
Function UpdateConfig-DnnSite {
<# UpdateConfig-DnnSite -DnnRootFolder $DnnRootFolder `
	-MaxRequestMB $MaxRequestMB `
	-RuntimeExecutionTimeout $RuntimeExecutionTimeout `
	-RuntimeRequestLengthDiskThreshold $RuntimeRequestLengthDiskThreshold `
	-RuntimeMaxUrlLength $RuntimeMaxUrlLength `
	-RuntimeRelaxedUrlToFileSystemMapping $RuntimeRelaxedUrlToFileSystemMapping `
	-RuntimeMaxQueryStringLength $RuntimeMaxQueryStringLength `
	-ProviderName $ProviderName `
	-ProviderEnablePasswordRetrieval $ProviderEnablePasswordRetrieval `
	-ProviderMinRequiredPasswordLength $ProviderMinRequiredPasswordLength `
	-ProviderPasswordFormat $ProviderPasswordFormat
#>
Param(
[Parameter(Mandatory=$true)]$DnnRootFolder,
$MaxRequestMB,
$RuntimeExecutionTimeout,
$RuntimeRequestLengthDiskThreshold,
$RuntimeMaxUrlLength,
$RuntimeRelaxedUrlToFileSystemMapping,
$RuntimeMaxQueryStringLength,
$ProviderName = "AspNetSqlMembershipProvider",
$ProviderEnablePasswordRetrieval,
$ProviderMinRequiredPasswordLength,
$ProviderPasswordFormat
)
	$webConfig = "$DnnRootFolder\web.config"
	Write-Header "Updating '$webConfig'..."
	
	if ($MaxRequestMB) {
		$maxRequestBytes = [int]$MaxRequestMB * 1MB 	# convert to Bytes
		<# <security>
		       <requestFiltering>
		          <requestLimits maxAllowedContentLength="90000000" />
		       </requestFiltering>
		   </security>
		#>
		Update-ConfigFile -Path $webConfig -NodeXPath "system.webServer/security/requestFiltering/requestLimits" -Attribute "maxAllowedContentLength" -Value $maxRequestBytes
		
		$maxRequestKB = $maxRequestBytes / 1024 # convert to KB
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/httpRuntime" `
						  -Attribute "maxRequestLength" -Value $maxRequestKB
	}
	
	if ($RuntimeExecutionTimeout) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/httpRuntime" `
						  -Attribute "executionTimeout" -Value $RuntimeExecutionTimeout
	}
	if ($RuntimeRequestLengthDiskThreshold) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/httpRuntime" `
						  -Attribute "requestLengthDiskThreshold" -Value $RuntimeRequestLengthDiskThreshold
	}
	if ($RuntimeMaxUrlLength) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/httpRuntime" `
						  -Attribute "maxUrlLength" -Value $RuntimeMaxUrlLength
	}
	if ($RuntimeRelaxedUrlToFileSystemMapping) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/httpRuntime" `
						  -Attribute "relaxedUrlToFileSystemMapping" -Value $RuntimeRelaxedUrlToFileSystemMapping
	}
	if ($RuntimeMaxQueryStringLength) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/httpRuntime" `
						  -Attribute "maxQueryStringLength" -Value $RuntimeMaxQueryStringLength
	}
	
	if ($ProviderName -and $ProviderEnablePasswordRetrieval) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/membership/providers/add[@name='$ProviderName']" `
						  -Attribute "enablePasswordRetrieval" -Value $ProviderEnablePasswordRetrieval
	}
	if ($ProviderName -and $ProviderMinRequiredPasswordLength) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/membership/providers/add[@name='$ProviderName']" `
						  -Attribute "minRequiredPasswordLength" -Value $ProviderMinRequiredPasswordLength
	}
	if ($ProviderName -and $ProviderPasswordFormat) {
		Update-ConfigFile -Path $webConfig -NodeXPath "system.web/membership/providers/add[@name='$ProviderName']" `
						  -Attribute "passwordFormat" -Value $ProviderPasswordFormat
	}
	
	Write-Footer "OK"
}

Function CopyModule-DnnSite {
#CopyModule-DnnSite -DnnRootFolder $DnnRootFolder -ExtraModulesFolder $ExtraModulesFolder
Param(
[Parameter(Mandatory=$true)]$DnnRootFolder,
[Parameter(Mandatory=$true)]$ExtraModulesFolder
)
	Write-Header "Copying extra modules to install..."
	
	if (!$ExtraModulesFolder -or !(Test-Path $ExtraModulesFolder -PathType Container)) {
		Write-Footer "OK (Not found)"
		return
	}
	
	$Destination = "$dnnRootFolder\Install\Module"

	# expand wildcards (Ej: *.zip)
	$files = Get-ChildItem "$ExtraModulesFolder\*.zip" | Select -ExpandProperty FullName
	Write-Indented "Modules found: $($files.Count)"
	foreach ($file in $files) {
		$targetFile = Join-Path $Destination (Split-Path $file -Leaf)
		Write-Indented $targetFile
		# overwrite if found
		Copy-Item $file $targetFile -Force -Recurse
	}
	Write-Footer "OK"
}

Function Unzip-DnnSite {
#Unzip-DnnSite -DnnInstallZip $DnnInstallZip -Destination $Destination -Force 1
Param(
[Parameter(Mandatory=$true)][string]$DnnInstallZip,
[Parameter(Mandatory=$true)][string]$Destination,
[bool]$Force = 0
)
	Write-Header "Extracting Dnn Site..."
	
	# files to exclude by default from dnn zip file
	$Exclude = @("App_Data\Database.mdf")
	
	# re-create site folder
	if (Test-Path $Destination -PathType Container) {
		if ($Force) { Delete-Folder $Destination }
		else { throw "Destination folder exists: '$Destination'. If you want to drop and create it again, Set the parameter -Force 1." }
	}
	
	# unblock file if it was download from internet (function does not exist on powershell 2.0)
	try { Unblock-File $DnnInstallZip } catch { Write-Warning "[Unblock-File] " + $_.Exception.Message }
	
	# unzip all dnn files to target folder (create target folder by default)
	Extract-ZipFile -ZipFile $DnnInstallZip -Destination $Destination -Exclude $Exclude
	
	Write-Footer "OK"
}
#endregion Configure Dnn Site


#region Create/Install Dnn Site
Function New-DnnSite {
<# New-DnnSite -DnnInstallZip $DnnInstallZip -Destination $Destination `
    -ExtraModulesFolder $ExtraModulesFolder `
    -Force $Force `
	# App Pool
    -AppPoolName $AppPoolName `
    -AppPoolUserName $AppPoolUserName `
    -AppPoolPassword $AppPoolPassword `
    -AppPoolEnable32BitAppOnWin64 $AppPoolEnable32BitAppOnWin64 `
	# Web Site
    -SiteName $SiteName `
    -SiteAlias $SiteAlias `
    -SitePort $SitePort `
    -SiteMaxUrlSegments $SiteMaxUrlSegments `
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
    -ProviderPasswordFormat $ProviderPasswordFormat
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
[int]$AppPoolEnable32BitAppOnWin64,
# Web Site
[Parameter(Mandatory=$true)][string]$SiteName, 
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
	Write-Header "Creating Dnn Site..."
	[bool]$AppPoolEnable32BitAppOnWin64 = $AppPoolEnable32BitAppOnWin64 -eq "1"
	
	# delete site and re-create
	if (Test-Site $siteName) { 
		if ($Force) { Remove-Site $siteName }
		else { throw "Site '$siteName' already exists. If you want to drop and create it again, Set the parameter Web.Site.DropAndCreate='1'." }
	}
	
	# unzip dnn files
	Unzip-DnnSite -DnnInstallZip $DnnInstallZip -Destination $Destination -Force $Force
	
	#copy extra modules to install along with dnn
	CopyModule-DnnSite -DnnRootFolder $Destination -ExtraModulesFolder $ExtraModulesFolder
	
	# update web-config
	UpdateConfig-DnnSite -DnnRootFolder $Destination `
		-MaxRequestMB $MaxRequestMB `
		-RuntimeExecutionTimeout $RuntimeExecutionTimeout `
		-RuntimeRequestLengthDiskThreshold $RuntimeRequestLengthDiskThreshold `
		-RuntimeMaxUrlLength $RuntimeMaxUrlLength `
		-RuntimeRelaxedUrlToFileSystemMapping $RuntimeRelaxedUrlToFileSystemMapping `
		-RuntimeMaxQueryStringLength $RuntimeMaxQueryStringLength `
		-ProviderName $ProviderName `
		-ProviderEnablePasswordRetrieval $ProviderEnablePasswordRetrieval `
		-ProviderMinRequiredPasswordLength $ProviderMinRequiredPasswordLength `
		-ProviderPasswordFormat $ProviderPasswordFormat

	# create web site on IIS
	New-AppPool -Name $AppPoolName -UserName $AppPoolUserName -Password $AppPoolPassword -Enable32BitAppOnWin64 $AppPoolEnable32BitAppOnWin64
	New-Site -Name $SiteName -PhysicalPath $Destination -AppPoolName $AppPoolName -Alias $SiteAlias -Port $SitePort -MaxUrlSegments $SiteMaxUrlSegments
	
	Write-Footer "OK"
}

Function InstallWizard-DnnSite {
<# InstallWizard-DnnSite -DnnRootUrl $DnnRootUrl `
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
#>
Param(
[Parameter(Mandatory=$true)][string]$DnnRootUrl,
[Parameter(Mandatory=$true)][string]$DnnUsername = "host",
[Parameter(Mandatory=$true)][string]$DnnPassword = 'abc123$',
[Parameter(Mandatory=$true)][string]$DnnEmail = "host@change.me",
[Parameter(Mandatory=$true)][string]$DnnDatabaseServerName,
[Parameter(Mandatory=$true)][string]$DnnDatabaseName,
[string]$DnnDatabaseObjectQualifier = "dnn_",
[string]$DnnDatabaseUsername,
[string]$DnnDatabasePassword,
[string]$DnnWebsiteTitle = "My Blank Website",
[string]$DnnTemplate = "Blank Website.template",
[string]$DnnLanguage = "es-ES"
)
	# validations *************************************
	# if site port is default, remove it
	$DnnRootUrl = $DnnRootUrl -replace ':80$', ''

	Write-Header "Invoking Install Wizard ($dnnRootUrl)..."
	$installUrl = "$dnnRootUrl/Install/InstallWizard.aspx"
	# agent: Chrome 48.0.2564.116
	$UserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.116 Safari/537.36"

	# ignore ssl-certificates
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

	Write-Indented ([Uri] $installUrl).AbsolutePath
	# -UseBasicParsing: if you don't need the html returned to be parsed into different objects (it is a bit quicker).
	$r = Invoke-WebRequest -Uri $installUrl -SessionVariable sessionId -UseBasicParsing -UserAgent $UserAgent -TimeoutSec 600
	Write-Indented "$($r.StatusCode): $($r.StatusDescription)"
	if ($r.StatusCode -ne 200) { throw "Página de instalación DNN no responde: $installUrl" }

	# headers
	$uri = [Uri]$installUrl
	$origin = $uri.AbsoluteUri.Replace($uri.AbsolutePath, "")
	$sessionId.Headers.Add("Host", $uri.Host)
	$sessionId.Headers.Add("Origin", $origin)
	$sessionId.Headers.Add("Accept", "*/*")
	$sessionId.Headers.Add("Accept-Encoding", "gzip, deflate")
	$sessionId.Headers.Add("Referer", $installUrl)
	$sessionId.Headers.Add("Accept-Language", "es")
	$sessionId.Headers.Add("X-Requested-With", "XMLHttpRequest")

	$ErrorScriptBlock = { 
		Param($response)
		"ERROR: {0}" -f (Html-ToText $response.d.Item2)
	}
	
	
	# response: {"d":false}
	$r = Call-Rest "$installUrl/IsInstallerRunning" $null $sessionId -FailCondition { Param($r) $r.d } -FailMessage "Dnn Installer is already running"
	# response: {"d":true}
	$r = Call-Rest "$installUrl/VerifyDatabaseConnectionOnLoad" $null $sessionId
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/ValidatePermissions" $null $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage $ErrorScriptBlock
	
	# parameters w/ default values
	$DnnDatabaseType = "server"
	$DnnDatabaseFilename = ""
	$DnnDatabaseSetup = "advanced"
	$DnnDatabaseSecurity = if ($DnnDatabaseUsername) { "userDefined" } else { "integrated" }
	$DnnDatabaseRunAsOwner = "on"
	# build request
	$body = @{ "installInfo" = 
				@{  "username" = $DnnUsername
					"password" = $DnnPassword
					"confirmPassword" = $DnnPassword
					"email" = $DnnEmail
					"websiteName" = $DnnWebsiteTitle
					"template" = $DnnTemplate
					"language" = $DnnLanguage
					"threadCulture" = $DnnLanguage
					"databaseSetup" = $DnnDatabaseSetup
					"databaseServerName" = $DnnDatabaseServerName
					"databaseFilename" = $DnnDatabaseFilename
					"databaseType" = $DnnDatabaseType
					"databaseName" = $DnnDatabaseName
					"databaseObjectQualifier" = $DnnDatabaseObjectQualifier
					"databaseSecurity" = $DnnDatabaseSecurity
					"databaseUsername" = $DnnDatabaseUsername
					"databasePassword" = $DnnDatabasePassword
					"databaseRunAsOwner" = $DnnDatabaseRunAsOwner
				}
			}
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/ValidateInput" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage $ErrorScriptBlock
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/VerifyDatabaseConnection" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage $ErrorScriptBlock

	$sessionId.Headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
	$sessionId.Headers["Accept-Encoding"] = "gzip, deflate, sdch"
	$sessionId.Headers.Remove("X-Requested-With") | Out-Null
	#
	$r = Invoke-WebRequest -Uri "$($installUrl)?culture=es-ES&initiateinstall" -WebSession $sessionId -UseBasicParsing
	Write-Indented "$($r.StatusCode): $($r.StatusDescription)"
	
	$sessionId.Headers.Add("X-Requested-With", "XMLHttpRequest")
	$sessionId.Headers["Accept"] = "*/*"
	$sessionId.Headers["Referer"] = "$($installUrl)?culture=es-ES&executeinstall"
	
	# invoke installation
	# WARNING: by default, it blocks until installation finished. It is force to return control after 3 sec
	try {
		$r = Call-Rest "$installUrl/RunInstall" $null $sessionId -TimeoutSec 3
		Write-Indented "$($r.StatusCode): $($r.StatusDescription)"
	}
	catch {
		Write-Indented "WARNING: Intentionally timing out request to check installation progress..."
		Write-Indented "$($_.Exception.GetType().Name): $($_.Exception.Message)"
	}
	
	# check progress
	$sessionId.Headers.Remove("X-Requested-With") | Out-Null
	$sessionId.Headers.Remove("Origin") | Out-Null

	$lastProgress = 0
	do {
		# WARNING: Windows goes On Top and also shows a dialog window which is hidden immediately
		Start-Sleep -Seconds 15

		# check for progress detail
		$uniqueArgument = "0.{0}" -f [DateTime]::Now.Ticks
		$progressUrl = "$dnnRootUrl/Install/installstat.log.resources.txt?$uniqueArgument"
		$response = Invoke-WebRequest -Uri $progressUrl -WebSession $sessionId -UseBasicParsing
		# parse response
		$r = $response.Content
		if (-not $r.Length) {
			if ($lastProgress -eq 0) {
				Write-Indented "No progress is reported back"
				break
			}
			else { continue }
		}
		# fix encoding
		$r = [Text.Encoding]::UTF8.GetString([Text.Encoding]::Default.GetBytes($r))
		# read last line
		$ar = $r.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)
		# convert to json-like object
		$json = ConvertFrom-Json $ar[$ar.Length - 1]
		# show progress
		if ($lastProgress -eq $json.progress -and $lastMessage -eq $json.details) { continue }
		$lastProgress = $json.progress
		$lastMessage = $json.details
		Write-Indented "$lastProgress%: $lastMessage"
		
		# {"progress":63,"details":"Crear el superusuario","check0":"Done","check1":"Done","check2":"Done","check3":"Done","check4":"Running","check5":"NotStarted"}
		# if ($json.check3 -eq "Done") { break }
		
		# break when progress = 100%
	} while ($lastProgress -lt 100)


	#-------------
	Write-Indented "Esperando que el Sitio Cargue (Post-Instalación)..."

	# -UseBasicParsing: if you don't need the html returned to be parsed into different objects (it is a bit quicker).
	# WARNING: timeout infinito
	$r = Invoke-WebRequest -Uri $dnnRootUrl -SessionVariable sessionId -UseBasicParsing -UserAgent $UserAgent -TimeoutSec 0
	Write-Indented "$($r.StatusCode): $($r.StatusDescription)"
	if ($r.StatusCode -ne 200) { throw "Sitio DNN no responde: $dnnRootUrl" }

	Write-Footer "OK"
}
#endregion Create/Install Dnn Site

