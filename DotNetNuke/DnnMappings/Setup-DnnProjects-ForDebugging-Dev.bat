@ECHO OFF
SETLOCAL
PUSHD "%~dp0"
REM use current file name
SET MYSCRIPT=%~n0


SET PS_SCRIPT=
SET BRANCH_NAME=
FOR /F "tokens=1-2 usebackq delims=," %%I IN (`Powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command "&{ '%MYSCRIPT%' -replace '^(.+)-([^-]+)$','$1,$2' }"`) DO SET PS_SCRIPT=%%I& SET BRANCH_NAME=%%J
Powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File "%PS_SCRIPT%.ps1" -siteName "%BRANCH_NAME%.dnndev.me" -branchName "%BRANCH_NAME%"

ENDLOCAL
PAUSE
