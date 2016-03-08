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
	$result = Run-Sql $query
	if ($result -match '\\$') { $result = $result -replace '\\$','' } 
	$result
}
Function Get-SqlServerDefaultDataPath { Get-SqlServerProperty "InstanceDefaultDataPath" }
Function Get-SqlServerDefaultLogPath { Get-SqlServerProperty "InstanceDefaultLogPath" }

Function Run-Sql($SqlScript, $server = ".\SQLExpress", [Switch]$EchoInput) {
	$SqlScript = "SET NOCOUNT ON;`r`nGO`r`n$SqlScript"
	
	$scriptFile = [System.IO.Path]::GetTempFileName()
	Set-Content -Path $scriptFile -Value $SqlScript -Encoding UTF8
	try {
		$ArgList = @("-S", $server, 
					 "-W",			# -W: remove trailing spaces
					 "-h", "-1", 	# -h -1: no header
					 "-b"			# -b: On error batch abort
					 )
		$ArgList += "-E" 			# -E: trusted connection
		if ($EchoInput) { $ArgList += "-e" }
		$ArgList += "-i", $scriptFile
		
		#Write-Host "sqlcmd.exe $ArgList"
		$response = sqlcmd.exe $ArgList
		$response
		if ($LASTEXITCODE -ne 0) { throw "ERROR while running SQL Script" }
	}
	finally { Remove-Item -Path $scriptFile -Force -ErrorAction SilentlyContinue }
}

Function Drop-Database($dbName) {
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
	Write-Header "Dropping Database '$dnnDatabaseName'..."
	Run-Sql $query
}

Function Exist-Database($dbName) {
	$query = "SELECT DB_ID('$dbName')"
	$id = Run-Sql $query
	$id -match "[0-9]+"
}

Function Create-Database($dbName, [Switch]$Recreate, $RecoveryMode = "Simple") {
	if (Exist-Database $dbName) {
		if (-not $Recreate) { throw "Database '$dbName' already exists. Use '-Recreate' if you want to drop it and recreate it." }
		Drop-Database $dnnDatabaseName
	}
	
	$dataPath = Get-SqlServerDefaultDataPath
	$logPath = Get-SqlServerDefaultLogPath
	
	Write-Header "Creating Database '$dnnDatabaseName'..."
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

	Run-Sql $query
}
#endregion

#region Install DNN
Function Install-Dnn($dnnRootUrl) {
	$installUrl = "$dnnRootUrl/Install/InstallWizard.aspx"
	# Chrome 48.0.2564.116
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

	$body = @{"installInfo" = @{
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
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/ValidateInput" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage { Param($r) "ERROR: $($r.d.Item2)" }
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
	"Finished"
}

Function Copy-DnnExtra($targetFolder, $sourceFiles) {
	foreach ($sourceFile in $sourceFiles) {
		$targetFile = Join-Path $targetFolder (Split-Path $sourceFile -Leaf)
		if (-not (Test-Path $targetFile)) { 
			"Adding Extra: '$targetFile'..."
			Copy-Item $sourceFile $targetFile
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
#endregion

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------
$sourceDnnExtras = "D:\Installers\DotNetNuke\08.00.00\Extras"
$dnnDeployer = gci "C:\ProgramData\chocolatey\lib\dnncmd\DnnExtension\*.zip" | Select -ExpandProperty FullName -Last 1
$dnnRootFolder = "C:\inetpub\dnn800"
$dnnRootUrl = "http://800.dnndev.me"

$maxRequestBytes = 100 * 1024 * 1024 # 100 MB

$dnnDatabaseName = "dnn800"

Create-Database $dnnDatabaseName -Recreate

Copy-DnnExtra "$dnnRootFolder\Install\Module" `
	"$sourceDnnExtras\ResourcePack.DNNCE.08.00.00.es-ES.zip", $dnnDeployer

Update-WebConfig "$dnnRootFolder\web.config" "system.web/httpRuntime" "maxRequestLength" ($maxRequestBytes/1024)
Update-WebConfig "$dnnRootFolder\web.config" "system.webServer/security/requestFiltering/requestLimits" "maxAllowedContentLength" $maxRequestBytes

Start-StopWatch
Install-Dnn $dnnRootUrl
Stop-StopWatch
