#!/usr/bin/env python3
"""Local SNI forwarder for clients that ignore the system SOCKS proxy.

Discord's updater connects directly (no proxy support), so the DPI resets its
TLS handshake. When the blocked hostnames are pointed at 127.0.0.1 (e.g. via
dnscrypt-proxy cloaking rules), this script accepts those connections on
port 443, reads the hostname from the TLS ClientHello (SNI) and relays the
untouched TLS stream through ciadpi's SOCKS5 port. TLS stays end-to-end.

Usage: sni_forward.py [listen_port] [socks_port]
"""
import asyncio
import json
import struct
import sys
import time

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 443
SOCKS_ADDR = ("127.0.0.1", int(sys.argv[2]) if len(sys.argv) > 2 else 1080)
DOH_URL = "https://1.1.1.1/dns-query"
DNS_TTL = 300

_dns_cache = {}


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def parse_sni(hello):
    """Extract the server name from a TLS ClientHello handshake message."""
    try:
        p = 4 + 2 + 32                     # handshake header, version, random
        p += 1 + hello[p]                  # session id
        p += 2 + struct.unpack(">H", hello[p:p + 2])[0]   # cipher suites
        p += 1 + hello[p]                  # compression methods
        end = p + 2 + struct.unpack(">H", hello[p:p + 2])[0]
        p += 2
        while p + 4 <= end:
            etype, elen = struct.unpack(">HH", hello[p:p + 4])
            p += 4
            if etype == 0:
                nlen = struct.unpack(">H", hello[p + 3:p + 5])[0]
                return hello[p + 5:p + 5 + nlen].decode("ascii")
            p += elen
    except (IndexError, struct.error, UnicodeDecodeError):
        pass
    return None


async def resolve(host):
    """Resolve via DoH so cloaked names do not loop back to ourselves."""
    hit = _dns_cache.get(host)
    if hit and hit[1] > time.time():
        return hit[0]
    proc = await asyncio.create_subprocess_exec(
        "/usr/bin/curl", "-s", "-m", "8", "--noproxy", "*",
        "-H", "accept: application/dns-json",
        f"{DOH_URL}?name={host}&type=A",
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    out, _ = await proc.communicate()
    ips = [a["data"] for a in json.loads(out).get("Answer", []) if a.get("type") == 1]
    if not ips:
        raise RuntimeError(f"no A record for {host}")
    _dns_cache[host] = (ips[0], time.time() + DNS_TTL)
    return ips[0]


async def socks_connect(ip, port):
    r, w = await asyncio.open_connection(*SOCKS_ADDR)
    w.write(b"\x05\x01\x00")
    await r.readexactly(2)
    w.write(b"\x05\x01\x00\x01" + bytes(int(x) for x in ip.split(".")) + struct.pack(">H", port))
    rep = await r.readexactly(4)
    if rep[1] != 0:
        raise RuntimeError(f"socks error {rep[1]}")
    if rep[3] == 1:
        await r.readexactly(6)
    elif rep[3] == 4:
        await r.readexactly(18)
    else:
        await r.readexactly((await r.readexactly(1))[0] + 2)
    return r, w


async def pipe(r, w):
    try:
        while data := await r.read(65536):
            w.write(data)
            await w.drain()
    except (ConnectionError, OSError):
        pass
    finally:
        try:
            w.close()
        except OSError:
            pass


async def handle(cr, cw):
    host = None
    try:
        # We may be bound to all interfaces (see main), so refuse anything
        # that is not coming from this machine.
        if cw.get_extra_info("peername")[0] not in ("127.0.0.1", "::1", "::ffff:127.0.0.1"):
            return
        head = await asyncio.wait_for(cr.readexactly(5), 10)
        if head[0] != 0x16:
            return
        body = await asyncio.wait_for(cr.readexactly(struct.unpack(">H", head[3:5])[0]), 10)
        host = parse_sni(body)
        if not host:
            return
        ip = await resolve(host)
        if ip.startswith("127."):
            raise RuntimeError("resolved to loopback")
        sr, sw = await socks_connect(ip, 443)
        log("->", host, ip)
        sw.write(head + body)
        await sw.drain()
        await asyncio.gather(pipe(cr, sw), pipe(sr, cw))
    except Exception as e:
        log("ERR", host, repr(e))
    finally:
        try:
            cw.close()
        except OSError:
            pass


async def main():
    try:
        bind = "127.0.0.1"
        server = await asyncio.start_server(handle, bind, LISTEN_PORT)
    except PermissionError:
        # Without root, macOS only allows low ports on all interfaces.
        bind = "0.0.0.0"
        server = await asyncio.start_server(handle, bind, LISTEN_PORT)
    log(f"listening on {bind}:{LISTEN_PORT}, forwarding via socks5://{SOCKS_ADDR[0]}:{SOCKS_ADDR[1]}")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
