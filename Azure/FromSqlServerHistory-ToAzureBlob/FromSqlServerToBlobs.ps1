#requires -Version 4
<#
.SYNOPSIS
  Lee blobs que sql server y los sube a azure
  Soporta n Hilos ejecutados en paralelo

.EXAMPLE

Powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File 

$ConnectionStringPatchDb = 'Server={0};Database={1};Integrated Security=True' -f "FCDB1\DEV", "RepExt_Trunk_APP"
$ConnectionString = 'Server={0};Database={1};Integrated Security=True' -f "FCDB1\DEV", "RepExt_Trunk_APP"

$StorageAccountName = 'girosyfinanzasdev'
$StorageAccountKey = 'tWSkl8twANjr1xidqF1amVdPXjxOyWDxlu1yFwDZDRzyVA=='
$ContainerNamePrefix = 'dev-loghistory'

$TempTargetFolder = "C:\Temp\sqlfiles_dev"
$BatchReadSize = 1
$LimitRowsAffected = 1

CD "..."
.\FromSqlServerToBlobs.ps1 -ConnectionStringPatchDb $ConnectionStringPatchDb -ConnectionString $ConnectionString -TempTargetFolder $TempTargetFolder -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ContainerNamePrefix $ContainerNamePrefix -BatchReadSize $BatchReadSize -LimitRowsAffected $LimitRowsAffected
#>
Param(
[Parameter(Mandatory=$true)][string]$ConnectionStringPatchDb,
[Parameter(Mandatory=$true)][string]$ConnectionString,
[Parameter(Mandatory=$true)][string]$TempTargetFolder, 
[Parameter(Mandatory=$true)][string]$StorageAccountName, 
[Parameter(Mandatory=$true)][string]$StorageAccountKey, 
[Parameter(Mandatory=$true)][string]$ContainerNamePrefix, 
[int]$BatchReadSize = 1,
[int]$LimitRowsAffected = 0
)
Set-StrictMode -Version Latest
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

$Script:ContainerList =  @()

Function Resolve-Container {
#Resolve-Container -ContainerName $ContainerName -blobContext $blobContext
Param(
[Parameter(Mandatory=$true)]$ContainerName,
[Parameter(Mandatory=$true)]$blobContext
)
	if ($Script:ContainerList -contains $ContainerName) { return }

	# Create container if not found
	if (-not (Get-AzureStorageContainer -Name $ContainerName -Context $blobContext -ErrorAction SilentlyContinue)) {
		"Creating container '$ContainerName'"
		New-AzureStorageContainer -Name $ContainerName -Permission Off -Context $blobContext | Out-Null
	}
	$Script:ContainerList += $ContainerName
}


Function Upload-Blob {
Param(
[Parameter(Mandatory=$true)]$id,
[Parameter(Mandatory=$true)]$json,
[Parameter(Mandatory=$true)]$ContainerName,
[Parameter(Mandatory=$true)]$blobNameSuffix,
[Parameter(Mandatory=$true)]$blobContext
)
	# create container if not found
	Resolve-Container -ContainerName $ContainerName -blobContext $blobContext

	# build blob name 
	$blobName = "{0}_{1}.json" -f $id, $blobNameSuffix
	$path = "{0}\{1}" -f $TempTargetFolder, $blobName
    [IO.File]::WriteAllText($path, $json, [Text.Encoding]::UTF8)
	
	# upload
	Set-AzureStorageBlobContent -File $path -Container $ContainerName -Blob $blobName -Context $blobContext -Force | Out-Null
	# delete temp file
	[IO.File]::Delete($path)
}


