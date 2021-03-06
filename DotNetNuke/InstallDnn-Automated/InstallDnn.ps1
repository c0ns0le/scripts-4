#requires -version 4
<#
.SYNOPSIS
  Install DotNetNuke with custom settings
.EXAMPLES
robocopy C:\inetpub\dnn800_orig C:\inetpub\dnn800 /MIR
iisreset & robocopy C:\inetpub\dnn800_orig C:\inetpub\dnn800 /MIR

TODO: Cleanup web.config: AppSettings SiteSql** unused, remove extra comment lines
TODO: Extend web.config: registered known file extensions (svg, etc.)
TODO: Extend web.config: add connection strings for extra applications?
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Init() {
	Clear-Host
	Set-Location $PSScriptRoot
	[Environment]::CurrentDirectory = $PSScriptRoot

	Reset-Indented
	Load-Settings
	Set-Alias7z
	Set-AliasWeb
}

#region Logging
Function Reset-Indented() { $Script:LogIndentedLevel = 0 }
Function Get-Indented($Text) { "{0}{1}" -f (" " * ($Script:LogIndentedLevel*2)), $Text  }
Function Add-Indented($Text, [Switch]$Decrease = $false) { 
	if ($Decrease) { $Script:LogIndentedLevel-- }
	Get-Indented $Text
	if (-not $Decrease)  { $Script:LogIndentedLevel++ }
}
Function Write-Header($Text) { Write-Host (Add-Indented $Text) -ForegroundColor DarkBlue }
Function Write-Footer($Text) { Write-Host (Add-Indented $Text -Decrease) -ForegroundColor DarkGreen }
#endregion

#region Timing
Function Start-StopWatch() {
	$Script:_Timer = New-Object Diagnostics.StopWatch
	$Script:_Timer.Start()
}

Function Stop-StopWatch() {
	$Script:_Timer.Stop()
	Write-Header ("Elapsed: " + $Script:_Timer.Elapsed.TotalSeconds + " sec")
	Write-Footer "Done!"
}
#endregion

#region General Utilities
Function Set-AliasWeb() {
	if (-not (Get-Module WebAdministration)) { Import-Module WebAdministration | Out-Null }
}

Function Set-Alias7z() {
	# check 7-zip alias
	$sevenZip = "C:\Program Files\7-Zip\7z.exe"
	if (-not (Test-Path $sevenZip)) {
		"Installing 7-Zip...."
		cinst 7zip -y
		# WARNING: Consider using 7-zip Portable to deal with issues on Installation Permissions: cinst 7zip.commandline -y
	}
	Set-Alias -Name 7z -Value $sevenZip -Scope Script
}

