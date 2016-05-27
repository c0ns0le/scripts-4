@ECHO OFF
SETLOCAL
SET BASE=%~n0

Powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "%BASE%.ps1" > "%BASE%.log" 2>&1

ENDLOCAL