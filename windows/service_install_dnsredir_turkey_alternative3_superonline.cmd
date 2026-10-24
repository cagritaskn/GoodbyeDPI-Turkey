@ECHO OFF
PUSHD "%~dp0"
set _arch=x86
IF "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set _arch=x86_64)
IF DEFINED PROCESSOR_ARCHITEW6432 (set _arch=x86_64)

echo DNS zorlamasini kaldiracak hizmeti yuklemek icin: (Alternatif Metod 3)
echo Bu batch dosyasini yonetici olarak calistirmaniz gerekmektedir.
echo Sag Tik - Yonetici Olarak Calistir.
echo Eger yonetici olarak calistirdiysaniz herhangi bir tusa basin.
pause
sc stop "GoodbyeDPI"
sc delete "GoodbyeDPI"
sc create "GoodbyeDPI" binPath= "\"%CD%\%_arch%\goodbyedpi.exe\" --set-ttl 3 --dns-addr 9.9.9.9 --dns-port 9953 --dnsv6-addr 2620:fe::fe --dnsv6-port 9953" start= "auto"
sc description "GoodbyeDPI" "Turkiye icin DNS zorlamasini kaldirir. Alternatif Metod 3"
sc start "GoodbyeDPI"
ipconfig /flushdns

POPD