Function Call-Rest([Parameter(Mandatory=$true)]$Url, $body, $sessionId, $method = "Post", $TimeoutSec = 0, $FailCondition = $null, $FailMessage = $null) {
	Write-Host (Get-Indented ([Uri] $Url).AbsolutePath)
	$response = $null
	try	{
		$jsonBody = &{ if ($body) { ConvertTo-Json ($body) }}
		$response = Invoke-RestMethod -Method $method -Uri $Url -Body $jsonBody -ContentType 'application/json; charset=UTF-8' -WebSession $sessionId -TimeoutSec $TimeoutSec
	}
	catch {
		if ($_.ErrorDetails) {
			$e = ConvertFrom-Json $_.ErrorDetails
			Write-Host (Get-Indented $e.Message -ForegroundColor Red)
			Write-Host (Get-Indented $e.StackTrace -ForegroundColor Red)
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

Function Load-Settings($configPath = $null) {
	Write-Header "Loading Settings..."
	
	if (-not $configPath) { 
		$configPath = "{0}.config" -f ($MyInvocation.PSCommandPath -replace '\.[^\.]+$','')
	}
	Get-Indented "Reading Config: '$configPath'"

	if (-not (Test-Path $configPath)) { throw "Cannot find config file: '$configPath'" }

	# initilize settings object
	$Script:appSettings = @{}

	# read config as xml
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
			$parentkeys = $keys[0..($keys.Length - 2)]
			$lastkey = $keys[($keys.Length - 1)]
			
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
	$vars.DnnDatabaseName = $vars.DnnDatabaseName.Replace("{DnnAlias}", $vars.DnnAlias)
	$vars.AppPoolName = $vars.AppPoolName.Replace("{DnnAlias}", $vars.DnnAlias)
	$vars.SitePhysicalPath = $vars.SitePhysicalPath.Replace("{DnnAlias}", $vars.DnnAlias)
	$vars.SiteDomain = $vars.SiteDomain.Replace("{DnnAlias}", $vars.DnnAlias)
	
	$Script:appSettings.Source.DnnInstallZip = $Script:appSettings.Source.DnnInstallZip.Replace("{DnnSourceRoot}", $vars.DnnSourceRoot)
	$Script:appSettings.Source.DnnExtraModules = $Script:appSettings.Source.DnnExtraModules.Replace("{DnnSourceRoot}", $vars.DnnSourceRoot)
	
	$Script:appSettings.Web.Site.AppPoolName = $Script:appSettings.Web.Site.AppPoolName.Replace("{AppPoolName}", $vars.AppPoolName)
	$Script:appSettings.Web.AppPool.Name = $Script:appSettings.Web.AppPool.Name.Replace("{AppPoolName}", $vars.AppPoolName)
	
	$managedRuntimeVersion = $Script:appSettings.Web.AppPool.managedRuntimeVersion
	if ($managedRuntimeVersion -notmatch '^v[0-9]\.0') {
		throw "Invalid format for managedRuntimeVersion: '$managedRuntimeVersion'. Example of valid format: 'v4.0'"
	}

	$Script:appSettings.Web.AppPool.userName = $Script:appSettings.Web.AppPool.userName.Replace("{Env:USERDOMAIN}", $Env:USERDOMAIN)
	
	$Script:appSettings.Web.Site.Name = $Script:appSettings.Web.Site.Name.Replace("{DnnAlias}", $vars.DnnAlias)
	$Script:appSettings.Web.Site.PhysicalPath = $Script:appSettings.Web.Site.PhysicalPath.Replace("{DnnAlias}", $vars.DnnAlias)
	$Script:appSettings.Target.Folder.Root = $Script:appSettings.Target.Folder.Root.Replace("{DnnAlias}", $vars.DnnAlias)
	$Script:appSettings.Dnn.Root.Url = $Script:appSettings.Dnn.Root.Url.Replace("{DnnAlias}", $vars.DnnAlias)

	# transform to int or it will raise error when assigning
	$Script:appSettings.Web.Site.maxUrlSegments = [int]$Script:appSettings.Web.Site.maxUrlSegments
	$Script:appSettings.Target.Web.Config.MaxRequestMB = [int]$Script:appSettings.Target.Web.Config.MaxRequestMB

	$Script:appSettings.Web.Site.PhysicalPath = $Script:appSettings.Web.Site.PhysicalPath.Replace("{SitePhysicalPath}", $vars.SitePhysicalPath)
	$Script:appSettings.Target.Folder.Root = $Script:appSettings.Target.Folder.Root.Replace("{SitePhysicalPath}", $vars.SitePhysicalPath)
	
	$Script:appSettings.Web.Site.Protocol = $Script:appSettings.Web.Site.Protocol.Replace("{SiteProtocol}", $vars.SiteProtocol)
	$Script:appSettings.Dnn.Root.Url = $Script:appSettings.Dnn.Root.Url.Replace("{SiteProtocol}", $vars.SiteProtocol)
	
	$Script:appSettings.Web.Site.Alias = $Script:appSettings.Web.Site.Alias.Replace("{SiteDomain}", $vars.SiteDomain)
	$Script:appSettings.Dnn.Root.Url = $Script:appSettings.Dnn.Root.Url.Replace("{SiteDomain}", $vars.SiteDomain)

	$Script:appSettings.Web.Site.Port = $Script:appSettings.Web.Site.Port.Replace("{SitePort}", $vars.SitePort)
	$Script:appSettings.Dnn.Root.Url = $Script:appSettings.Dnn.Root.Url.Replace("{SitePort}", ":$($vars.SitePort)")
	# remove default port
	$Script:appSettings.Dnn.Root.Url = $Script:appSettings.Dnn.Root.Url.Replace(":80", "")
	
	$Script:appSettings.Database.Name = $Script:appSettings.Database.Name.Replace("{DnnDatabaseName}", $vars.DnnDatabaseName)
	$Script:appSettings.Dnn.installInfo.databaseName = $Script:appSettings.Dnn.installInfo.databaseName.Replace("{DnnDatabaseName}", $vars.DnnDatabaseName)
	
	$Script:appSettings.Database.Server = $Script:appSettings.Database.Server.Replace("{DnnDatabaseServer}", $vars.DnnDatabaseServer)
	$Script:appSettings.Dnn.installInfo.databaseServerName = $Script:appSettings.Dnn.installInfo.databaseServerName.Replace("{DnnDatabaseServer}", $vars.DnnDatabaseServer)

	$Script:appSettings.Dnn.installInfo.password = $Script:appSettings.Dnn.installInfo.password.Replace("{DnnSuperUserPassword}", $vars.DnnSuperUserPassword)
	$Script:appSettings.Dnn.installInfo.confirmPassword = $Script:appSettings.Dnn.installInfo.confirmPassword.Replace("{DnnSuperUserPassword}", $vars.DnnSuperUserPassword)

	# expand path to last-item matching search expression
	$Script:appSettings.Source.DnnInstallZip = Get-ChildItem $Script:appSettings.Source.DnnInstallZip | Select -ExpandProperty FullName -Last 1
	$Script:appSettings.Source.DnnDeployer = Get-ChildItem $Script:appSettings.Source.DnnDeployer | Select -ExpandProperty FullName -Last 1
	Write-Footer "OK"
}
#UNIT-TEST: Load-Settings
#Init; ConvertTo-Json $Script:appSettings; exit

Function Set-FullAccess([Parameter(Mandatory=$true)]$physicalPath, [Parameter(Mandatory=$true)]$userName) {
	Write-Header "Granting full access to '$userName' on '$physicalPath'..."
	$ArgList = @("`"$physicalPath`"", 
				"/grant", 
				# (OI) - herencia de objeto
				# (CI) - herencia de contenedor
				# F - acceso total
				"`"$userName`":(OI)(CI)(F)", 
				"/T", 	# /T se realiza en todos los archivos o directorios bajo los directorios especificados en el nombre.
				"/Q",   # /Q suprimir los mensajes de que las operaciones se realizaron correctamente.
				"/C"	# /C indica que esta operación continuará en todos los errores de archivo. Se seguirán mostrando los mensajes de error.
				)
	Get-Indented "icacls.exe $ArgList"
	$cmdOutput = icacls.exe $ArgList
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	Write-Footer "OK"
}

Function Delete-Folder([Parameter(Mandatory=$true)]$targetFolder) {
	if (Test-Path $targetFolder -PathType Container) {
		Write-Header "Deleting existing folder '$targetFolder' (recursively)..."
		Remove-Item $targetFolder -Recurse -Force
		Write-Footer "OK"
	}
}
#UNIT-TEST
#Init; Delete-Folder $Script:appSettings.Target.Folder.Root; Exit

Function Unzip-File([Parameter(Mandatory=$true)]$zipFile, [Parameter(Mandatory=$true)]$targetFolder, $Exclude) {
	Write-Header "Extracting files to '$targetFolder'..."
	
	# check zip file exists
	if (-not (Test-Path $zipFile)) { throw "File not found '$zipFile'" }
	
	# unzip file
	# Examplo: 7z x archive.zip -oc:\soft *.cpp -r -y
	$ArgList = @("x", 				# Extracts with full paths
				$zipFile, 			# zip file
				"-o$targetFolder",  # destination folder
				"*", 				# file to extract
				"-r"				# recursive
				"-y"				# overwrite existing files on destination
				)
	
	if ($Exclude) {
		# filenames or wildcarded names that must be excluded. Multiple exclude switches are supported.
		# -x [<recurse_type>]<file_ref>
		# <recurse_type> ::= r[- | 0]                <file_ref> ::= @{listfile} | !{wildcard}
		$Exclude | % { $ArgList += "xr!$_" }
	}
	
	Get-Indented "7z $ArgList"
	$cmdOutput = 7z $ArgList
	if (0 -notcontains $LASTEXITCODE) { throw $cmdOutput }
	Write-Footer "OK"
}
#UNIT-TEST
#Init; Unzip-File $Script:appSettings.Source.DnnInstallZip $Script:appSettings.Target.Folder.Root; Exit

Function Update-WebConfig([Parameter(Mandatory=$true)]$configFile, [Parameter(Mandatory=$true)]$rootXPath, [Parameter(Mandatory=$true)]$attrName, [Parameter(Mandatory=$true)]$attrValue) {
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
		Get-Indented ( "{0}/@{1}: '{2}' [{3}]" -f $rootXPath, $attrName, $attrValue, (&{if ($isDirty) {"UPDATED"} else {"UNCHANGED"}}) )
	}
	else {
		Get-Indented ( "{0}: '{1}' [{2}]" -f $rootXPath, $attrValue, (&{if ($isDirty) {"UPDATED"} else {"UNCHANGED"}}) )
	}
	if ($isDirty) { $doc.Save($configFile) }
}
#endregion

#region Database
Function Run-Sql([Parameter(Mandatory=$true)]$SqlScript, [Parameter(Mandatory=$true)][Hashtable]$appSettingsDatabase, [Switch]$UseDefaultDatabase = $false, [Switch]$EchoInput = $false) {
	$SqlScript = "SET NOCOUNT ON;`r`nGO`r`n$SqlScript"
	
	$scriptFile = [System.IO.Path]::GetTempFileName()
	Set-Content -Path $scriptFile -Value $SqlScript -Encoding UTF8
	try {
		$ArgList = @("-S", $appSettingsDatabase.Server, 
					 "-W",			# -W: remove trailing spaces
					 "-h", "-1", 	# -h -1: no header
					 "-b"			# -b: On error batch abort
					 )
		if (-not $UseDefaultDatabase) {
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
		
		#Write-Host (Get-Indented "sqlcmd.exe $ArgList")
		$response = sqlcmd.exe $ArgList
		if ($response) { $response = $response.Trim() }
		$response
		if ($LASTEXITCODE -ne 0) { throw "ERROR while running SQL Script" }
	}
	finally { Remove-Item -Path $scriptFile -Force -ErrorAction SilentlyContinue | Out-Null }
}

Function Get-SqlServerDefaultPaths() {
	$query1 = @"
PRINT CONVERT(sysname, ServerProperty('InstanceDefaultDataPath')) +
		'|' + 
		CONVERT(sysname, ServerProperty('InstanceDefaultLogPath')) 
"@

	$query2 = @"
-- create a temporary db
IF EXISTS(SELECT 1 FROM [master].[sys].[databases] WHERE [name] = 'zzTempDatabaseToDefaultPath')
	DROP DATABASE zzTempDatabaseToDefaultPath;
GO
CREATE DATABASE zzTempDatabaseToDefaultPath;
GO

-- find out default paths
DECLARE @Default_Data_Path VARCHAR(512), @Default_Log_Path VARCHAR(512);

--data
SELECT @Default_Data_Path = LEFT(physical_name,LEN(physical_name)-CHARINDEX('\',REVERSE(physical_name))+1)
	FROM sys.master_files mf INNER JOIN sys.databases d  ON mf.database_id = d.database_id
	WHERE d.[name] = 'zzTempDatabaseToDefaultPath' AND type = 0;

--Log
SELECT @Default_Log_Path = LEFT(physical_name,LEN(physical_name)-CHARINDEX('\',REVERSE(physical_name))+1)
	FROM sys.master_files mf INNER JOIN sys.databases d  ON mf.database_id = d.database_id
	WHERE d.[name] = 'zzTempDatabaseToDefaultPath' AND type = 1;

PRINT @Default_Data_Path + '|' + @Default_Log_Path;
GO

-- drop the temporary db
IF EXISTS(SELECT 1 FROM [master].[sys].[databases] WHERE [name] = 'zzTempDatabaseToDefaultPath')   
    DROP DATABASE zzTempDatabaseToDefaultPath;
GO
"@

	$result = Run-Sql $query1 $Script:appSettings.Database -UseDefaultDatabase
	if (-not $result) {
		$result = Run-Sql $query2 $Script:appSettings.Database -UseDefaultDatabase
	}
	$result -split '\|'
}
#UNIT-TEST
#Init; Get-SqlServerDefaultPaths; exit

Function Delete-Database([Parameter(Mandatory=$true)][Hashtable]$appSettingsDatabase) {
	$dbName = $appSettingsDatabase.Name
	Write-Header "Deleting Database '$dbName'..."

	$query = @"
USE master
GO
PRINT 'Deleting Backup History...'
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$dbName'
GO
PRINT 'SET SINGLE_USER...'
ALTER DATABASE [$dbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
PRINT 'DROP DATABASE...'
DROP DATABASE [$dbName]
GO
"@
	Run-Sql $query $appSettingsDatabase -UseDefaultDatabase
	Write-Footer "OK"
}

Function Exist-Database([Parameter(Mandatory=$true)][Hashtable]$appSettingsDatabase) {
	$dbName = $appSettingsDatabase.Name
	$query = "SELECT DB_ID('$dbName')"
	$id = Run-Sql $query $appSettingsDatabase -UseDefaultDatabase
	$id -match "[0-9]+"
}

Function Create-Database([Parameter(Mandatory=$true)][Hashtable]$appSettingsDatabase) {
	$dbName = $appSettingsDatabase.Name
	Write-Header "Creating Database '$dbName'..."

	$DropAndCreate = $appSettingsDatabase.DropAndCreate -eq "1"
	$RecoveryMode = $appSettingsDatabase.RecoveryMode
	
	if (Exist-Database $appSettingsDatabase) {
		if ($DropAndCreate) { Delete-Database $appSettingsDatabase }
		else { throw "Database '$dbName' already exists. If you want to drop and create it again, Set the parameter Database.DropAndCreate='1'." }
	}
	
	Get-Indented "Resolving Database Paths..."
	$dataPath = $appSettingsDatabase.DataPath
	$logPath = $appSettingsDatabase.LogPath
	
	if (!$dataPath -or !$logPath) {
		$defaultDataPath, $defaultLogPath = Get-SqlServerDefaultPaths
		if (!$dataPath) { $dataPath = $defaultDataPath }
		if (!$logPath) { $logPath = $defaultLogPath }
	}
	# remove trailing forward-slash
	$dataPath = $dataPath -replace '\\$', ''
	$logPath = $logPath -replace '\\$', ''
	
	Get-Indented "DataPath: '$dataPath'"
	Get-Indented "LogPath: '$logPath'"
	
	$query = @"
PRINT 'CREATE DATABASE...'
CREATE DATABASE [$dbName]
	CONTAINMENT = NONE
	ON PRIMARY (NAME = N'$dbName',     FILENAME = N'$dataPath\$dbName.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
	LOG ON     (NAME = N'$($dbName)_log', FILENAME = N'$logPath\$($dbName)_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)
GO
--ALTER DATABASE [$dbName] SET COMPATIBILITY_LEVEL = 120;
--GO
PRINT 'SET *** OFF';
ALTER DATABASE [$dbName] SET ANSI_NULL_DEFAULT OFF;
GO
--PRINT 'SET ANSI_NULLS OFF';
ALTER DATABASE [$dbName] SET ANSI_NULLS OFF;
GO
--PRINT 'SET ANSI_PADDING OFF';
ALTER DATABASE [$dbName] SET ANSI_PADDING OFF;
GO
--PRINT 'SET ANSI_WARNINGS OFF';
ALTER DATABASE [$dbName] SET ANSI_WARNINGS OFF;
GO
--PRINT 'SET ARITHABORT OFF';
ALTER DATABASE [$dbName] SET ARITHABORT OFF;
GO
--PRINT 'SET AUTO_CLOSE OFF';
ALTER DATABASE [$dbName] SET AUTO_CLOSE OFF;
GO
--PRINT 'SET AUTO_SHRINK OFF';
ALTER DATABASE [$dbName] SET AUTO_SHRINK OFF;
GO
PRINT 'SET CURSOR_CLOSE_ON_COMMIT OFF';
ALTER DATABASE [$dbName] SET CURSOR_CLOSE_ON_COMMIT OFF;
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
PRINT 'SET AUTO_UPDATE_STATISTICS_ASYNC OFF';
ALTER DATABASE [$dbName] SET AUTO_UPDATE_STATISTICS_ASYNC OFF;
GO
PRINT 'SET DATE_CORRELATION_OPTIMIZATION OFF';
ALTER DATABASE [$dbName] SET DATE_CORRELATION_OPTIMIZATION OFF;
GO
PRINT 'SET READ_COMMITTED_SNAPSHOT OFF';
ALTER DATABASE [$dbName] SET READ_COMMITTED_SNAPSHOT OFF;
GO
PRINT 'SET *** ON';
ALTER DATABASE [$dbName] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF);
GO
--PRINT 'SET AUTO_UPDATE_STATISTICS ON';
ALTER DATABASE [$dbName] SET AUTO_UPDATE_STATISTICS ON;
GO
PRINT 'SET CURSOR_DEFAULT GLOBAL';
ALTER DATABASE [$dbName] SET CURSOR_DEFAULT GLOBAL;
GO
PRINT 'SET DISABLE_BROKER';
ALTER DATABASE [$dbName] SET DISABLE_BROKER;
GO
PRINT 'SET PARAMETERIZATION SIMPLE';
ALTER DATABASE [$dbName] SET PARAMETERIZATION SIMPLE;
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
USE [$dbName]
GO
PRINT 'MODIFY FILEGROUP PRIMARY';
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [$dbName] MODIFY FILEGROUP [PRIMARY] DEFAULT;
GO
"@

	Run-Sql $query $appSettingsDatabase -UseDefaultDatabase
	Write-Footer "OK"
}
#endregion

#region IIS Tools

#region Application Pool
Function Exist-AppPool([Parameter(Mandatory=$true)]$appPoolName) { Test-Path "IIS:\AppPools\$appPoolName" -PathType Container }

Function Delete-AppPool([Parameter(Mandatory=$true)]$appPoolName) { 
	if (-not (Exist-AppPool $appPoolName)) { return }

	Write-Header "Deleting App Pool '$appPoolName'..."
	Remove-Item "IIS:\AppPools\$appPoolName" -Force -Recurse 
	Write-Footer "OK"
}

Function Create-AppPool([Parameter(Mandatory=$true)]$appSettingsWebAppPool) {
	$appPoolName = $appSettingsWebAppPool.Name
	Write-Header "Creating App Pool $appPoolName..."

	$poolPath = "IIS:\AppPools\$appPoolName"
	$managedRuntimeVersion = $appSettingsWebAppPool.managedRuntimeVersion
	$enable32BitAppOnWin64 = $appSettingsWebAppPool.enable32BitAppOnWin64
	# NetworkService | LocalService | LocalSystem | ApplicationPoolIdentity | SpecificUser
	$identityType = $appSettingsWebAppPool.identityType
	$userName = $appSettingsWebAppPool.userName

	$appPoolExisted = Exist-AppPool $appPoolName
	$appPool =  &{ if ($appPoolExisted) { Get-Item $poolPath } else { New-Item $poolPath } }
	
	$userChanged = $true
	if ($appPoolExisted) {
		$userChanged = -not ($appPool.ProcessModel.identityType -eq $identityType -and $appPool.ProcessModel.userName -eq $userName)
	}

	if ($userChanged) {
		$appPool | Set-ItemProperty -Name ProcessModel.identityType -Value $identityType

		if ($identityType -eq "SpecificUser") {
			# username is required
			if (-not $userName) { throw "[Create-AppPool] userName is required when identityType = '$identityType'" }
			# ask for password
			$cred = Get-Credential $userName -Message "Credenciales para el Grupo de Aplicaciones $poolName"
			if (-not $cred) { throw "Instalación Cancelada." }
			# set user/password
			$userName = $cred.UserName
			$appPool | Set-ItemProperty -Name ProcessModel.userName -Value $userName
			$appPool | Set-ItemProperty -Name ProcessModel.password -Value $cred.GetNetworkCredential().Password
		}
	}


	$appPool | Set-ItemProperty -Name managedRuntimeVersion -Value $managedRuntimeVersion	
	$appPool | Set-ItemProperty -Name enable32BitAppOnWin64 -Value $enable32BitAppOnWin64	
	
	if (-not $appPoolExisted) {
		# small delay so that it creates app pool's built-in user
		Start-Sleep -Milliseconds 2000
		# set permissions
		Set-FullAccess "$env:SystemRoot\Temp" "IIS AppPool\$appPoolName"
		Set-FullAccess "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files" "IIS AppPool\$appPoolName"
		Set-FullAccess "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files" "IIS AppPool\$appPoolName"
	}
	Write-Footer "OK"
}
#UNIT-TEST AppPool
#Init; Delete-AppPool $Script:appSettings.Web.AppPool.Name; exit
#Init; Exist-AppPool $Script:appSettings.Web.AppPool.Name; exit
#Init; Create-AppPool $Script:appSettings.Web.AppPool; exit
#endregion

#region Web Site
Function Exist-Site([Parameter(Mandatory=$true)]$siteName) { Test-Path "IIS:\Sites\$siteName" -PathType Container }

Function Delete-Site([Parameter(Mandatory=$true)]$siteName) { 
	if (-not (Exist-Site $siteName)) { return }
	Write-Header "Deleting site '$siteName'..."
	Remove-Item "IIS:\Sites\$siteName" -Force -Recurse
	Write-Footer "OK"
}

Function Create-Site([Parameter(Mandatory=$true)]$appSettingsWebSite) {
	$siteName = $appSettingsWebSite.Name
	$physicalPath = $appSettingsWebSite.PhysicalPath
	$appPoolName = $appSettingsWebSite.AppPoolName
	$protocol = $appSettingsWebSite.Protocol
	$sitePort = $appSettingsWebSite.Port
	$siteAlias = $appSettingsWebSite.Alias
	$maxUrlSegments = $appSettingsWebSite.maxUrlSegments
	$DropAndCreate = $appSettingsWebSite.DropAndCreate
	$anonymousAuthentication = &{ if ($appSettingsWebSite.anonymousAuthentication -eq "1") {"true"} else {"false"} }
	$windowsAuthentication = &{ if ($appSettingsWebSite.windowsAuthentication -eq "1") {"true"} else {"false"} }

	if ($appPoolName -eq $null) { $appPoolName = $siteName }
	if ($siteAlias -eq $null) { $siteAlias = $siteName }
	
	Write-Header "Create Site $siteName"
	$bindings = @{ protocol = $protocol
				  bindingInformation = (":{0}:{1}" -f $sitePort, $siteAlias)
				}
	
	$sitePath = "IIS:\Sites\$siteName"
	$iisSite = New-Item $sitePath -bindings $bindings -physicalPath $physicalPath
	
	# set app pool name to use
	$iisSite | Set-ItemProperty -Name applicationPool -Value $appPoolName
	$iisSite | Set-ItemProperty -Name limits.maxUrlSegments -Value $maxUrlSegments -ErrorAction SilentlyContinue
	
	# grant full access to user set as identity on site's app pool
	Set-FullAccess $physicalPath "IIS AppPool\$appPoolName"
	
	# enable anonymous authentication | disable windows authentication
	Get-Indented "Setting Anonymous Authentication to enabled = '$anonymousAuthentication'"
	# -PSPath machine/webRoot/appHost
	Set-WebConfigurationProperty -Filter /system.WebServer/security/authentication/anonymousAuthentication -Name enabled -Value $anonymousAuthentication -PSPath IIS:\ -Location $siteName
	#Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/anonymousAuthentication -name enabled -value true -PSPath $sitePath

	Get-Indented "Setting Windows Authentication to enabled = '$windowsAuthentication'"
	Set-WebConfigurationProperty -Filter /system.WebServer/security/authentication/windowsAuthentication -Name enabled -Value $windowsAuthentication -PSPath IIS:\ -Location $siteName
	#Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/windowsAuthentication -name enabled -value false -PSPath $sitePath

	Write-Footer "OK"
}

#UNIT-TEST AppPool
#Init; Delete-Site $Script:appSettings.Web.Site.Name; exit
#Init; Exist-Site $Script:appSettings.Web.Site.Name; exit
#Init; Create-AppPool $Script:appSettings.Web.AppPool; Create-Site $Script:appSettings.Web.Site; exit
#endregion

#endregion

#region Configure Dnn Site
Function UpdateConfig-DnnSite([Parameter(Mandatory=$true)]$dnnRootFolder, [Parameter(Mandatory=$true)]$appSettingsTargetWebConfig) {
	Write-Header "Updating web.config..."
	$maxRequestBytes = $appSettingsTargetWebConfig.MaxRequestMB * 1024 * 1024 	# convert MB to Bytes
	Update-WebConfig "$dnnRootFolder\web.config" "system.web/httpRuntime" "maxRequestLength" ($maxRequestBytes / 1024)
	Update-WebConfig "$dnnRootFolder\web.config" "system.webServer/security/requestFiltering/requestLimits" "maxAllowedContentLength" $maxRequestBytes
	Write-Footer "OK"
}

Function CopyModule-DnnSite([Parameter(Mandatory=$true)]$dnnRootFolder, [Parameter(Mandatory=$true)]$dnnExtraModules, [Parameter(Mandatory=$true)]$dnnDeployer) {
	Write-Header "Copying extra modules to install..."
	$targetFolder = "$dnnRootFolder\Install\Module"
	$sourceFiles = @($dnnExtraModules, $dnnDeployer)

	foreach ($sourceFile in $sourceFiles) {
		$sourceFolder = Split-Path $sourceFile -Parent
		# check source folder exist
		if (-not (Test-Path $sourceFolder -PathType Container)) {
			Get-Indented "WARNING: Skipping. Cannot find folder '$sourceFolder'"
			continue
		}
		
		# expand wildcards (Ej: *.zip)
		$files = Get-ChildItem $sourceFile | Select -ExpandProperty FullName
		foreach($file in $files) {
			$targetFile = Join-Path $targetFolder (Split-Path $file -Leaf)
			Get-Indented $targetFile
			# overwrite if found
			Copy-Item $file $targetFile -Force -Recurse
		}
	}
	Write-Footer "OK"
}

Function Unzip-DnnSite([Parameter(Mandatory=$true)]$appSettingsSource, [Parameter(Mandatory=$true)]$appSettingsTargetFolder) {
	Write-Header "Extracting Dnn Site..."
	# re-create site folder
	if (Test-Path $appSettingsTargetFolder.Root -PathType Container) {
		if ($appSettingsTargetFolder.DropAndCreate) { Delete-Folder $appSettingsTargetFolder.Root }
		else { throw "Destination folder exists: '$($appSettingsTargetFolder.Root)'. If you want to drop and create it again, Set the parameter Target.Folder.DropAndCreate='1'." }
	}
	
	# unzip all dnn files to target folder (create target folder by default)
	Unzip-File $appSettingsSource.DnnInstallZip $appSettingsTargetFolder.Root $appSettingsSource.DnnInstallExclude
	Write-Footer "OK"
}
#UNIT-TEST
#Init; Unzip-DnnSite $Script:appSettings.Source $Script:appSettings.Target.Folder; Exit

Function Create-DnnSite([Parameter(Mandatory=$true)]$appSettingsSource, [Parameter(Mandatory=$true)]$appSettingsTarget, [Parameter(Mandatory=$true)]$appSettingsWebAppPool, [Parameter(Mandatory=$true)]$appSettingsWebSite) {
	Write-Header "Creating Dnn Site..."
	
	# delete site and re-create
	$siteName = $appSettingsWebSite.Name
	if (Exist-Site $siteName) { 
		if ($appSettingsWebSite.DropAndCreate) { Delete-Site $siteName }
		else { throw "Site '$siteName' already exists. If you want to drop and create it again, Set the parameter Web.Site.DropAndCreate='1'." }
	}
	
	# unzip dnn files
	Unzip-DnnSite $appSettingsSource $appSettingsTarget.Folder
	
	#copy extra modules to install along with dnn
	CopyModule-DnnSite $appSettingsTarget.Folder.Root $appSettingsSource.DnnExtraModules $appSettingsSource.DnnDeployer
	
	# update web-config
	UpdateConfig-DnnSite $appSettingsTarget.Folder.Root $appSettingsTarget.Web.Config

	# create web site on IIS
	Create-AppPool $appSettingsWebAppPool
	Create-Site $appSettingsWebSite
	
	Write-Footer "OK"
}
#UNIT-TEST
#Init; Create-DnnSite $Script:appSettings.Source $Script:appSettings.Target $Script:appSettings.Web.AppPool $Script:appSettings.Web.Site; Exit

Function InstallWizard-DnnSite([Parameter(Mandatory=$true)]$dnnRootUrl, [Parameter(Mandatory=$true)]$appSettingsDnn) {
	Write-Header "Invoking Install Wizard ($dnnRootUrl)..."
	$installUrl = "$dnnRootUrl/Install/InstallWizard.aspx"
	# agent: Chrome 48.0.2564.116
	$UserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.116 Safari/537.36"

	# ignore ssl-certificates
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

	Get-Indented ([Uri] $installUrl).AbsolutePath
	# -UseBasicParsing: if you don't need the html returned to be parsed into different objects (it is a bit quicker).
	$r = Invoke-WebRequest -Uri $installUrl -SessionVariable sessionId -UseBasicParsing -UserAgent $UserAgent -TimeoutSec 600
	Get-Indented "$($r.StatusCode): $($r.StatusDescription)"
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
	$r = Call-Rest "$installUrl/ValidateInput" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage { Param($r) "ERROR: $($r.d.Item2)" }
	
	# response: {"d":{"Item1":true,"Item2":""}}
	$r = Call-Rest "$installUrl/VerifyDatabaseConnection" $body $sessionId -FailCondition { Param($r) -not $r.d.Item1 } -FailMessage { Param($r) "ERROR: $($r.d.Item2)" }

	$sessionId.Headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
	$sessionId.Headers["Accept-Encoding"] = "gzip, deflate, sdch"
	$sessionId.Headers.Remove("X-Requested-With") | Out-Null
	#
	$r = Invoke-WebRequest -Uri "$($installUrl)?culture=es-ES&initiateinstall" -WebSession $sessionId -UseBasicParsing
	Get-Indented "$($r.StatusCode): $($r.StatusDescription)"
	
	$sessionId.Headers.Add("X-Requested-With", "XMLHttpRequest")
	$sessionId.Headers["Accept"] = "*/*"
	$sessionId.Headers["Referer"] = "$($installUrl)?culture=es-ES&executeinstall"
	
	# invoke installation
	# WARNING: by default, it blocks until installation finished. It is force to return control after 3 sec
	try {
		$r = Call-Rest "$installUrl/RunInstall" $null $sessionId -TimeoutSec 3
		Get-Indented "$($r.StatusCode): $($r.StatusDescription)"
	}
	catch {
		Get-Indented "Intentionally timing out request to check installation progress..."
		Get-Indented "$($_.Exception.GetType().Name): $($_.Exception.Message)"
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
				Get-Indented "No progress is reported back"
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
		Get-Indented "$lastProgress%: $lastMessage"
		# break when progress = 100%
	} while ($lastProgress -lt 100)

	Write-Footer "OK"
}
#endregion

#region Cleanup
Function Clean-DnnAll() {
	$appSettingsDatabase = $Script:appSettings.Database
	$appSettingsWebSite = $Script:appSettings.Web.Site

	Delete-Database $appSettingsDatabase
	Delete-Site $appSettingsWebSite.Name
	Delete-Folder $appSettingsWebSite.physicalPath
	Delete-AppPool $appSettingsWebSite.appPoolName
}
#UNIT-TEST
#Init; Delete-All $Script:appSettings.Database $Script:appSettings.Web.Site; exit
#endregion


#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Init

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-StopWatch

Create-Database $Script:appSettings.Database
Create-DnnSite $Script:appSettings.Source $Script:appSettings.Target $Script:appSettings.Web.AppPool $Script:appSettings.Web.Site
InstallWizard-DnnSite $Script:appSettings.Dnn.Root.Url $Script:appSettings.Dnn

Stop-StopWatch
