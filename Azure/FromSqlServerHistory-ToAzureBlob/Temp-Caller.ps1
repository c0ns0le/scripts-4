#$ConnectionStringPatchDb = 'Server={0};Database={1};Integrated Security=True' -f "FCDB1\DEV", "RepExt_Trunk_APP"
$ConnectionStringPatchDb = 'Server={0};Database={1};Integrated Security=True' -f ".\SQLEXPRESS", "gyf_patch"

$ConnectionString = 'Server={0};Database={1};Integrated Security=True' -f "FCDB1\DEV", "RepExt_Trunk_APP"

$StorageAccountName = 'girosyfinanzastest'
$StorageAccountKey = 'rnGSDPvJvNE5quodwOSHXhqWhS4XNf5M6K03cLJ/tWSkl8twANjr1xidqF1amVdPXjxOyWDxlu1yFwDZDRzyVA=='
$ContainerNamePrefix = 'dev-loghistory'

$TempTargetFolder = "C:\Temp\sqlfiles"
$BatchReadSize = 1
$LimitRowsAffected = 10

CD "C:\TFS1\Colab\PLColab\RepExt\Produccion\Persistencia\Patches\2016_06_14-FromSqlServerHistory-ToAzureBlob\"
.\FromSqlServerToBlobs.ps1 -ConnectionStringPatchDb $ConnectionStringPatchDb -ConnectionString $ConnectionString -TempTargetFolder $TempTargetFolder -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ContainerNamePrefix $ContainerNamePrefix -BatchReadSize $BatchReadSize -LimitRowsAffected $LimitRowsAffected
