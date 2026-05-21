@echo off
setlocal

set "SCRIPT_PATH=C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\kubernetes_monitors.ps1"
set "POWERSHELL_PATH=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%POWERSHELL_PATH%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

endlocal
exit /b 0