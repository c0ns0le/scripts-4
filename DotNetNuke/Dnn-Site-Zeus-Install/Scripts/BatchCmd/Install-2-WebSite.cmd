@ECHO OFF
SETLOCAL
CLS
SET PS=Powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File

REM virtual machine
SET BASEDIR=E:\Setup.Dnn\****
SET DNN_ZIP=E:\DNN_Platform_07.03.04_Install.zip
SET DNN_EXTRA_MODULES_FOLDER=E:\Packages\Modules
SET INSTALL_SCRIPT_FOLDER=%BASEDIR%\Scripts\Powershell

REM cloud
SET BASEDIR=%USERPROFILE%\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install
SET DNN_ZIP=%USERPROFILE%\Downloads\DNN_Platform_07.03.04_Install.zip
SET DNN_EXTRA_MODULES=%BASEDIR%\ExtraModules
SET INSTALL_SCRIPT_FOLDER=%BASEDIR%\Scripts\Powershell

%PS% "%INSTALL_SCRIPT_FOLDER%\%~n0.ps1" ^
  -DnnInstallZip "%DNN_ZIP%" ^
  -Destination "C:\Zeus Software\web" ^
  -ExtraModulesFolder "%DNN_EXTRA_MODULES_FOLDER%" ^
  -AppPoolName "zeusweb" ^
  -AppPoolUserName "temphost" ^
  -AppPoolPassword 'abc123$' ^
  -AppPoolEnable32BitAppOnWin64 1 ^
  -SiteName "hotel-portal.dnndev.me" ^
  -SiteAlias "portal.dnndev.me" ^
  -SitePort 80 ^
  -MaxRequestMB 100 ^
  -RuntimeExecutionTimeout 1200 ^
  -RuntimeRequestLengthDiskThreshold 90000 ^
  -RuntimeMaxUrlLength 5000 ^
  -RuntimeRelaxedUrlToFileSystemMapping "true" ^
  -RuntimeMaxQueryStringLength 50000 ^
  -ProviderEnablePasswordRetrieval "true" ^
  -ProviderMinRequiredPasswordLength 6 ^
  -ProviderPasswordFormat "Encrypted"

ENDLOCAL