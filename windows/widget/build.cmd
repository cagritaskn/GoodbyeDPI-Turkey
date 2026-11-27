@ECHO OFF
REM GoodbyeDPI-Widget.exe derlemesi. Windows ile gelen .NET Framework 4 derleyicisini kullanir.
REM Cikti: windows\GoodbyeDPI-Widget.exe (service_*.cmd scriptleriyle ayni klasor)
PUSHD "%~dp0"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
IF NOT EXIST "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
"%CSC%" /nologo /target:winexe /optimize+ /codepage:65001 ^
  /win32icon:..\..\src\icon.ico /win32manifest:app.manifest ^
  /reference:System.ServiceProcess.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ^
  /out:..\GoodbyeDPI-Widget.exe GoodbyeDPIWidget.cs WidgetForm.cs
set _rc=%ERRORLEVEL%
POPD
EXIT /B %_rc%
