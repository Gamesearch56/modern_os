# Problem reports

Super+# (`xkb.lua` `bugReport`, bound to keycode 51: `#` on a German
layout, `\` on US) runs `modern report`. When the shell answers IPC it opens the
`modern.bugreport` window (`Services/BugReport.qml`, `Modules/BugReport/`);
when it does not, `scripts/bug-report.sh quick` captures, collects and
sends with no questions, so a dead shell can still be reported.

## Flow

1. `new` creates `$XDG_STATE_HOME/modern/reports/<id>/`.
2. `capture` writes one JPEG per monitor (`grim`).
3. `collect` runs `scripts/lib/bug-report-collect.sh`, then
   `scripts/lib/report-redact.py`. Redaction happens before the review
   list, so what the user can open is what gets sent.
4. `send` uploads the ticked files and screenshots to `bugReport.repo`
   and opens a private issue. Exit 20 (offline, rate limited, timeout or
   a GitHub 5xx) leaves a `queued` marker; `outbox` sends it when the
   network returns. 21 is no token, 22 a refused token, 23 any other
   answer.
5. `export` writes `~/Downloads/modernos-report-<id>.tar.xz` when there
   is no token.

The token is `secrets.json` → `bugReport.githubToken`, scoped to the
reports repository. The `gh` login of the computer is used only with
`MODERN_REPORT_GH=1`: it usually has far more rights than filing an
issue needs. To read a report: `scripts/report-fetch.sh <issue>`.

Every step's stderr and an unexpected exit land in the shell log under
the `BugReport` tag (`Services/BugReportProc.qml`).

## What is collected

| File | Contents |
|------|----------|
| `system.txt`, `failed-units.txt`, `coredumps.txt`, `doctor.txt` | Version, commit, kernel, failed units, recent crashes |
| `hyprland.txt`, `hyprland-log.txt` | Monitors, workspaces, window class and geometry (no titles), layers, input device names, log warnings |
| `journal-*.txt`, `quickshell-log.txt` | User journal, system warnings, previous boot errors, shell log |
| `audio.txt` | `wpctl status`, sinks, cards, PipeWire quantum/rate, Bluetooth card profile and codec |
| `bluetooth.txt` | Adapter, per-device `bluetoothctl info` (paired/bonded/trusted), bluetoothd and WirePlumber logs |
| `network.txt` | NM state, radios, rfkill, regulatory domain, joined network's band/signal/rate (no name), NetworkManager and wpa_supplicant logs |
| `hardware.txt`, `games.txt`, `config.json` | PCI/USB, memory, disks, battery, GPU renderer and driver, kernel/Hyprland/Quickshell/Mesa/NVIDIA package versions; Proton tools; behaviour config |
| `session.txt` | Lock marker, whether shell/supervisor/hypridle/inhibitor run, logind session, inhibitors, `modern-session`/`modern-power`/`modern-shell` journal, greetd, login screen log and auth trace, desktop session log (headers, warnings, errors only), hypridle log |
| `boot.txt` | Kernel command line, boot timing and critical chain, boot entries, splash/boot-confirm/greetd units, the end of the previous boot (its shutdown) |
| `update.txt`, `update-log.txt`, `install-log.txt` | Update exit status and markers, system-update unit, release history, update logs, `install.sh` log and the ISO installer's late-phase log |
| `apps.txt` | Texteditor, Imageviewer and Mediaplayer logs: launcher notes plus each window's own qs output (`scripts/lib/app-log.sh`, 1 MB, one previous file kept). An "Apps" report quotes it in the issue |

Every file name needs a `bugReport.files.<name>` label in `en.json` and
`de.json`; `tests/test-bug-report.sh` fails on one without.

Never collected (`_forbidden`): `secrets.json`, `.env`, keyrings, SSH
and GnuPG, browser profiles. Redacted in every text file: tokens,
`key=value` secrets, URL queries, mail addresses, IPs, MAC addresses
(last byte kept), Wi-Fi names (quoted, `SSID:` fields, `ssid=`), the
hostname, the username and the home path. JSON loses every value under
an account, location or secret key.

Tests: `tests/test-bug-report.sh` (stubbed tools, fake GitHub).
