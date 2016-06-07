@ECHO OFF
SETLOCAL
PUSHD "%~dp0"

ECHO Creando MKLINK "Packages"
IF NOT EXIST Packages MKLINK /D Packages "C:\Temp\TempShared\Packages"

POPD
ENDLOCAL
PAUSE