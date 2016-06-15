@ECHO OFF
SETLOCAL
PUSHD "%~dp0"
IF NOT "%1"=="" (SET BATCH_READ_SIZE=%1) ELSE (SET BATCH_READ_SIZE=1)
IF NOT "%2"=="" (SET LIMIT_ROW_COUNT=%2) ELSE (SET LIMIT_ROW_COUNT=0)
REM
REM change from env to env
SET DB_CNNSTRING_PATCH=Server=.\SQLEXPRESS;Database=gyf_patch;Integrated Security=True
SET DB_SERVER=mycloudserver.database.windows.net
SET DB_NAME=test
SET DB_USER=test
SET DB_PWD=XcV$aQ7r2$
SET TEMP_FOLDER_FOR_PROCESSING=C:\Temp\sqltempblobfiles_test
SET STORAGE_ACCOUNT=test
SET STORAGE_KEY=asfdasdzxcASDASDFADFCVVASFQ234SDVAW345VXCVBASD
SET STORAGE_CONTAINER_PREFIX=logstest
REM
SET DB_CNNSTRING=Server=%DB_SERVER%;Database=%DB_NAME%;uid=%DB_USER%;pwd=%DB_PWD%;Pooling=False

Powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "FromSqlServerToBlobs.ps1" ^
  -ConnectionStringPatchDb "%DB_CNNSTRING_PATCH%" ^
  -ConnectionString "%DB_CNNSTRING%" ^
  -TempTargetFolder "%TEMP_FOLDER_FOR_PROCESSING%" ^
  -StorageAccountName "%STORAGE_ACCOUNT%" ^
  -StorageAccountKey "%STORAGE_KEY%" ^
  -ContainerNamePrefix "%STORAGE_CONTAINER_PREFIX%" ^
  -BatchReadSize "%BATCH_READ_SIZE%" ^
  -LimitRowsAffected %LIMIT_ROW_COUNT%

ENDLOCAL
EXIT