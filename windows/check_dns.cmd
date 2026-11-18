@ECHO OFF
PUSHD "%~dp0"
ECHO.
ECHO Quad9 DNS (9.9.9.9:9953) uzerinden CDN alan adlari test ediliyor...
ECHO Bu test, GoodbyeDPI'in kullandigi DNS sunucusunun Roblox/Spotify
ECHO gorsellerini cozebildigini dogrular (issue #93).
ECHO.
ECHO --- Roblox gorsel CDN'i (tr.rbxcdn.com) ---
nslookup -vc -port=9953 tr.rbxcdn.com 9.9.9.9
ECHO.
ECHO --- Spotify gorsel CDN'i (i.scdn.co) ---
nslookup -vc -port=9953 i.scdn.co 9.9.9.9
ECHO.
ECHO --- Discord CDN'i (cdn.discordapp.com) ---
nslookup -vc -port=9953 cdn.discordapp.com 9.9.9.9
ECHO.
ECHO Sonuc yukarida listelenen IP adresleridir. "Addresses:" altinda en az bir
ECHO IP adresi varsa DNS calisiyor demektir. Bos yanit veya zaman asimi alirsaniz
ECHO ISS'niz 9953 portunu engelliyor olabilir; README.md icindeki DNS bolumune bakin.
ECHO Not: Bu test TCP kullanir. GoodbyeDPI DNS sorgularini UDP uzerinden yonlendirir;
ECHO TCP 9953 engelli olsa bile GoodbyeDPI calisabilir.
ECHO.
pause
POPD
