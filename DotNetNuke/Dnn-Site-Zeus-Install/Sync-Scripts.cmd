@ECHO OFF
SETLOCAL
PUSH "%~dp0"

robocopy "C:\TFS\Zeus\Comun\Setup.Dnn\Zeus.Dnn.Setup.Component\Scripts" "Scripts" /MIR

PAUSE
ENDLOCAL