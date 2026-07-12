@echo off
rem ===========================================================================
rem  Einstiegspunkt: einfach doppelklicken.
rem
rem  Ruft install.ps1 auf und umgeht dabei die Windows-Skriptsperre
rem  (ExecutionPolicy), damit nichts von Hand freigeschaltet werden muss.
rem ===========================================================================

chcp 65001 >nul
cd /d "%~dp0"

set "PSEXE=powershell"
where pwsh >nul 2>&1 && set "PSEXE=pwsh"

"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*

echo.
pause
