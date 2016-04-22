@ECHO OFF
SETLOCAL
PUSHD "%~dp0"
REM use current file name
SET BRANCH_NAME=%~n0

Powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File Create-Mappings.ps1 "%BRANCH_NAME%"

PAUSE
ENDLOCAL