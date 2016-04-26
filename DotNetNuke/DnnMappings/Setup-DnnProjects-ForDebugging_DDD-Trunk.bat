@ECHO OFF
SETLOCAL
PUSHD "%~dp0"
REM use current file name
SET MYSCRIPT=%~n0


SET PS_SCRIPT=
SET PROJECT_PREFIX=
SET BRANCH_NAME=
FOR /F "tokens=1-3 usebackq delims=," %%I IN (`Powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -Command "&{ '%MYSCRIPT%' -replace '^(.+)_([^-]+)-([^-]+)$','$1,$2,$3' }"`) DO SET PS_SCRIPT=%%I& SET PROJECT_PREFIX=%%J& SET BRANCH_NAME=%%K
Powershell -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File "%PS_SCRIPT%.ps1" -siteName "%PROJECT_PREFIX%-%BRANCH_NAME%.dnndev.me" -branchName "%BRANCH_NAME%"

ENDLOCAL
PAUSE
