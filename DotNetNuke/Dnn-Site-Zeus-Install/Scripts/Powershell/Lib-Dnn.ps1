##requires -version 4
<#
.SYNOPSIS
  	Funciones para instalacion de DotNetNuke
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#-----------------------------------------------------------[Functions]------------------------------------------------------------

#region Invoke REST web services


#endregion


#region Configure Dnn Site
Function FixUrl-DnnSite {
Param(
[Parameter(Mandatory=$true)][string]$Url
)
	# if site port is default, remove it
	$Url = $Url -replace ':80$', ''
	# add http if no protocol specified
	if (-not ($Url -match '://')) { $Url = "http://$Url" }
	return $Url
}

Function UpdateConfig-DnnSite {
<# UpdateConfig-DnnSite -RootFolder $RootFolder `
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
[Parameter(Mandatory=$true)]$RootFolder,
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
	$webConfig = "$RootFolder\web.config"
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
#CopyModule-DnnSite -RootFolder $RootFolder -ExtraModulesFolder $ExtraModulesFolder
Param(
[Parameter(Mandatory=$true)][string]$RootFolder,
[Parameter(Mandatory=$true)][string[]]$ExtraModulesFolder
)
	Write-Header "Copiando módulos adicionales al subfolder install..."
	
	foreach ($Path in $ExtraModulesFolder) {
		if (!$Path -or !(Test-Path $Path -PathType Container)) {
			Write-Footer "OK (Not found)"
			return
		}
		
		$Destination = "$RootFolder\Install\Module"

		# expand wildcards (Ej: *.zip)
		$files = Get-ChildItem "$Path\*.zip" | Select -ExpandProperty FullName
		$fileCount = if ($files -is [Array]) { $files.Count } elseif ($files -is [string]) { 1 } else { 0 }
		Write-Indented "Modules found: $fileCount"
		foreach ($file in $files) {
			$targetFile = Join-Path $Destination (Split-Path $file -Leaf)
			Write-Indented $targetFile
			# overwrite if found
			Copy-Item $file $targetFile -Force -Recurse
		}
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
    -SiteIPAddress $SiteIPAddress `
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
	if ($ExtraModulesFolder) {
		CopyModule-DnnSite -RootFolder $Destination -ExtraModulesFolder $ExtraModulesFolder
	}
	
	# update web-config
	UpdateConfig-DnnSite -RootFolder $Destination `
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
    New-Site -Name $SiteName -PhysicalPath $Destination -AppPoolName $AppPoolName -IPAddress $SiteIPAddress -Alias $SiteAlias  -Port $SitePort -MaxUrlSegments $SiteMaxUrlSegments
	
	Write-Footer "OK"
}

Function InstallWizard-DnnSite {
<# InstallWizard-DnnSite -RootUrl $DnnRootUrl `
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
[Parameter(Mandatory=$true)][string]$RootUrl,
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
	$RootUrl = FixUrl-DnnSite $RootUrl

	Write-Header "Invoking Install Wizard ($RootUrl)..."
	$installUrl = "$RootUrl/Install/InstallWizard.aspx"

	# ignore ssl-certificates
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

	Write-Indented ([Uri] $installUrl).AbsolutePath
	# -UseBasicParsing: if you don't need the html returned to be parsed into different objects (it is a bit quicker).
	$r = Invoke-WebRequest -Uri $installUrl -SessionVariable sessionId -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -UseBasicParsing -TimeoutSec (2 * 60 * 60)
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
	$r = Invoke-HttpRest "$installUrl/IsInstallerRunning" $null $sessionId -FailCondition { Param($r) $r.d } -FailMessage "Dnn Installer is already running"
	# response: {"d":true}
	$r = Invoke-HttpRest "$installUrl/VerifyDatabaseConnectionOnLoad" $null $sessionId
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Invoke-HttpRest "$installUrl/ValidatePermissions" $null $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage $ErrorScriptBlock
	
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
	$r = Invoke-HttpRest "$installUrl/ValidateInput" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage $ErrorScriptBlock
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Invoke-HttpRest "$installUrl/VerifyDatabaseConnection" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage $ErrorScriptBlock

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
		$r = Invoke-HttpRest "$installUrl/RunInstall" $null $sessionId -TimeoutSec 3
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
		$progressUrl = "$RootUrl/Install/installstat.log.resources.txt?$uniqueArgument"
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
	Write-Footer "OK"

	Invoke-WebPage $RootUrl # espera que carge
}


Function InstallModules-DnnSite {
#InstallModules-DnnSite -Path $ExtraModulesFolder -RootUrl $DnnRootUrl -RootFolder $DnnRootFolder
Param(
[Parameter(Mandatory=$true)][string[]]$Path,
[Parameter(Mandatory=$true)][string]$RootUrl,
[Parameter(Mandatory=$true)][string]$RootFolder,
[Switch]$WaitToReload = $false
)
	Write-Header "Instalando Modules Adicionales"
	$RootUrl = FixUrl-DnnSite $RootUrl
	
	# copy modules to dnn install folder
	CopyModule-DnnSite -RootFolder $RootFolder -ExtraModulesFolder $Path
	
	$dnnInstallResourcesUrl = "$RootUrl/Install/Install.aspx?mode=installresources"
	# wait for installation to finish
	Invoke-WebPage $dnnInstallResourcesUrl
	
	# wait for web site to reload (by calling home page)
	if ($WaitToReload) {
		Invoke-WebPage $RootUrl
	}
	Write-Footer "OK"
}


Function Wait-DnnSite {
#Wait-DnnSite -RootUrl $DnnRootUrl
Param(
[Parameter(Mandatory=$true)][string]$RootUrl
)
	Write-Header "Esperando Que el Sitio Cargue"
	$RootUrl = FixUrl-DnnSite $RootUrl
	Invoke-WebPage $RootUrl
	Write-Footer "OK"
}
#endregion Create/Install Dnn Site

