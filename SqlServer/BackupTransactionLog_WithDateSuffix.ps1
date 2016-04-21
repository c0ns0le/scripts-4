##requires -version 4
<#
.SYNOPSIS
  Backup Transaction log sql server
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Stop
$ErrorActionPreference = "Stop"


#----------------------------------------------------------[Bug Powershell 2.0]----------------------------------------------------------
 
$bindingFlags = [Reflection.BindingFlags] “Instance,NonPublic,GetField”
$objectRef = $host.GetType().GetField(“externalHostRef”, $bindingFlags).GetValue($host)
$bindingFlags = [Reflection.BindingFlags] “Instance,NonPublic,GetProperty”
$consoleHost = $objectRef.GetType().GetProperty(“Value”, $bindingFlags).GetValue($objectRef, @())
[void] $consoleHost.GetType().GetProperty(“IsStandardOutputRedirected”, $bindingFlags).GetValue($consoleHost, @())
$bindingFlags = [Reflection.BindingFlags] “Instance,NonPublic,GetField”
$field = $consoleHost.GetType().GetField(“standardOutputWriter”, $bindingFlags)
$field.SetValue($consoleHost, [Console]::Out)
$field2 = $consoleHost.GetType().GetField(“standardErrorWriter”, $bindingFlags)
$field2.SetValue($consoleHost, [Console]::Out)

#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$Script:ScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#	Get-ChildItem $sourceFolder -Recurse -File | % {

Function BackupLog-SqlServer($dbName, $sqlInstance, $targetFolder) {
	$dateSuffix = Get-Date -Format "yyyyMMdd_HHmmss"
	
	# create folder if not found
	if (-not (Test-Path $targetFolder)) { md $targetFolder | Out-Null }
	
	# add suffix, same file extension
	$tempFile = "$targetFolder\$($dbName)_$dateSuffix.tmp"
	"Creating backup file '$tempFile'..."
	$sqlScript = "BACKUP LOG [$dbName] TO DISK = N'$tempFile' WITH NOFORMAT, NOINIT, NAME = N'$dbName-Copia transaccion log', SKIP, NOREWIND, NOUNLOAD,  STATS = 10"
	
	# -b on batch error
	sqlcmd.exe -S $sqlInstance -E -Q $sqlScript -b
	if ($LASTEXITCODE -ne 0) { throw "Error Running SQL Script" }
	
	$targetFile = $tempFile -replace '\.[^\.]+$', ".trn"
	"Renaming to '$targetFile'..."
	Move-Item $tempFile $targetFile -Force
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

# UNIT-TEST
#BackupLog-SqlServer -dbName "pruebas" -sqlInstance ".\SQLEXPRESS" -targetFolder "C:\temp\Azure_Logshipping"; exit

#-----------------------------------------------------------[Execution]------------------------------------------------------------

BackupLog-SqlServer -dbName "pruebas" -sqlInstance "." -targetFolder "E:\Azure_Logshipping"


