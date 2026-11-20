@ECHO OFF
SETLOCAL EnableExtensions
PUSHD "%~dp0"

set "_arch=x86"
IF "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set "_arch=x86_64")
IF DEFINED PROCESSOR_ARCHITEW6432 (set "_arch=x86_64")

set "EXE=%~dp0%_arch%\goodbyedpi.exe"
set "DNS=--dns-addr 9.9.9.9 --dns-port 9953 --dnsv6-addr 2620:fe::fe --dnsv6-port 9953"
set "TEST_URL=https://discord.com/api/v10/gateway"
set "CDN_URL=https://tr.rbxcdn.com/180DAY-8b02a6f4a5eb20c7550bd69deeee034e/768/432/Image/Webp/noFilter"
set "BODY=%TEMP%\gdp_autotest_body.txt"

net session >nul 2>&1
IF ERRORLEVEL 1 (
  ECHO Bu scripti yonetici olarak calistirmaniz gerekiyor.
  ECHO Sag tik - Yonetici Olarak Calistir.
  PAUSE
  EXIT /B 1
)

IF NOT EXIST "%EXE%" (
  ECHO goodbyedpi.exe bulunamadi:
  ECHO   %EXE%
  ECHO ZIP dosyasini eksiksiz cikardiginizdan emin olun.
  PAUSE
  EXIT /B 1
)

where curl.exe >nul 2>&1
IF ERRORLEVEL 1 (
  ECHO curl.exe bulunamadi. Windows 10 1803 veya uzeri gerekli.
  PAUSE
  EXIT /B 1
)

ECHO.
ECHO GoodbyeDPI yontem testi
ECHO =========================
ECHO Hizmet birkac kez durdurulup baslatilacak.
ECHO Bu islem 1-3 dakika surer.
ECHO.

sc query "GoodbyeDPI" >nul 2>&1
IF NOT ERRORLEVEL 1 (
  sc qc "GoodbyeDPI" > "%~dp0service-config-before-autotest.txt" 2>nul
  ECHO Mevcut hizmet yapilandirmasi kaydedildi:
  ECHO   %~dp0service-config-before-autotest.txt
  ECHO.
)

set "SELECTED="
set "SELECTED_ARGS="
set "FALLBACK="
set "FALLBACK_ARGS="

CALL :TRY "Varsayilan -5 set-ttl 5" "-5 --set-ttl 5"
CALL :TRY "Alternatif 1-3 set-ttl 3" "--set-ttl 3"
CALL :TRY "Alternatif 2-4 -5" "-5"
CALL :TRY "Alternatif 5-6 -9" "-9"

ECHO.
ECHO =========================
IF DEFINED SELECTED GOTO INSTALL_SELECTED
IF DEFINED FALLBACK GOTO INSTALL_FALLBACK
GOTO INSTALL_DEFAULT

:INSTALL_SELECTED
ECHO Secilen yontem: %SELECTED%
CALL :INSTALL "%SELECTED%" "%SELECTED_ARGS%"
IF ERRORLEVEL 1 (
  ECHO HATA: Secilen yontem kurulamadi.
  GOTO FINAL_PAUSE
)
GOTO FINAL_REPORT

:INSTALL_FALLBACK
ECHO Discord testini gecen yontem olmadi.
ECHO Roblox CDN testini gecen yontem kuruluyor: %FALLBACK%
CALL :INSTALL "%FALLBACK%" "%FALLBACK_ARGS%"
GOTO FINAL_REPORT

:INSTALL_DEFAULT
ECHO Hicbir yontem testi gecemedi.
ECHO Varsayilan yontem kuruluyor.
CALL :INSTALL "Varsayilan -5 set-ttl 5" "-5 --set-ttl 5"

:FINAL_REPORT
ipconfig /flushdns >nul 2>&1
ECHO.
ECHO Hizmet durumu:
sc query "GoodbyeDPI" | findstr /C:"STATE"
ECHO.
ECHO Kaldirmak icin: service_remove.cmd

