<#
.SYNOPSIS
  Funciones de Administración de Bases de datos SQL Server
#>
Set-StrictMode -Version latest  # Error Reporting: ALL
#-----------------------------------------------------------[Functions]------------------------------------------------------------

#region Logging (Override)
if (-not (Test-Path Function:Write-Header)) { Function Write-Header($Text) { $Text } }
if (-not (Test-Path Function:Get-Indented)) { Function Get-Indented($Text) { "    $Text" } }
if (-not (Test-Path Function:Write-Indented)) { Function Write-Indented($Text) { Write-Verbose (Get-Indented $Text) } }
if (-not (Test-Path Function:Write-Footer)) { Function Write-Footer($Text) { $Text } }
#endregion

##region Database
Function RunScript-SqlServer {
#RunScript-SqlServer -Script $query -Name $Name -Server $Server -User $User -Password $Password
Param(
[Parameter(Mandatory=$true)][string]$Script,
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$Server,
[string]$User,
[string]$Password,
[Switch]$UseDefaultDatabase = $false, 
[Switch]$EchoInput = $false
)
	$Script = "SET NOCOUNT ON;`r`nGO`r`n$Script"
	
	$scriptFile = [System.IO.Path]::GetTempFileName()
	Set-Content -Path $scriptFile -Value $Script -Encoding UTF8
	try {
		$ArgList = @("-S", $Server, 
					 "-W",			# -W: remove trailing spaces
					 "-h", "-1", 	# -h -1: no header
					 "-b"			# -b: On error batch abort
					 )
		if (-not $UseDefaultDatabase) {
			$ArgList += "-d", $Name 			# -d use database name
		}
		if ($User) {
			$ArgList += "-U", $User, 		# -U login id
						"-P", $Password 	# -P password
		}
		else { 
			$ArgList += "-E" 			# -E: trusted connection
		}
		# echo input commands
		if ($EchoInput) { $ArgList += "-e" }
		# input file
		$ArgList += "-i", $scriptFile
		
		Write-Verbose "sqlcmd.exe $ArgList"
		$response = sqlcmd.exe $ArgList
		if ($response) { $response = $response.Trim() }
		$response
		if ($LASTEXITCODE -ne 0) { throw "ERROR while running SQL Script" }
	}
	finally { Remove-Item -Path $scriptFile -Force -ErrorAction SilentlyContinue | Out-Null }
}

Function GetDefaultPaths-SqlServer {
#GetDefaultPaths-SqlServer -Name $Name -Server $Server -User $User -Password $Password
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$Server,
[string]$User,
[string]$Password
)
	$query1 = @"
PRINT CONVERT(sysname, ServerProperty('InstanceDefaultDataPath')) +
		'|' + 
		CONVERT(sysname, ServerProperty('InstanceDefaultLogPath')) 
"@

	$query2 = @"
-- create a temporary db
IF EXISTS(SELECT 1 FROM master.[sys].[databases] WHERE [name] = 'zzTempDatabaseToDefaultPath')
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
IF EXISTS(SELECT 1 FROM master.[sys].[databases] WHERE [name] = 'zzTempDatabaseToDefaultPath')   
    DROP DATABASE zzTempDatabaseToDefaultPath;
GO
"@

	$result = RunScript-SqlServer -Script $query1 `
				-Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	
	if (-not $result) {
		$result = RunScript-SqlServer -Script $query2 `
				-Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	}
	$result -split '\|'
}

#region SQL Server Databases

Function Remove-SqlServerDb {
#Remove-SqlServerDb -Name $Name -Server $Server -User $User -Password $Password
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$Server,
[string]$User,
[string]$Password,
[string]$OwnerSqlServerUserName,
[string]$OwnerWindowsUserName
)
	Write-Header "Deleting Database '$Name'..."
	if (-not (Test-SqlServerDb -Name $Name -Server $Server -User $User -Password $Password)) {
		Write-Footer "OK (Not found)"
		return
	}

	$query = @"
