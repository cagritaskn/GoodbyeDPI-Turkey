# AGENTS.md — working in GoodbyeDPI-Turkey

Instructions for an agent editing this repository. All facts below were
verified in this worktree on a Linux x86_64 host (`uname -s` -> `Linux`,
`uname -m` -> `x86_64`, exit 0). Anything that needs macOS, Windows, or a
compiler that is not installed here is marked **not runnable locally**.

## Project map

GoodbyeDPI is a Windows DPI-bypass tool driven by the WinDivert kernel driver.
This repository is a **Turkish fork** that adds launchers and a macOS port on
top of the upstream program.

| Path | What it is | Owner |
| --- | --- | --- |
| `src/` | Upstream GoodbyeDPI C sources: `goodbyedpi.c`, `dnsredir.c`, `fakepackets.c`, `ttltrack.c`, `blackwhitelist.c`, `service.c`, `utils/` (`getline.c`, `repl_str.c`, `uthash.h`), plus an RC file, manifest and icon. Built with `src/Makefile` against **WinDivert headers/libs + a MinGW cross-compiler** into `goodbyedpi.exe`. Compiled on GitHub Actions (`.github/workflows/build.yml`, x86_64 and i686). | **Upstream** (ValdikSS/GoodbyeDPI). The fork only carries a couple of small patches here (`git log -- src` -> "Update goodbyedpi.c", "Add TLS ClientHello fake packet generator"). Treat it as vendored: do not restyle or refactor it. |
| `windows/` | 15 `.cmd` one-shot and service-install launchers (`turkey_dnsredir*.cmd`, `service_install_*.cmd`, `service_remove.cmd`) plus `README-BEN OKU.txt`. These are the user-facing entry points on Windows and are the reference behaviour the macOS scripts mirror. | **Fork** (Turkish presets, Turkish text, CRLF). |
| `macos/` | The bash port. `build.sh` clones byedpi and compiles `ciadpi` into `macos/bin/`; `Makefile` is a thin `make build` / `make clean` wrapper over it; `scripts/_lib.sh` holds the shared helpers; `scripts/turkey_dnsredir*.sh` are one-shot runners, `scripts/service_install_*.sh` install a launchd LaunchDaemon, `scripts/service_remove.sh` removes it, `scripts/split_tunnel.sh` switches the system proxy for a PAC file; `launchd/*.plist.template` is the daemon template; `split-tunnel-domains.txt` is the split-tunnel domain list; `README.md` is the macOS user guide. | **Fork**. |
| `REVERT.md` | Turkish uninstall manual: how to stop the tool, delete the service, and restore DNS. | **Fork**. |
| `README.md` | Turkish top-level user guide (Windows focus, macOS quick start). | **Fork**. |

