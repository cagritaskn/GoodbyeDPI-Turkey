@ECHO OFF
PUSHD "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GoodbyeDPI-Kontrol.ps1"
POPD
