@ECHO OFF
SETLOCAL EnableExtensions

net session >nul 2>&1
IF ERRORLEVEL 1 (
  ECHO Yonetici izni isteniyor...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  EXIT /B
)

PUSHD "%~dp0"

set "_arch=x86"
IF "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set "_arch=x86_64")
IF DEFINED PROCESSOR_ARCHITEW6432 (set "_arch=x86_64")

set "EXE=%~dp0%_arch%\goodbyedpi.exe"

IF NOT EXIST "%EXE%" (
  ECHO.
  ECHO HATA: goodbyedpi.exe bulunamadi.
  ECHO ZIP dosyasini eksiksiz cikardiginizdan emin olun.
  ECHO Beklenen yol: %EXE%
  ECHO.
  PAUSE
  EXIT /B 1
)

ECHO.
ECHO GoodbyeDPI-Turkiye kuruluyor...
ECHO.

sc stop "GoodbyeDPI" >nul 2>&1
set /a WAIT=0

:WAIT_DELETE
sc query "GoodbyeDPI" >nul 2>&1
IF ERRORLEVEL 1 GOTO CREATE_SERVICE
sc delete "GoodbyeDPI" >nul 2>&1
ping -n 2 127.0.0.1 >nul
set /a WAIT+=1
IF %WAIT% GEQ 10 GOTO DELETE_FAIL
GOTO WAIT_DELETE

:DELETE_FAIL
ECHO HATA: Eski GoodbyeDPI hizmeti kaldirilamadi.
ECHO Bilgisayari yeniden baslatip bu dosyayi tekrar calistirin.
ECHO.
PAUSE
EXIT /B 1

:CREATE_SERVICE
sc create "GoodbyeDPI" binPath= "\"%EXE%\" -5 --set-ttl 5 --dns-addr 9.9.9.9 --dns-port 9953 --dnsv6-addr 2620:fe::fe --dnsv6-port 9953" start= "auto" >nul
IF ERRORLEVEL 1 (
  ECHO HATA: Hizmet olusturulamadi.
  ECHO.
  PAUSE
  EXIT /B 1
)

sc description "GoodbyeDPI" "Turkiye icin DNS zorlamasini kaldirir. Quad9 9.9.9.9:9953" >nul
sc start "GoodbyeDPI" >nul
IF ERRORLEVEL 1 (
  ECHO HATA: Hizmet baslatilamadi.
  ECHO.
  PAUSE
  EXIT /B 1
)

ipconfig /flushdns >nul 2>&1
ping -n 3 127.0.0.1 >nul

ECHO.
ECHO Roblox CDN testi yapiliyor...
where curl.exe >nul 2>&1
IF ERRORLEVEL 1 GOTO NO_CURL

set "CODE=000"
FOR /F "usebackq delims=" %%C IN (`curl.exe -sS --compressed --noproxy "*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -m 15 -o NUL -w "%%{http_code}" "https://tr.rbxcdn.com/180DAY-8b02a6f4a5eb20c7550bd69deeee034e/768/432/Image/Webp/noFilter" 2^>nul`) DO set "CODE=%%C"
IF "%CODE%"=="200" (
  ECHO   Roblox CDN: BASARILI
) ELSE (
  ECHO   Roblox CDN: BASARISIZ ^(HTTP %CODE%^)
  ECHO   Sorun devam ederse otomatik_method_sec.cmd dosyasini deneyin.
)
GOTO DONE

:NO_CURL
ECHO   curl.exe bulunamadi, test atlandi.

:DONE
ECHO.
ECHO ============================================
ECHO  Kurulum tamamlandi.
ECHO.
ECHO  Roblox ve Spotify'i yeniden baslatin.
ECHO  Sorun devam ederse otomatik_method_sec.cmd
ECHO  dosyasina cift tiklayin.
ECHO.
ECHO  Kaldirmak icin: service_remove.cmd
ECHO ============================================
ECHO.
PAUSE
POPD
EXIT /B 0