USE master
GO
PRINT 'Deleting Backup History...'
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$Name'
GO
PRINT 'SET SINGLE_USER...'
ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
PRINT 'DROP DATABASE...'
DROP DATABASE [$Name]
GO
"@
	RunScript-SqlServer -Script $query -Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	
	if ( ($OwnerSqlServerUserName -and $OwnerSqlServerUserName -ne "sa") -or $OwnerWindowsUserName) {
		$loginName = if ($OwnerSqlServerUserName) { $OwnerSqlServerUserName } else { $OwnerWindowsUserName }
		Write-Indented "Removing '$loginName' from SQL Server"
	
		$query = @"
USE master
GO
PRINT 'Removing Login "$loginName"'
IF EXISTS(SELECT name FROM master.sys.server_principals WHERE name = '$loginName')
	DROP LOGIN [$loginName]
GO
PRINT 'OK'
"@
		RunScript-SqlServer -Script $query -Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	}
	
	Write-Footer "OK"
}

Function Test-SqlServerDb {
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$Server,
[string]$User,
[string]$Password
)
	$Name = $Name
	$query = "SELECT DB_ID('$Name')"
	$id = RunScript-SqlServer -Script $query -Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	$id -match "[0-9]+"
}

Function New-SqlServerDb {
#New-SqlServerDb -Name $Name -Server $Server -User $User -Password $Password -Force 1
Param(
[Parameter(Mandatory=$true)][string]$Name,
[Parameter(Mandatory=$true)][string]$Server,
[string]$User,
[string]$Password,
[string]$RecoveryMode = 'Simple',
[Switch]$Force,
[string]$OwnerSqlServerUserName,
[string]$OwnerSqlServerUserPassword,
[string]$OwnerWindowsUserName,
[string]$DataPath,
[string]$LogPath
)
	Write-Header "Creating Database '$Name'..."
	
	if (Test-SqlServerDb -Name $Name -Server $Server -User $User -Password $Password) {
		if ($Force) { Remove-SqlServerDb -Name $Name -Server $Server -User $User -Password $Password }
		else { throw "Database '$Name' already exists. If you want to drop and create it again, Set the parameter -Force." }
	}
	
	Write-Indented "Resolving Database Paths..."
	if (!$dataPath -or !$logPath) {
		$defaultDataPath, $defaultLogPath = GetDefaultPaths-SqlServer -Name $Name -Server $Server -User $User -Password $Password
		if (!$dataPath) { $dataPath = $defaultDataPath }
		if (!$logPath) { $logPath = $defaultLogPath }
	}
	# remove trailing forward-slash
	$dataPath = $dataPath -replace '\\$', ''
	$logPath = $logPath -replace '\\$', ''
	
	Write-Indented "DataPath: '$dataPath'"
	Write-Indented "LogPath: '$logPath'"
	
	$query = @"
PRINT 'CREATE DATABASE...'
CREATE DATABASE [$Name]
	CONTAINMENT = NONE
	ON PRIMARY (NAME = N'$Name',     FILENAME = N'$dataPath\$Name.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
	LOG ON     (NAME = N'$($Name)_log', FILENAME = N'$logPath\$($Name)_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)
GO
--ALTER DATABASE [$Name] SET COMPATIBILITY_LEVEL = 120;
--GO
PRINT 'SET *** OFF';
ALTER DATABASE [$Name] SET ANSI_NULL_DEFAULT OFF;
GO
--PRINT 'SET ANSI_NULLS OFF';
ALTER DATABASE [$Name] SET ANSI_NULLS OFF;
GO
--PRINT 'SET ANSI_PADDING OFF';
ALTER DATABASE [$Name] SET ANSI_PADDING OFF;
GO
--PRINT 'SET ANSI_WARNINGS OFF';
ALTER DATABASE [$Name] SET ANSI_WARNINGS OFF;
GO
--PRINT 'SET ARITHABORT OFF';
ALTER DATABASE [$Name] SET ARITHABORT OFF;
GO
--PRINT 'SET AUTO_CLOSE OFF';
ALTER DATABASE [$Name] SET AUTO_CLOSE OFF;
GO
--PRINT 'SET AUTO_SHRINK OFF';
ALTER DATABASE [$Name] SET AUTO_SHRINK OFF;
GO
PRINT 'SET CURSOR_CLOSE_ON_COMMIT OFF';
ALTER DATABASE [$Name] SET CURSOR_CLOSE_ON_COMMIT OFF;
GO
PRINT 'SET CONCAT_NULL_YIELDS_NULL OFF';
ALTER DATABASE [$Name] SET CONCAT_NULL_YIELDS_NULL OFF;
GO
PRINT 'SET NUMERIC_ROUNDABORT OFF';
ALTER DATABASE [$Name] SET NUMERIC_ROUNDABORT OFF;
GO
PRINT 'SET QUOTED_IDENTIFIER OFF';
ALTER DATABASE [$Name] SET QUOTED_IDENTIFIER OFF;
GO
PRINT 'SET RECURSIVE_TRIGGERS OFF';
ALTER DATABASE [$Name] SET RECURSIVE_TRIGGERS OFF;
GO
PRINT 'SET AUTO_UPDATE_STATISTICS_ASYNC OFF';
ALTER DATABASE [$Name] SET AUTO_UPDATE_STATISTICS_ASYNC OFF;
GO
PRINT 'SET DATE_CORRELATION_OPTIMIZATION OFF';
ALTER DATABASE [$Name] SET DATE_CORRELATION_OPTIMIZATION OFF;
GO
PRINT 'SET READ_COMMITTED_SNAPSHOT OFF';
ALTER DATABASE [$Name] SET READ_COMMITTED_SNAPSHOT OFF;
GO
PRINT 'SET *** ON';
ALTER DATABASE [$Name] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF);
GO
--PRINT 'SET AUTO_UPDATE_STATISTICS ON';
ALTER DATABASE [$Name] SET AUTO_UPDATE_STATISTICS ON;
GO
PRINT 'SET CURSOR_DEFAULT GLOBAL';
ALTER DATABASE [$Name] SET CURSOR_DEFAULT GLOBAL;
GO
PRINT 'SET DISABLE_BROKER';
ALTER DATABASE [$Name] SET DISABLE_BROKER;
GO
PRINT 'SET PARAMETERIZATION SIMPLE';
ALTER DATABASE [$Name] SET PARAMETERIZATION SIMPLE;
GO
PRINT 'SET READ_WRITE';
ALTER DATABASE [$Name] SET READ_WRITE;
GO
PRINT 'SET RECOVERY $RecoveryMode';
ALTER DATABASE [$Name] SET RECOVERY $RecoveryMode;
GO
PRINT 'SET MULTI_USER';
ALTER DATABASE [$Name] SET MULTI_USER;
GO
PRINT 'SET PAGE_VERIFY';
ALTER DATABASE [$Name] SET PAGE_VERIFY CHECKSUM;
GO
PRINT 'SET TARGET_RECOVERY_TIME = 0 SECONDS';
ALTER DATABASE [$Name] SET TARGET_RECOVERY_TIME = 0 SECONDS;
GO
PRINT 'SET DELAYED_DURABILITY = DISABLED';
ALTER DATABASE [$Name] SET DELAYED_DURABILITY = DISABLED;
GO
USE [$Name]
GO
PRINT 'MODIFY FILEGROUP PRIMARY';
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [$Name] MODIFY FILEGROUP [PRIMARY] DEFAULT;
GO
"@

	RunScript-SqlServer -Script $query -Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	
	
	if ( ($OwnerSqlServerUserName -and $OwnerSqlServerUserName -ne "sa") -or $OwnerWindowsUserName) {
		if ($OwnerSqlServerUserName) {
			$loginName = $OwnerSqlServerUserName
			$loginSql = "CREATE LOGIN [$OwnerSqlServerUserName] WITH PASSWORD=N'$OwnerSqlServerUserPassword', DEFAULT_DATABASE=master, CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF"
		}
		elseif ($OwnerWindowsUserName) {
			$loginName = $OwnerWindowsUserName
			$loginSql = "CREATE LOGIN [$OwnerWindowsUserName] FROM WINDOWS WITH DEFAULT_DATABASE=master"
		}
		Write-Indented "Adding $loginName as db_owner"
	
		$query = @"
USE master
GO
PRINT '[master] Creating Login "$loginName"'
IF NOT EXISTS(SELECT name FROM master.sys.server_principals WHERE name = '$loginName')
	$loginSql
GO
USE [$Name]
GO
PRINT '[$Name] Creating User "$loginName"'
IF NOT EXISTS(SELECT name FROM sys.database_principals WHERE name = '$loginName')
	CREATE USER [$loginName] FOR LOGIN [$loginName]
GO
PRINT '[$Name] Adding "$loginName" to db_owner'
ALTER ROLE [db_owner] ADD MEMBER [$loginName]
GO
PRINT 'OK'
"@

		RunScript-SqlServer -Script $query -Name $Name -Server $Server -User $User -Password $Password -UseDefaultDatabase
	}
	
	Write-Footer "OK"
}
#endregion SQL Server Databases

##endregion Database
