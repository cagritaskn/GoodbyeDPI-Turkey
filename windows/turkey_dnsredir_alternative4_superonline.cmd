@ECHO OFF
PUSHD "%~dp0"
set _arch=x86
IF "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set _arch=x86_64)
IF DEFINED PROCESSOR_ARCHITEW6432 (set _arch=x86_64)
PUSHD "%_arch%"

start "" goodbyedpi.exe -5 --dns-addr 9.9.9.9 --dns-port 9953 --dnsv6-addr 2620:fe::fe --dnsv6-port 9953

POPD
POPD
