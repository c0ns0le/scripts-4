#requires -version 4
<#
.SYNOPSIS
  Enter description here
.EXAMPLES
robocopy C:\inetpub\dnn800_orig C:\inetpub\dnn800 /MIR
iisreset & robocopy C:\inetpub\dnn800_orig C:\inetpub\dnn800 /MIR
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#region Functions
#-----------------------------------------------------------[Functions]------------------------------------------------------------

#region Utilities
Function Write-Header($Text) { Write-Host $Text -ForegroundColor DarkBlue }
Function Write-Footer($Text) { Write-Host $Text -ForegroundColor DarkGreen }

Function Call-Rest($Url, $body, $sessionId, $method = "Post", $TimeoutSec = 0, $FailCondition = $null, $FailMessage = $null) {
	Write-Host ([Uri] $Url).AbsolutePath
	$response = $null
	try	{
		$jsonBody = &{ if ($body) { ConvertTo-Json ($body) }}
		$response = Invoke-RestMethod -Method $method -Uri $Url -Body $jsonBody -ContentType 'application/json; charset=UTF-8' -WebSession $sessionId -TimeoutSec $TimeoutSec
	}
	catch {
		if ($_.ErrorDetails) {
			$e = ConvertFrom-Json $_.ErrorDetails
			Write-Host $e.Message -ForegroundColor Red
			Write-Host $e.StackTrace -ForegroundColor Red
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

Function Load-Settings($configPath = "$PSScriptRoot\dnn.installer.config") {
	$Script:appSettings = @{}

	$config = (Get-Content $configPath) -as [Xml]
	
	foreach ($node in $config.configuration.appSettings.add) {
		$key, $value = $node.key, $node.value
	
		# csv values are tranformed to an array
		if ($value -contains ',') {
			# remove blanks around separator
	  		$value = $value -replace " *, *", ","
			# transform to an array
			$value = $value.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries)
	 	}

		$parent = $Script:appSettings

		# expand key - each period (.) denotes a parent key
		$keys = $key -split '\.'
		if ($keys.Length -eq 1) {
			$lastkey = $key
		}
		else {
			$parentkeys = $keys[0..($keys.Length-2)]
			$lastkey = $keys[($keys.Length-1)]
			
			foreach ($item in $parentkeys) {
				if (-not $parent.$item) { $parent.$item = @{} }
				elseif ($parent.$item.GetType().Name -ne "Hashtable") {
					$text =  $parent.$item
					$parent.$item = @{}
					$parent.$item.Text = $text
				}
				$parent = $parent.$item
			}
		}
		
		$parent.$lastkey = $value
	}
	
	# meta-variables substitution
	$vars = $Script:appSettings.MetaVariables
	$vars.DnnDatabase = $vars.DnnDatabase.Replace("{DnnAlias}", $vars.DnnAlias)
	
	$Script:appSettings.Source.DnnInstallZip = $Script:appSettings.Source.DnnInstallZip.Replace("{DnnSourceRoot}", $vars.DnnSourceRoot)
	$Script:appSettings.Source.DnnExtraModules = $Script:appSettings.Source.DnnExtraModules.Replace("{DnnSourceRoot}", $vars.DnnSourceRoot)
	
	$Script:appSettings.Web.RootFolder = $Script:appSettings.Web.RootFolder.Replace("{DnnAlias}", $vars.DnnAlias)
	$Script:appSettings.Web.RootUrl = $Script:appSettings.Web.RootUrl.Replace("{DnnAlias}", $vars.DnnAlias)
	$Script:appSettings.Web.AppPool.Name = $Script:appSettings.Web.AppPool.Name.Replace("{DnnAlias}", $vars.DnnAlias)
	
	$Script:appSettings.Database.Name = $Script:appSettings.Database.Name.Replace("{DnnDatabase}", $vars.DnnDatabase)
	$Script:appSettings.Dnn.installInfo.databaseName = $Script:appSettings.Dnn.installInfo.databaseName.Replace("{DnnDatabase}", $vars.DnnDatabase)

	# expand path to last-item matching search expression
	$Script:appSettings.Source.DnnInstallZip = Get-ChildItem $Script:appSettings.Source.DnnInstallZip | Select -ExpandProperty FullName -Last 1
	$Script:appSettings.Source.DnnDeployer = Get-ChildItem $Script:appSettings.Source.DnnDeployer | Select -ExpandProperty FullName -Last 1
}
#WARNING: Uncomment for testing
#cls; Load-Settings; ConvertTo-Json $Script:appSettings; exit

Function Set-FullAccess($physicalPath, $userName) {
	Write-Header "Granting full access to '$userName' on '$physicalPath'..."
	$ArgList = "`"$physicalPath`"", "/grant", "`"$userName`":(OI)(CI)(F)", "/T", "/Q", "/C"
	#Write-Host "icacls.exe $ArgList"
	$cmdOutput = icacls.exe $ArgList
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	Write-Footer "OK"
}

Function Set-Alias7z {
	# check 7-zip alias
	$sevenZip = "C:\Program Files\7-Zip\7z.exe"
	if (-not (Test-Path $sevenZip)) {
		"Installing 7-Zip...."
		cinst 7zip -y
		# WARNING: Consider using 7-zip Portable to deal with issues on Installation Permissions: cinst 7zip.commandline -y
	}
	Set-Alias -Name 7z -Value $sevenZip -Scope Script
}

Function Unzip-File($zipFile, $targetFolder) {
	Write-Header "Extracting files to '$targetFolder'..."
	
	# create target folder if not exists
	#if (-not (Test-Path $targetFolder -PathType Container)) { md $targetFolder | Out-Null }
	
	# unzip file
	# Examplo: 7z x archive.zip -oc:\soft *.cpp -r -y
	$ArgList = @("x", 				# Extracts with full paths
				$zipFile, 			# zip file
				"-o$targetFolder",  # destination folder
				"*", 				# file to extract
				"-r"				# recursive
				"-y"				# overwrite existing files on destination
				)
	# Write-Host "7z $ArgList"
	$cmdOutput = 7z $ArgList
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	Write-Footer "OK"
}

Function Update-WebConfig($configFile, $rootXPath, $attrName, $attrValue) {
	$doc = (Get-Content $configFile) -as [Xml]
	$root = $doc.DocumentElement

	$names = $rootXPath -split '/'
	$node = $root
	foreach ($name in $names) {
		if ($node.$name) { $node = $node.$name -As [Xml.XmlElement] }
		else {
			$isDirty = $true
			$item = $doc.CreateElement($name)
			$node = $node.AppendChild($item)
		}
	}

	if ($attrName) { 
		$currentValue = $node.$attrName
		$attrValue = "$attrValue"
		
		if ($currentValue -eq $null) { 
			$isDirty = $true
			$node.setAttribute($attrName, $attrValue)
		}
		elseif ($currentValue -ne $attrValue) { 
			$isDirty = $true
			$node.$attrName = $attrValue
		}
	}

	if ($attrName) {
		"{0}/@{1}: '{2}' [{3}]" -f $rootXPath, $attrName, $attrValue, (&{if ($isDirty) {"UPDATED"} else {"UNCHANGED"}})
	}
	else {
		"{0}: '{1}' [{2}]" -f $rootXPath, $attrValue, (&{if ($isDirty) {"UPDATED"} else {"UNCHANGED"}})
	}
	if ($isDirty) { $doc.Save($configFile) }
}
#endregion

#region Database
Function Get-SqlServerProperty($name) {
	$query = "PRINT CONVERT(varchar(128), ServerProperty('$name'));"
	$result = Run-Sql $query $Script:appSettings.Database -UseDefaultDatabase
	if ($result -match '\\$') { $result = $result -replace '\\$','' } 
	$result
}
Function Get-SqlServerDefaultDataPath { Get-SqlServerProperty "InstanceDefaultDataPath" }
Function Get-SqlServerDefaultLogPath { Get-SqlServerProperty "InstanceDefaultLogPath" }

Function Run-Sql($SqlScript, [Hashtable]$appSettingsDatabase, [Switch]$UseDefaultDatabase = $false, [Switch]$EchoInput = $false) {
	$SqlScript = "SET NOCOUNT ON;`r`nGO`r`n$SqlScript"
	
	$scriptFile = [System.IO.Path]::GetTempFileName()
	Set-Content -Path $scriptFile -Value $SqlScript -Encoding UTF8
	try {
		$ArgList = @("-S", $appSettingsDatabase.Server, 
					 "-W",			# -W: remove trailing spaces
					 "-h", "-1", 	# -h -1: no header
					 "-b"			# -b: On error batch abort
					 )
		if (-not $UseMaster) {
			$ArgList += "-d", $appSettingsDatabase.Name 			# -d use database name
		}
		if ($appSettingsDatabase.AdminUser) {
			$ArgList += "-U", $appSettingsDatabase.AdminUser, 		# -U login id
						"-P", $appSettingsDatabase.AdminPassword 	# -P password
		}
		else { 
			$ArgList += "-E" 			# -E: trusted connection
		}
		# echo input commands
		if ($EchoInput) { $ArgList += "-e" }
		# input file
		$ArgList += "-i", $scriptFile
		
		# Write-Host "sqlcmd.exe $ArgList"
		$response = sqlcmd.exe $ArgList
		$response
		if ($LASTEXITCODE -ne 0) { throw "ERROR while running SQL Script" }
	}
	finally { Remove-Item -Path $scriptFile -Force -ErrorAction SilentlyContinue }
}

Function Drop-Database([Hashtable]$appSettingsDatabase) {
	$dbName = $appSettingsDatabase.Name
	$query = @"
USE master
GO
PRINT 'Deleting backup history...'
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$dbName'
GO
PRINT 'SET SINGLE_USER...'
ALTER DATABASE [$dbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
PRINT 'Dropping database...'
DROP DATABASE [$dbName]
GO
PRINT 'OK'
GO
"@
	Write-Header "Dropping Database '$dbName'..."
	Run-Sql $query $appSettingsDatabase -UseDefaultDatabase
}

Function Exist-Database([Hashtable]$appSettingsDatabase) {
	$dbName = $appSettingsDatabase.Name
	$query = "SELECT DB_ID('$dbName')"
	$id = Run-Sql $query $appSettingsDatabase -UseDefaultDatabase
	$id -match "[0-9]+"
}

Function Create-Database([Hashtable]$appSettingsDatabase) {
	$dbName = $appSettingsDatabase.Name
	$DropIfExists = $appSettingsDatabase.DropIfExists -eq "1"
	$RecoveryMode = $appSettingsDatabase.RecoveryMode
	
	if (Exist-Database $appSettingsDatabase) {
		if (-not $DropIfExists) { throw "Database '$dbName' already exists. Set DropIfExists = '1' if you want to drop it and recreate it." }
		Drop-Database $appSettingsDatabase
	}
	
	$dataPath = &{ if ($appSettingsDatabase.DataPath) {$appSettingsDatabase.DataPath} else {Get-SqlServerDefaultDataPath} }
	$logPath  = &{ if ($appSettingsDatabase.LogPath ) {$appSettingsDatabase.LogPath } else {Get-SqlServerDefaultLogPath } }
	
	Write-Header "Creating Database '$dbName'..."
	$query = @"
PRINT 'Creating database...'
CREATE DATABASE [$dbName]
	CONTAINMENT = NONE
	ON PRIMARY (NAME = N'$dbName',     FILENAME = N'$dataPath\$dbName.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
	LOG ON     (NAME = N'$($dbName)_log', FILENAME = N'$logPath\$($dbName)_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)
GO
--ALTER DATABASE [$dbName] SET COMPATIBILITY_LEVEL = 120;
--GO
PRINT 'SET ANSI_NULL_DEFAULT OFF';
ALTER DATABASE [$dbName] SET ANSI_NULL_DEFAULT OFF;
GO
PRINT 'SET ANSI_NULLS OFF';
ALTER DATABASE [$dbName] SET ANSI_NULLS OFF;
GO
PRINT 'SET ANSI_PADDING OFF';
ALTER DATABASE [$dbName] SET ANSI_PADDING OFF;
GO
PRINT 'SET ANSI_WARNINGS OFF';
ALTER DATABASE [$dbName] SET ANSI_WARNINGS OFF;
GO
PRINT 'SET ARITHABORT OFF';
ALTER DATABASE [$dbName] SET ARITHABORT OFF;
GO
PRINT 'SET AUTO_CLOSE OFF';
ALTER DATABASE [$dbName] SET AUTO_CLOSE OFF;
GO
PRINT 'SET AUTO_SHRINK OFF';
ALTER DATABASE [$dbName] SET AUTO_SHRINK OFF;
GO
PRINT 'SET AUTO_CREATE_STATISTICS ON';
ALTER DATABASE [$dbName] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF);
GO
PRINT 'SET AUTO_UPDATE_STATISTICS ON';
ALTER DATABASE [$dbName] SET AUTO_UPDATE_STATISTICS ON;
GO
PRINT 'SET CURSOR_CLOSE_ON_COMMIT OFF';
ALTER DATABASE [$dbName] SET CURSOR_CLOSE_ON_COMMIT OFF;
GO
PRINT 'SET CURSOR_DEFAULT GLOBAL';
ALTER DATABASE [$dbName] SET CURSOR_DEFAULT GLOBAL;
GO
PRINT 'SET CONCAT_NULL_YIELDS_NULL OFF';
ALTER DATABASE [$dbName] SET CONCAT_NULL_YIELDS_NULL OFF;
GO
PRINT 'SET NUMERIC_ROUNDABORT OFF';
ALTER DATABASE [$dbName] SET NUMERIC_ROUNDABORT OFF;
GO
PRINT 'SET QUOTED_IDENTIFIER OFF';
ALTER DATABASE [$dbName] SET QUOTED_IDENTIFIER OFF;
GO
PRINT 'SET RECURSIVE_TRIGGERS OFF';
ALTER DATABASE [$dbName] SET RECURSIVE_TRIGGERS OFF;
GO
PRINT 'SET DISABLE_BROKER';
ALTER DATABASE [$dbName] SET DISABLE_BROKER;
GO
PRINT 'SET AUTO_UPDATE_STATISTICS_ASYNC OFF';
ALTER DATABASE [$dbName] SET AUTO_UPDATE_STATISTICS_ASYNC OFF;
GO
PRINT 'SET DATE_CORRELATION_OPTIMIZATION OFF';
ALTER DATABASE [$dbName] SET DATE_CORRELATION_OPTIMIZATION OFF;
GO
PRINT 'SET PARAMETERIZATION SIMPLE';
ALTER DATABASE [$dbName] SET PARAMETERIZATION SIMPLE;
GO
PRINT 'SET READ_COMMITTED_SNAPSHOT OFF';
ALTER DATABASE [$dbName] SET READ_COMMITTED_SNAPSHOT OFF;
GO
PRINT 'SET READ_WRITE';
ALTER DATABASE [$dbName] SET READ_WRITE;
GO
PRINT 'SET RECOVERY $RecoveryMode';
ALTER DATABASE [$dbName] SET RECOVERY $RecoveryMode;
GO
PRINT 'SET MULTI_USER';
ALTER DATABASE [$dbName] SET MULTI_USER;
GO
PRINT 'SET PAGE_VERIFY';
ALTER DATABASE [$dbName] SET PAGE_VERIFY CHECKSUM;
GO
PRINT 'SET TARGET_RECOVERY_TIME = 0 SECONDS';
ALTER DATABASE [$dbName] SET TARGET_RECOVERY_TIME = 0 SECONDS;
GO
PRINT 'SET DELAYED_DURABILITY = DISABLED';
ALTER DATABASE [$dbName] SET DELAYED_DURABILITY = DISABLED;
GO
PRINT 'USE [$dbName]';
USE [$dbName]
GO
PRINT 'MODIFY FILEGROUP PRIMARY';
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [$dbName] MODIFY FILEGROUP [PRIMARY] DEFAULT;
GO
PRINT 'OK';
"@

	Run-Sql $query -UseDefaultDatabase
}
#endregion

#region Web Site
Function Set-AliasAppCmd {
	$appcmdPath = "$env:SystemRoot\system32\inetsrv\appcmd.exe"
	if (-not (Test-Path $appcmdPath)) { throw "Cannot find '$appcmdPath'" }
	Set-Alias appcmd -Value $appcmdPath -Scope Script
}

Function Create-AppPool($poolName, $user, $pwd) {
	Write-Header "Create App Pool $poolName"
	$cmdOutput = appcmd add apppool /name:"$poolName" /managedRuntimeVersion:v4.0 /enable32BitAppOnWin64:true /processModel.identityType:SpecificUser /processModel.userName:"$user" /processModel.password:"$pwd"
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	
	# small delay so that it creates built-in user
	Start-Sleep -Milliseconds 3000
	# set permissions
	Set-FullAccess "$env:SystemRoot\Temp" "IIS AppPool\$poolName"
	Set-FullAccess "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files" "IIS AppPool\$poolName"
	Set-FullAccess "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files" "IIS AppPool\$poolName"
}

Function Create-WebSite($siteName, $physicalPath, $poolName, $siteAlias, $sitePort = 80) {
	if ($poolName -eq $null) { $poolName = $siteName }
	if ($siteAlias -eq $null) { $siteAlias = $siteName }
	
	Write-Header "Create Site $siteName"
	$cmdOutput = appcmd add site /name:"$siteName" ("/bindings:http/*:{0}:{1}" -f $sitePort,$siteAlias) /physicalPath:"$physicalPath" /applicationDefaults.applicationPool:"$poolName"
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	
	Write-Header "Enabling Anonymous Authentication, Disable Windows Authentication..."
	$cmdOutput = appcmd set config "$siteName" /section:anonymousAuthentication /enabled:true /commit:apphost
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	$cmdOutput = appcmd set config "$siteName" /section:windowsAuthentication /enabled:false /commit:apphost
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }

	Set-FullAccess $physicalPath "IIS AppPool\$poolName"
	
	Write-Header "maxUrlSegments:120"
	$cmdOutput = appcmd set site $siteName /limits.maxUrlSegments:120
	# WARNING: might fail on Windows 7
	#if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
}
#endregion

#region Install DNN
Function Install-Dnn($dnnRootUrl, $appSettingsDnn) {
	Write-Header "Installing DotNetNuke..."
	$installUrl = "$dnnRootUrl/Install/InstallWizard.aspx"
	# agent: Chrome 48.0.2564.116
	$UserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.116 Safari/537.36"

	Write-Host ([Uri] $installUrl).AbsolutePath
	# -UseBasicParsing: if you don't need the html returned to be parsed into different objects (it is a bit quicker).
	$r = Invoke-WebRequest -Uri $installUrl -SessionVariable sessionId -UseBasicParsing -UserAgent $UserAgent
	"$($r.StatusCode): $($r.StatusDescription)"
	if ($r.StatusCode -ne 200) { throw "Install page is not responding. Check DNN is not installed already" }

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

	# response: {"d":false}
	$r = Call-Rest "$installUrl/IsInstallerRunning" $null $sessionId -FailCondition { Param($r) $r.d } -FailMessage "Dnn Installer is already running"
	# response: {"d":true}
	$r = Call-Rest "$installUrl/VerifyDatabaseConnectionOnLoad" $null $sessionId
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/ValidatePermissions" $null $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage { Param($r) "ERROR: $($r.d.Item2)" }
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/ValidateInput" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage { Param($r) "ERROR: $($r.d.Item2)" }

	$body = $appSettingsDnn
	<#$body = @{"installInfo" = @{
						"username" = "host"; "password" = "abc123$"; "confirmPassword" = "abc123$"; "email" = "host@change.me"; 
						"websiteName" = "My Blank Website"; 
						#"template" = "Default Website.template"; 
						"template" = "Blank Website.template"; 
						"language" = "es-ES"; 
						"threadCulture" = "es-ES"; 
						"databaseSetup" = "advanced"; "databaseServerName" = ".\SQLExpress"; "databaseFilename" = "Database.mdf"; 
						"databaseType" = "server"; "databaseName" = "dnn800"; 
						"databaseObjectQualifier" = "dnn_"; 
						"databaseSecurity" = "integrated"; "databaseUsername" = ""; "databasePassword" = ""; "databaseRunAsOwner" = "on"}}
	#>
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/VerifyDatabaseConnection" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage { Param($r) "ERROR: $($r.d.Item2)" }

	$sessionId.Headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
	$sessionId.Headers["Accept-Encoding"] = "gzip, deflate, sdch"
	$sessionId.Headers.Remove("X-Requested-With") | Out-Null
	#
	$r = Invoke-WebRequest -Uri "$($installUrl)?culture=es-ES&initiateinstall" -WebSession $sessionId -UseBasicParsing
	"$($r.StatusCode): $($r.StatusDescription)"
	
	$sessionId.Headers.Add("X-Requested-With", "XMLHttpRequest")
	$sessionId.Headers["Accept"] = "*/*"
	$sessionId.Headers["Referer"] = "$($installUrl)?culture=es-ES&executeinstall"
	
	# invoke installation
	# WARNING: by default, it blocks until installation finished. It is force to return control after 3 sec
	try {
		$r = Call-Rest "$installUrl/RunInstall" $null $sessionId -TimeoutSec 3
		"$($r.StatusCode): $($r.StatusDescription)"
	}
	catch {
		Write-Host $_.Exception.Message -ForegroundColor DarkYellow
	}
	
	# check progress
	$sessionId.Headers.Remove("X-Requested-With") | Out-Null
	$sessionId.Headers.Remove("Origin") | Out-Null

	$lastProgress = 0
	do {
		# WARNING: Windows goes On Top and also shows a dialog window which is hidden immediately
		Start-Sleep -Seconds 1

		# check for progress detail
		$uniqueArgument = "0.{0}" -f [DateTime]::Now.Ticks
		$progressUrl = "$dnnRootUrl/Install/installstat.log.resources.txt?$uniqueArgument"
		$response = Invoke-WebRequest -Uri $progressUrl -WebSession $sessionId -UseBasicParsing
		# parse response
		$r = $response.Content
		if (-not $r.Length) {
			if ($lastProgress -eq 0) {
				"No progress is reported back"
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
		"$lastProgress%: $lastMessage"
		# break when progress = 100%
	} while ($lastProgress -lt 100)
	"OK"
}

Function Update-DnnWebConfig($dnnRootFolder, $appSettingsWebConfig) {
	Write-Header "Updating web.config..."
	$maxRequestBytes = $appSettingsWebConfig.MaxRequestMB * 1024 * 1024 	# convert to bytes
	Update-WebConfig "$dnnRootFolder\web.config" "system.web/httpRuntime" "maxRequestLength" ($maxRequestBytes / 1024)
	Update-WebConfig "$dnnRootFolder\web.config" "system.webServer/security/requestFiltering/requestLimits" "maxAllowedContentLength" $maxRequestBytes
}

Function Copy-DnnExtraModules($dnnRootFolder, $dnnExtraModules, $dnnDeployer) {
	Write-Header "Copying extra modules to install..."
	$targetFolder = "$dnnRootFolder\Install\Module"
	$sourceFiles = @($dnnExtraModules, $dnnDeployer)

	foreach ($sourceFile in $sourceFiles) {
		# expand wildcards (Ej: *.zip)
		$files = Get-ChildItem $sourceFile | Select -ExpandProperty FullName
		foreach($file in $files) {
			$targetFile = Join-Path $targetFolder (Split-Path $file -Leaf)
			if (-not (Test-Path $targetFile)) { 
				"Adding Extra Module: '$targetFile'..."
				Copy-Item $file $targetFile
			}
		}
	}
}
#endregion

#region Timing
Function Start-StopWatch {
	$Script:_Timer = New-Object Diagnostics.StopWatch
	$Script:_Timer.Start()
}

Function Stop-StopWatch {
	$Script:_Timer.Stop()
	Write-Header ("Elapsed: " + $Script:_Timer.Elapsed.TotalSeconds + " sec")
}
#endregion

#region Cleanup
# TODO: rename to "Delete-WebSite, Delete-AppPool"
Function Delete-All {
	$siteName = ""
	$appPoolName = ""
	appcmd delete site /site.name:"$siteName"
	appcmd delete apppool /apppool.name:"$appPoolName"
}
#endregion

#endregion

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host
Load-Settings
Set-Alias7z
Set-AliasAppCmd

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-StopWatch

Create-Database $Script:appSettings.Database -Recreate

Unzip-File $Script:appSettings.Source.DnnInstallZip $Script:appSettings.Web.RootFolder

Copy-DnnExtraModules $Script:appSettings.Web.RootFolder $Script:appSettings.Source.DnnExtraModules $Script:appSettings.Source.DnnDeployer
Update-DnnWebConfig $Script:appSettings.Web.RootFolder $Script:appSettings.Web.Config
Install-Dnn $Script:appSettings.Web.RootUrl $Script:appSettings.Dnn

Stop-StopWatch