Function UploadFromSqlToBlob-Document {
	if (-not $BatchReadSize) { $BatchReadSize = 1 }
<#	$SqlUpdateTransactional = @"
		SET ROWCOUNT $BatchReadSize
		UPDATE Historial.LogsTransacciones WITH (READPAST, READCOMMITTEDLOCK)
			SET ds_MensajeEntrada = NULL
			OUTPUT deleted.id_LogTransaccion,
				   deleted.ds_MensajeEntrada
			WHERE ds_MensajeEntrada IS NOT NULL
		SET ROWCOUNT 0
"@
#>
	$SqlDeleteTransactionalPatch = @"
		SET ROWCOUNT $BatchReadSize
		DELETE dbo.LogsTransacciones_PendingBlob WITH (READPAST, READCOMMITTEDLOCK)
			OUTPUT deleted.id_LogTransaccion
		SET ROWCOUNT 0
"@
	
	$SqlSelectFmt = @"
		SELECT ds_MensajeEntrada, ds_MensajeSalida, dt_Creado
			FROM Historial.LogsTransacciones WITH (NOLOCK)
			WHERE id_LogTransaccion = {0}
"@
	$SqlUpdateFmt = @"
		UPDATE Historial.LogsTransacciones
			SET ds_MensajeEntrada = NULL,
				ds_MensajeSalida = NULL
			WHERE id_LogTransaccion = {0}
"@
	
	if (-not (Test-Path $TempTargetFolder -PathType Container)) { mkdir $TempTargetFolder | Out-Null }

	# connect to blob
	$blobContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

	try {
		$cnnPatch =  New-Object Data.SqlClient.SqlConnection $ConnectionStringPatchDb
		$cnnPatch.Open()
		$totalRowsAffected = 0
		
		# Open ADO.NET Connection
		$cnn = New-Object Data.SqlClient.SqlConnection $ConnectionString
		$cnn.Open()

		while ($true) {
			try {
				$trxPatch = $cnnPatch.BeginTransaction("TransactionPatch")
				$trx = $cnn.BeginTransaction("Transaction")

				# New Command and Reader
				$cmdPatch = New-Object Data.SqlClient.SqlCommand $SqlDeleteTransactionalPatch, $cnnPatch
				#$cmdPatch.CommandTimeout = 30 # sec
				$cmdPatch.Transaction = $trxPatch
				$readerPatch = $cmdPatch.ExecuteReader()

				# Looping through records
				$iterationRowsWithNonEmptyMessage = 0
				$iterationRowsAffected = 0

				while ($readerPatch.Read()) {
					$iterationRowsAffected++
					$id = $readerPatch.GetInt64(0)
			    
					$SqlSelect = $SqlSelectFmt -f $id
					$cmd = New-Object Data.SqlClient.SqlCommand $SqlSelect, $cnn
					$cmd.Transaction = $trx
					$reader = $cmd.ExecuteReader()

					if (!$reader.Read()) {
						$reader.Close(); $reader = $null
						continue
					}

					$jsonEntrada = $null; $jsonSalida = $null
					
					# read data row
			        if (-not $reader.IsDBNull(0)) { $jsonEntrada = $reader.GetString(0) }
			        if (-not $reader.IsDBNull(1)) { $jsonSalida = $reader.GetString(1) }
					$dtCreado = $reader.GetDateTime(2)
					$lenEntrada = if ($jsonEntrada) { $jsonEntrada.Length } else { 0 }
					$lenSalida = if ($jsonSalida) { $jsonSalida.Length } else { 0 }
					
					$reader.Close(); $reader = $null

					$ContainerName = "{0}-{1:yyyy-MM}" -f $ContainerNamePrefix, $dtCreado
					"[{0}\{1}] bytes entrada/salida: {2:#,0} | {3:#,0}" -f $ContainerName, $id, $lenEntrada, $lenSalida
					# do not count rows with empty messages
					if ($lenEntrada -or $lenSalida) { $iterationRowsWithNonEmptyMessage++ }
					
					
					# upload blobs to azure
					if ($lenEntrada) { Upload-Blob -ID $id -json $jsonEntrada -ContainerName $ContainerName -blobNameSuffix "Entrada" -blobContext $blobContext }
					if ($lenSalida) { Upload-Blob -ID $id -json $jsonSalida -ContainerName $ContainerName -blobNameSuffix "Salida" -blobContext $blobContext }
				
					# null out blob-like fields on database
					if ($jsonEntrada -ne $null -or $jsonSalida -ne $null) {
						$SqlUpdate = $SqlUpdateFmt -f $id
						$cmd = New-Object Data.SqlClient.SqlCommand $SqlUpdate, $cnn
						$cmd.Transaction = $trx
						$affectedRowsOnUpdate = $cmd.ExecuteNonQuery()
					}
				}
				$totalRowsAffected += $iterationRowsWithNonEmptyMessage
				
				$readerPatch.Close(); $readerPatch = $null

				$trx.Commit(); $trx = $null
				$trxPatch.Commit(); $trxPatch = $null
				
				# stop no more files available
				if ($iterationRowsAffected -eq 0) { break }
				
				# stop if limit was reached
				if ($LimitRowsAffected -and $totalRowsAffected -ge $LimitRowsAffected) { break }
				
			} #end try
			catch {
				if ($readerPatch) { try { $readerPatch.Close() } catch { $_.Exception.Message } }
				if ($reader) { try { $reader.Close() } catch { $_.Exception.Message } }
				if ($trxPatch) { try { $trxPatch.Rollback() } catch { $_.Exception.Message } }
				if ($trx) { try { $trx.Rollback() } catch { $_.Exception.Message } }
				throw
			} # end catch
		} # end while

		$cnnPatch.Close(); $cnnPatch = $null
		$cnn.Close(); $cnn = $null
	} # end try
	catch {
		if ($cnn) { try { $cnn.Close() } catch { $_.Exception.Message } }
		if ($cnnPatch) { try { $cnnPatch.Close() } catch { $_.Exception.Message } }
		throw
	} # end catch
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------

UploadFromSqlToBlob-Document
