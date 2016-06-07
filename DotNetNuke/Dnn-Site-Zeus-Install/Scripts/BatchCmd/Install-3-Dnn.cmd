@ECHO OFF
SETLOCAL
CLS
SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File

REM virtual machine
SET BASEDIR=E:\Setup.Dnn\****
SET INSTALL_SCRIPT_FOLDER=%BASEDIR%\Scripts\Powershell
SET DNN_DB_SERVER=%COMPUTERNAME%\SQL2014

REM cloud
SET BASEDIR=%USERPROFILE%\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install
SET INSTALL_SCRIPT_FOLDER=%BASEDIR%\Scripts\Powershell
SET DNN_DB_SERVER=%COMPUTERNAME%\SQLExpress

REM local
SET BASEDIR=C:\TFS\Zeus\Comun\Setup.Dnn\Zeus.Dnn.Setup.Component
SET INSTALL_SCRIPT_FOLDER=%BASEDIR%\Scripts\Powershell
SET DNN_DB_SERVER=%COMPUTERNAME%\SQL2014


%PS% "%INSTALL_SCRIPT_FOLDER%\%~n0.ps1" ^
  -DnnRootUrl "http://hotel-portal.dnndev.me" ^
  -DnnUsername "host" ^
  -DnnPassword 'abc123$' ^
  -DnnEmail "host@change.me" ^
  -DnnDatabaseServerName "%DNN_DB_SERVER%" ^
  -DnnDatabaseName "hotel-portal" ^
  -DnnDatabaseObjectQualifier "dnn" ^
  -DnnDatabaseUsername "" ^
  -DnnDatabasePassword "" ^
  -DnnWebsiteTitle "Sitio Web Dnn" ^
  -DnnTemplate "Blank Website.template" ^
  -DnnLanguage "es-ES"

ENDLOCAL