:FINAL_PAUSE
PAUSE
POPD
EXIT /B 0


:TRY
set "NAME=%~1"
set "ARGS=%~2"
ECHO.
ECHO ------------------------------------------
ECHO Deneniyor: %NAME%
ECHO ------------------------------------------
CALL :INSTALL "%NAME%" "%ARGS%"
IF ERRORLEVEL 1 (
  ECHO   Hizmet baslatilamadi, bu yontem atlaniyor.
  EXIT /B 0
)

ipconfig /flushdns >nul 2>&1
ping -n 3 127.0.0.1 >nul

set "DISCORD_OK=0"
set "DISCORD_CODE=000"
FOR /F "usebackq delims=" %%C IN (`curl.exe -sS --compressed --noproxy "*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -m 15 -o "%BODY%" -w "%%{http_code}" "%TEST_URL%" 2^>nul`) DO set "DISCORD_CODE=%%C"
IF "%DISCORD_CODE%"=="200" (
  findstr /C:"gateway" "%BODY%" >nul 2>&1
  IF NOT ERRORLEVEL 1 set "DISCORD_OK=1"
)
IF "%DISCORD_OK%"=="1" (
  ECHO   Discord: BASARILI ^(HTTP %DISCORD_CODE%^)
  IF NOT DEFINED SELECTED (
    set "SELECTED=%NAME%"
    set "SELECTED_ARGS=%ARGS%"
  )
) ELSE (
  ECHO   Discord: BASARISIZ ^(HTTP %DISCORD_CODE%^)
)

set "CDN_OK=0"
set "CDN_CODE=000"
FOR /F "usebackq delims=" %%C IN (`curl.exe -sS --compressed --noproxy "*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -m 15 -o NUL -w "%%{http_code}" "%CDN_URL%" 2^>nul`) DO set "CDN_CODE=%%C"
IF "%CDN_CODE%"=="200" (
  ECHO   Roblox CDN: BASARILI ^(HTTP 200^)
  IF NOT DEFINED FALLBACK (
    set "FALLBACK=%NAME%"
    set "FALLBACK_ARGS=%ARGS%"
  )
) ELSE (
  ECHO   Roblox CDN: BASARISIZ ^(HTTP %CDN_CODE%^)
)
EXIT /B 0


:INSTALL
set "NAME=%~1"
set "ARGS=%~2"

sc query "GoodbyeDPI" >nul 2>&1
IF ERRORLEVEL 1 GOTO INSTALL_CREATE

sc stop "GoodbyeDPI" >nul 2>&1
set /a WAIT=0
:INSTALL_WAIT
sc query "GoodbyeDPI" | findstr /C:"STOPPED" >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO INSTALL_CONFIG
set /a WAIT+=1
IF %WAIT% GEQ 15 GOTO INSTALL_TIMEOUT
ping -n 2 127.0.0.1 >nul
GOTO INSTALL_WAIT

:INSTALL_TIMEOUT
ECHO   HATA: Hizmet durdurulamadi.
EXIT /B 1

:INSTALL_CONFIG
sc config "GoodbyeDPI" binPath= "\"%EXE%\" %ARGS% %DNS%" start= "auto" >nul 2>&1
IF ERRORLEVEL 1 (
  ECHO   HATA: Hizmet yapilandirilamadi.
  EXIT /B 1
)
GOTO INSTALL_START

:INSTALL_CREATE
sc create "GoodbyeDPI" binPath= "\"%EXE%\" %ARGS% %DNS%" start= "auto" >nul 2>&1
IF ERRORLEVEL 1 (
  ECHO   HATA: Hizmet olusturulamadi.
  EXIT /B 1
)

:INSTALL_START
sc description "GoodbyeDPI" "Turkiye icin DNS zorlamasini kaldirir. %NAME%" >nul 2>&1
sc start "GoodbyeDPI" >nul 2>&1
IF ERRORLEVEL 1 (
  ECHO   HATA: Hizmet baslatilamadi.
  EXIT /B 1
)
EXIT /B 0
