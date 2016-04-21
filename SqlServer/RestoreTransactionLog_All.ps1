#requires -version 4
<#
.SYNOPSIS
  Backup Transaction log sql server
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------


Function RestoreLog-SqlServer {
Param(
	[Parameter(Mandatory=$true)]$dbName, 
	[Parameter(Mandatory=$true)]$sqlInstance, 
	[Parameter(Mandatory=$true)]$sourceFolder, 
	[Parameter(Mandatory=$true)][string]$standbyFolder,
	[Parameter(Mandatory=$true)]$historySubfolder,
	[double]$DaysToKeepLog = 2
)
	# files sorted by name
	$logs = Get-ChildItem "$sourceFolder\*.trn" -File | Sort-Object
	#$logs | % { $_.Name }; exit
	
	$historySubfolder = Join-Path $sourceFolder $historySubfolder
	if (-not (Test-Path $historySubfolder -PathType Container)) { md $historySubfolder | Out-Null }
	
	foreach ($log in $logs) {
		$logFile = $log.FullName
	
		Write-Host "Restoring backup file '$logFile'..." -ForegroundColor DarkGreen
		$sqlScript = "RESTORE LOG [$dbName] FROM  DISK = N'$logFile' WITH  FILE = 1, STANDBY = '$standbyFolder\ROLLBACK_UNDO_$dbName.bak',  NOUNLOAD,  STATS = 10"

		# -b on batch error
		sqlcmd.exe -S $sqlInstance -E -Q $sqlScript -b
		if ($LASTEXITCODE -ne 0) { throw "Error $LASTEXITCODE while running SQL script" }
		
		Move-Item -Path $logFile -Destination $historySubfolder -Force
	}
	
	Cleanup-History $historySubfolder $DaysToKeepLog
}


Function Cleanup-History($historyPath, [double]$DaysToKeepLog) {
	$limit = (Get-Date).AddDays(-1 * $DaysToKeepLog)

	# Delete files older than the $limit.
	Write-Host "Cleaning up log history..." -ForegroundColor DarkGreen
	Get-ChildItem -Path $historyPath -File | ? { $_.CreationTime -lt $limit } | % { 
		$_.FullName
		Remove-Item $_.FullName -Force
	}
}


#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

# UNIT-TEST
#RestoreLog-SqlServer -dbName "pruebas2" -sqlInstance ".\SQLEXPRESS" -sourceFolder "C:\temp\Azure_Logshipping" -historySubfolder "History" -DaysToKeepLog (1/24/60 * 1); exit

#-----------------------------------------------------------[Execution]------------------------------------------------------------

RestoreLog-SqlServer -dbName "pruebas" -sqlInstance "." `
					-sourceFolder "F:\Logshipping" `
					-standbyFolder "C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Backup" `
					-historySubfolder "History" -DaysToKeepLog 2
