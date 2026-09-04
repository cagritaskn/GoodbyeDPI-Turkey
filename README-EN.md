[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)
[![Downloads](https://img.shields.io/github/downloads/cagritaskn/GoodbyeDPI-Turkey/total.svg)](https://github.com/cagritaskn/GoodbyeDPI-Turkey/releases/)

[Türkçe](README.md) | **English**

# Important Note About SplitWire-Turkey (29.07.2025)
>
> [!IMPORTANT]
> Since some users reported issues accessing Discord or loading certain content on other websites, we released **[SplitWire-Turkey](https://github.com/cagritaskn/SplitWire-Turkey)**, which works with different methods but the same purpose. After removing GoodbyeDPI (see the [GoodbyeDPI-Turkey correct removal guide](https://github.com/cagritaskn/GoodbyeDPI-Turkey/blob/master/REVERT.md)), you can try **[this tool](https://github.com/cagritaskn/SplitWire-Turkey)**.

# Important Note About Kaspersky Antivirus (13.01.2025)
>
> [!CAUTION]
> Due to its agreement with the Russian government, the antivirus software called Kaspersky prevents GoodbyeDPI from working. If you use, have used, or even have Kaspersky installed (even disabled) on your computer, please remove it completely. Otherwise GoodbyeDPI most likely will not work. You can prefer alternative antivirus software or use Windows Defender. (As of 2025, Windows Defender is more than adequate at blocking malware and malicious sites.)
> Disabling Kaspersky while downloading the GoodbyeDPI ZIP, adding it to exclusions afterwards, or disabling it will not solve the problem. To use GoodbyeDPI correctly, you must get rid of Kaspersky one way or another.

## Summary

This project is a modified version of GoodbyeDPI designed to access Discord and other blocked sites/apps without a VPN and without slowing down your internet.

## GoodbyeDPI — Deep Packet Inspection (DPI) bypass tool (Turkey edition)

Because some ISPs in Turkey do not allow DNS changes, this application is a modified version of the original [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI) project meant to work around that restriction.
It is designed to bypass the "Deep Packet Inspection" (DPI) systems found in many ISPs that block access to certain websites.
It handles passive DPI (connected via optical splitter or port mirroring, which does not block data but responds faster than the intended destination) and active, inline DPI. This application is definitely **not** a VPN and will not cause any speed change in games or general internet use.

> [!NOTE]
> On Windows 7, 8, 8.1, 10 or 11 you **must run it as Administrator**.

## Virus & Data Leak & Bitcoin Mining

Because the program is open source, you can read and review all of its code. Although some users report false positives on VirusTotal, this is caused by the functions of the `WinDivert.dll` and `WinDivert64.sys` files (these files affect the system). These .dll and .sys files are also open source and can be reviewed — meaning they are completely clean. Users who do not want to or do not trust it are not obligated to use it; the choice is everyone's own.
If you wish, you can scan the whole folder or the .zip file on a site like [VirusTotal](https://www.virustotal.com/gui/home/upload) and review the results.

> [!IMPORTANT]
> Do not be alarmed by the Bitcoin address you see in the WinDivert file descriptions or when trying to delete them. WinDivert is an open-source Windows packet inspection/modification library by a developer named [basil00](https://github.com/basil00), shared for free at [GitHub - WinDivert](https://github.com/basil00/WinDivert). The Bitcoin text and address are simply the developer's donation wallet, also published on the [official donation page](https://reqrypt.org/donate.html).

## Using GoodbyeDPI

There are three ways to use this Turkey fork of GoodbyeDPI.

- **Using the Control Panel (Recommended):** A Turkish/English graphical interface that lets you turn GoodbyeDPI on/off with one click and pick a method. Details below.
- Using it as a service: Install the service once and it runs automatically every time your computer restarts, with nothing to launch manually.
- Using the batch file: You must launch the batch file manually every time (GoodbyeDPI stops when the batch window is closed).

> [!NOTE]
> Do not move the extracted ZIP contents from where you extracted them. The installed service uses the file path where you ran the .cmd file, so moving the files will break the service. (Recommendation: extract the ZIP to a location that will not bother you and keep the files there, e.g. `C:\GoodbyeDPI\`.)

## GoodbyeDPI Control Panel (On/Off GUI)

`GoodbyeDPI-Kontrol.cmd` is a bilingual (Turkish/English) control panel that lets you **turn GoodbyeDPI on and off with a single click**. Instead of running separate `.cmd` files, you manage the service from the interface.

**Features:**

- **On/Off button:** Starts or stops the GoodbyeDPI service with one click (green = start, red = stop).
- **Method selector:** All 7 methods shipped with the fork (main method + 6 SuperOnline alternatives) are selectable from a dropdown. If you change the method while the service is running, it is automatically reinstalled with the new method.
- **Language button:** The `EN`/`TR` button at the top-right switches the interface language instantly. On first launch it is auto-selected based on your Windows language.
- **Reinstall / Remove service:** Bottom buttons to manually reinstall or completely remove the service.
- **Admin elevation:** If you are not an administrator, it automatically requests elevation.
- **Architecture detection:** Automatically detects 32-bit (x86) and 64-bit (x86_64) Windows; works on Windows 7/8/8.1/10/11.
- Your selected method and language are saved to `GoodbyeDPI-Kontrol.config.json` and remembered on the next launch.

**How to use:**

- Double-click `GoodbyeDPI-Kontrol.cmd` (admin permission is requested automatically).
- Pick the method that fits your ISP (if unsure, start with "Recommended - Main method").
- Press the big button to turn GoodbyeDPI on.

> [!NOTE]
> For methods that do not set DNS (Alt 1, 2, 6), the interface warns you: you must set your Windows DNS to Yandex (77.88.8.8) manually. For methods with preset Yandex DNS (Main, Alt 3, 4, 5) this is not needed.

## Using It as a Service (runs automatically at Windows startup)

To use the Turkey edition of GoodbyeDPI as a service:

- Download [goodbyedpi-0.2.3rc3-turkey.zip](https://github.com/cagritaskn/GoodbyeDPI-Turkey/releases/download/release-0.2.3rc3-turkey/goodbyedpi-0.2.3rc3-turkey.zip).
- Extract the ZIP to any directory.
- Right-click `service_install_dnsredir_turkey.cmd` and choose `Run as administrator`.
- Press any key in the console window that opens.
- The window will close automatically once the service is installed, and the service will start automatically.

> [!NOTE]
> This installs the GoodbyeDPI service on your computer. To remove it, run `service_remove.cmd` as administrator.

## Using the Batch File (one-off, stops when the window is closed)

To use the Turkey fork by running the batch file **(a command window opens and the app starts running; closing this window stops it)**:

- Download [goodbyedpi-0.2.3rc3-turkey.zip](https://github.com/cagritaskn/GoodbyeDPI-Turkey/releases/download/release-0.2.3rc3-turkey/goodbyedpi-0.2.3rc3-turkey.zip).
- Extract the ZIP to any directory.
- Right-click `turkey_dnsredir.cmd` and choose `Run as administrator`.

> [!NOTE]
> When you run `turkey_dnsredir.cmd` as administrator, GoodbyeDPI becomes active. However, with this method you must turn GoodbyeDPI on manually after every restart, and it deactivates when the window opened by `turkey_dnsredir.cmd` is closed.

## Removing GoodbyeDPI and Reverting DNS Settings

To completely turn off and delete GoodbyeDPI and revert the DNS assignment, follow **[this guide](https://github.com/cagritaskn/GoodbyeDPI-Turkey/blob/master/REVERT.md)**.

## Methods Reference

The control panel and the `.cmd` files ship the following methods. Methods marked "Preset DNS" configure Yandex DNS themselves; the others require you to set Windows DNS manually.

| Method | GoodbyeDPI arguments | DNS |
| --- | --- | --- |
| Main (recommended) | `-5 --set-ttl 5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253` | Preset |
| SuperOnline Alt 3 | `--set-ttl 3 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253` | Preset |
| SuperOnline Alt 4 | `-5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253` | Preset |
| SuperOnline Alt 5 | `-9 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253` | Preset |
| SuperOnline Alt 1 | `--set-ttl 3` | Manual |
| SuperOnline Alt 2 | `-5` | Manual |
| SuperOnline Alt 6 | `-9` | Manual |

## Common Problems

- **WinDivert files not found error (false-positive virus detection):** Add the extracted folder to your antivirus exclusions. For Windows Defender see [this guide](https://support.microsoft.com/en-us/windows/add-an-exclusion-to-windows-security-811816c0-4dfd-af4a-47e4-c301afe13b26). Adding an exclusion may not always solve it; in that case you may need to completely remove Kaspersky and reinstall GoodbyeDPI-Turkey.
- **"File path not found" error when the service tries to start:** This happens if you move the extracted folder or delete some files. Re-extract the ZIP, run `service_remove.cmd` as administrator, then run your chosen `.cmd` file again.
- **Some sites open slowly / do not open:** This can happen with TTL-based methods. Try the no-TTL alternatives (Alt 2 or Alt 4). Remove the current service with `service_remove.cmd` first, then install the alternative.
- **Discord opens in the browser but the app won't launch:** Common on fiber plans, with no guaranteed fix. Try [WinDivertTool.exe](https://github.com/basil00/WinDivertTool/releases/download/v2.2.0/WinDivertTool.exe): it lists which apps use WinDivert; delete any stale ones except the one from your latest install, then restart.

## DNS and Port Configuration

By default these scripts use **Yandex DNS**. To use a different DNS, edit the DNS/port values in the `.cmd` files (or pick a method in the control panel). Recommended: Yandex DNS (77.88.8.8 / 77.88.8.1), Cloudflare DNS (1.1.1.1 / 1.0.0.1). For methods without preset DNS (Alt 1, 2, 6), set your Windows DNS manually.

## Donation and Support

Using this program is completely free. To support continued work, you can use the sponsor links below.

**GitHub Sponsor:**

[![Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/cagritaskn)

**Patreon:**

[![Static Badge](https://img.shields.io/badge/cagritaskn-purple?logo=patreon&label=Patreon)](https://www.patreon.com/cagritaskn/membership)

## Legal Notice
>
> [!IMPORTANT]
> All legal responsibility arising from the use of this application belongs to the user. The application is written and modified solely for educational and research purposes; using it or not, under these conditions, is the user's own choice. This modified project, shared on this open-source platform, is written and modified for the purposes of information sharing and coding education.
