#requires -Version 4
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Enter description here
.EXAMPLE
 Enter example here
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$ErrorActionPreference = "Stop"  # Set Error Action to Stop
$Script:ScriptVersion = "1.0"    # Script Version

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Upload-AzureBlob($storageAccountName, $storageAccountKey, $containerName) {
	# Azure subscription-specific variables.
	$storageAccountName = "storage-account-name"
	$containerName = "container-name"

	# Find the local folder where this PowerShell script is stored.
	$currentLocation = Get-location
	$thisfolder = Split –parent $currentLocation

	# Upload files in data subfolder to Azure.
	$localfolder = "$thisfolder\data"
	$destfolder = "data"
	$blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
	$files = Get-ChildItem $localFolder

	foreach($file in $files)
	{
		$fileName = "$localFolder\$file"
		$blobName = "$destfolder/$file"
		write-host "copying $fileName to $blobName"
		Set-AzureStorageBlobContent -File $filename -Container $containerName -Blob $blobName -Context $blobContext -Force
	}
	write-host "All files in $localFolder uploaded to $containerName!"
}


Function GetNext-SqlDocument($ConnectionString, $storageAccountName, $storageAccountKey, $containerName, $destfolder) {
	try {
		$Sql = "SELECT TOP 10 id_LogTransaccion, ds_MensajeEntrada FROM Historial.LogsTransacciones WHERE ds_MensajeEntrada IS NOT NULL"

		# Open ADO.NET Connection
		$cnn = New-Object Data.SqlClient.SqlConnection $ConnectionString
		$cnn.ConnectionString = $ConnectionString
		$cnn.Open()

		$blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
		Set-AzureStorageBlobContent -File $filename -Container $containerName -Blob $blobName -Context $blobContext -Force

		# New Command and Reader
		$cmd = New-Object Data.SqlClient.SqlCommand $Sql, $cnn
		$rd = $cmd.ExecuteReader()

		if (-not (Test-Path $TargetPath -PathType Container)) { mkdir $TargetPath | Out-Null }

		# Looping through records
		While ($rd.Read())
		{
		    $id = $rd.GetInt64(0)
	        $inputJson = $rd["ds_MensajeEntrada"] -as [string]
			$path = "{0}\{1}_Entrada.json" -f $TargetPath, $id
			
			if ($inputJson.Length) {
				"[{0}] {1} bytes" -f $id, $inputJson.Length
		        [IO.File]::WriteAllText($path, $inputJson, [Text.Encoding]::UTF8)

				Set-AzureStorageBlobContent -File $path -Container $containerName -Blob $blobName -Context $blobContext -Force
			}
		}

		$cnn.Close()
	}
	catch {
		if ($cnn) {
			try { $cnn.Close() } catch { $_.Exception.Message; }
		}
		throw
	}
}

#-----------------------------------------------------------[Initialize]-----------------------------------------------------------
Clear-Host

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$ConnectionString = 'Server=FCDB1\DEV;Database=RepExt_Trunk_APP;Integrated Security=True'
$TargetPath = "C:\Temp\sqlfiles"

GetNext-SqlDocument -ConnectionString $ConnectionString -TargetPath $TargetPath