Deployment model, because it explains the code shape: Windows uses WinDivert
(kernel driver). macOS has no equivalent, so the port drives
[byedpi](https://github.com/hufrea/byedpi) (`ciadpi`) — a userspace SOCKS5
proxy that implements the same desync tricks. The Windows-only
"fake packet + low TTL" preset is **not** available on macOS; the port
compensates with `--split`, `--disorder`, `--tlsrec`, `--oob`, `--mod-http`.

## Verified commands

Run from the repository root. "Exit" is the code observed in this worktree.

| Command | Exit | Result |
| --- | --- | --- |
| `uname -s` / `uname -m` | 0 | `Linux` / `x86_64` — this host is **not** macOS and **not** Windows. |
| `bash -n macos/scripts/*.sh macos/build.sh` | 0 | All 18 tracked shell files parse. Same loop per file: every `bash -n` returned 0. |
| `bash macos/tests/static-checks.sh` | 0 | `static-checks: 19 scripts, 0 failures` (the 18 above plus the checker itself). |
| `xmllint --noout macos/launchd/com.cagritaskn.goodbyedpi-turkey.plist.template` | 0 | Template is well-formed XML. `xmllint` exists here. |
| `python3 -c "import xml.etree.ElementTree as ET; ET.parse('macos/launchd/com.cagritaskn.goodbyedpi-turkey.plist.template')"` | 0 | Same check without `xmllint`; `python3` exists here. |
| `./macos/build.sh` | 1 | Refuses to run: `This build script targets macOS (Darwin) only.` It exits before creating `macos/bin/` or `macos/third_party/`, so the tree stays clean. |
| `command -v shellcheck` | 1 | **Not installed.** Never cite shellcheck as a passing check. |
| `command -v x86_64-w64-mingw32-gcc` | 1 | **Not installed** (same for `i686-w64-mingw32-gcc`). |
| `command -v plutil` / `command -v codesign` | 1 | **Not available** — macOS-only Apple tools. |
| `grep -rn 'mapfile\|readarray\|\${var,,}' macos/` | 0 | Only matches are comments; no script uses a Bash 4+ feature. |
| `git check-ignore -v macos/bin/ macos/third_party/byedpi/ macos/launchd/com.cagritaskn.goodbyedpi-turkey.plist` | 0 | All three ignored by `.gitignore` lines 5, 6 and 7. |

**Not runnable locally, do not fake it:**

- `./macos/build.sh` / `make -C macos build` — `build.sh` refuses off Darwin (exit 1 above), and even on Darwin it needs Xcode tooling. **`ciadpi` cannot be built on this host**, so `macos/bin/ciadpi` never exists; the `run_method_*` helpers in `_lib.sh` call `require_root` and `require_ciadpi` and abort, and the remaining scripts write real system proxy/DNS/launchd state. So *no* `macos/scripts/*.sh` script can be executed end to end here.
- `src/` build — targets Windows: `src/Makefile` defaults `CPREFIX = x86_64-w64-mingw32-` and links `-lWinDivert -lws2_32`, and WinDivert headers/libs are not vendored. Without the MinGW cross-compiler (`command -v` -> 1) and WinDivert, **`src/` is not buildable here**. `src/` is also C99/POSIX-ish but Windows-API-bound; do not try to compile it on Linux.
- Any runtime behaviour check: applying proxy/DNS, installing a LaunchDaemon, and the PAC/split-tunnel flow all require macOS + root. They can only be reviewed by reading code.

So the only checks that can pass on a Linux host are: **bash syntax
(`bash -n`), the static check script, and XML well-formedness of the plist
template.** That is the whole local gate.

## Conventions

- **Language split.** User-facing strings and documentation are **Turkish**: `README.md`, `REVERT.md`, `macos/README.md`, script `log`/`warn`/`err`/`die` messages, `windows/*.cmd` echoes, `windows/README-BEN OKU.txt`. Code comments, commit messages, and this file are **English**. Upstream `src/` comments are English — keep them that way.
- **Commits:** conventional-commits subject lines, imperative, lowercase type: `feat(macos): ...`, `fix(macos): ...`, `docs: ...`, `chore: ...`. History shows both styles, but new work uses the conventional form. One logical change per commit.
- **Shell scripts:** every tracked script starts with `#!/usr/bin/env bash`, then `set -euo pipefail`. Executable `macos/scripts/*.sh` runner/installer scripts source the shared library with `source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"` and then call a `run_method_*` helper (`run_method_oneshot`, `run_method_service_install`, ...). Exceptions: `_lib.sh` itself is sourced, never executed, and `macos/scripts/split_tunnel.sh` is self-contained by design. Put new shared logic in `_lib.sh`, not in a caller.
- **Bash 3.2 compatibility matters.** macOS ships `/bin/bash` 3.2 (this Linux host runs 5.3, so a Bash 4+ feature would pass `bash -n` here and break on macOS). No `mapfile`/`readarray`, no `${var,,}` / `${var^^}`, no associative arrays (`declare -A`), no `&>>`. Use `while IFS= read -r` loops and `tr` for case folding. The static checker caps complexity this way; keep it.
- **Style:** 4-space indent, LF, UTF-8, final newline (`.editorconfig`). Colour log prefixes go through the `log`/`warn`/`err`/`die` helpers in `_lib.sh`; do not invent new `printf` banners.
- **Errors are loud.** `set -euo pipefail` plus explicit `die "..."` for missing prerequisites. Never swallow a failure to make a script "work".

## Do not touch

- `src/` — upstream-owned; fork patches only, no reformatting, no "modernising".
- `windows/` — CRLF `.cmd` launchers; a stray LF or re-encoding breaks them.
- `macos/third_party/` — a gitignored `git clone` of byedpi. Vendored, never edited by hand, never committed.
- `macos/bin/` — build output (`ciadpi`), gitignored, regenerated by `macos/build.sh`. Never commit a binary.
- `REVERT.md` — user-facing uninstall document; content is deliberate and reviewed. Do not rewrite it.
- `.github/ISSUE_TEMPLATE/*` (`bug.yml`, `bug_report.md`, `feature.yml`, `feature_request.md`, `config.yml`) — repo process config, not project code.
- `macos/launchd/*.plist` (the **rendered** file) is **gitignored**; the tracked source of truth is `com.cagritaskn.goodbyedpi-turkey.plist.template`. Edit the template, never the rendered copy, and keep `<!-- ARGS_PLACEHOLDER -->` intact — `_lib.sh` substitutes `@LABEL@`, `@CIADPI@` and that marker when installing the daemon.

Also out of scope for a docs or script change: renaming script files (users
copy these names from the README), and changing the fixed ports/labels
(`127.0.0.1:1080`, `CIADPI_PORT`, `com.cagritaskn.goodbyedpi-turkey`).

## Verification gate

Never claim "done" without running the gate and pasting the exit code.

Multi-step work (new subsystem, security pass, multi-file change) is planned and
recorded under `docs/plans/` — start at `docs/plans/README.md` for the task-spec
contract, the three verification gates (local static / CI build / real hardware)
and the execution rules. Linux gate: `cd linux && make check && make test`.

If `macos/tests/static-checks.sh` exists (it does in this worktree), that is
the project gate — run it from the repo root: it runs `bash -n` on every
`*.sh` under `macos/` (skipping `third_party/` and `bin/`) and exits 0 only
when all parse, printing `static-checks: N scripts, 0 failures`.

If that script does not exist in your checkout, run `bash -n` over every
shell file yourself — `bash -n macos/build.sh macos/scripts/*.sh` — and
require exit 0; `bash -n` catches syntax errors but nothing else, and
`shellcheck` is not installed here.

Add the plist check whenever you touch `macos/launchd/`:
`xmllint --noout macos/launchd/com.cagritaskn.goodbyedpi-turkey.plist.template`
(exit 0). Nothing else is runnable on a non-Darwin host, so a change to
`build.sh`, `_lib.sh` runtime logic, or any installer is verified by syntax
plus code review only — say so explicitly in your report instead of implying
a functional test ran.
