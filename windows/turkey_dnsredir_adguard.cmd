@ECHO OFF
PUSHD "%~dp0"
set _arch=x86
IF "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set _arch=x86_64)
IF DEFINED PROCESSOR_ARCHITEW6432 (set _arch=x86_64)
PUSHD "%_arch%"

start "" goodbyedpi.exe -5 --dns-addr 94.140.14.140 --dns-port 5353 --dnsv6-addr 2a10:50c0::1:ff --dnsv6-port 5353

POPD
POPD
