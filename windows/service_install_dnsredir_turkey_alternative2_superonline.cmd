@ECHO OFF
PUSHD "%~dp0"
set _arch=x86
IF "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set _arch=x86_64)
IF DEFINED PROCESSOR_ARCHITEW6432 (set _arch=x86_64)

echo DNS zorlamasini kaldiracak hizmeti yuklemek icin: (Alternatif Metod)
echo Bu batch dosyasini yonetici olarak calistirmaniz gerekmektedir.
echo Sag Tik - Yonetici Olarak Calistir.
echo Eger yonetici olarak calistirdiysaniz herhangi bir tusa basin.
echo Bu pencere kapandiktan sonra Windows ayarlarindan DNS degistirmeyi unutmayin.
echo DNS degisikliginin ardindan bilgisayarinizi yeniden baslatin.
pause
sc stop "GoodbyeDPI"
sc delete "GoodbyeDPI"
sc create "GoodbyeDPI" binPath= "\"%CD%\%_arch%\goodbyedpi.exe\" -5" start= "auto"
sc description "GoodbyeDPI" "Turkiye icin DNS zorlamasini kaldirir. Alternatif Metod 2"
sc start "GoodbyeDPI"

POPD
