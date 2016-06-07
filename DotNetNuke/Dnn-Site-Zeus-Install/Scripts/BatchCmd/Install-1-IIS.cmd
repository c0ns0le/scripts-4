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

REM local
SET BASEDIR=C:\TFS\Zeus\Comun\Setup.Dnn\Zeus.Dnn.Setup.Component
SET DNN_ZIP=D:\Instaladores\DotNetNuke\07.03.04\DNN_Platform_07.03.04_Install.zip
SET DNN_EXTRA_MODULES=%USERPROFILE%\Documents\GitHub\scripts\DotNetNuke\Dnn-Site-Zeus-Install\ExtraModules
SET INSTALL_SCRIPT_FOLDER=%BASEDIR%\Scripts\Powershell


%PS% "%INSTALL_SCRIPT_FOLDER%\%~n0.ps1"

ENDLOCAL