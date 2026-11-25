# Problem reports

How "Report a problem" works: what it collects, how it redacts personal
data before anything leaves the computer, and where a report goes. For
end users who want to know what they send, and for developers who
change the collectors.

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
4. `send` uploads the ticked files and screenshots to the `reports`
   branch of the private repository `bugReport.repo`
   (`Gamesearch56/modern-reports`) and opens a private issue, using this
   computer's GitHub login (`gh auth token`). Nothing is committed to
   the public repository. A project token is never read. Exit
   20 (offline, rate limited, timeout or a GitHub 5xx) leaves a `queued`
   marker; `outbox` sends it when the network returns. 21 means this
   computer is not signed in to GitHub, so the report is not sent. 22
   is a refused login or a repository this login cannot see, 23 any
   other answer.
5. `export` writes `modernos-report-<id>.tar.xz` to the XDG Downloads
   folder (`~/Downloads` by default). A quick report that cannot be
   sent does this itself.

To read a report back: `scripts/report-fetch.sh <issue>`.

Every step's stderr and an unexpected exit land in the shell log under
the `BugReport` tag (`Services/BugReportProc.qml`).

## What is collected

| File | Contents |
|------|----------|
| `system.txt`, `failed-units.txt`, `coredumps.txt`, `doctor.txt` | Version, commit, kernel, failed units, recent crashes |
| `device.txt` | One-screen device summary, quoted as the issue's **Device** section: machine model and form factor, firmware and boot mode (Secure Boot), virtualization, CPU and threads, memory, each GPU with its driver, OpenGL renderer, graphics package versions, displays (make, model, mode, scale, VRR; no serial), root filesystem, audio server, install type. `modern device` prints it, redacted, for a hand-written issue |
| `hyprland.txt`, `hyprland-log.txt` | Monitors, workspaces, window class and geometry (no titles), layers, input device names, log warnings |
| `journal-*.txt`, `quickshell-log.txt` | User journal, system warnings, previous boot errors, shell log |
| `audio.txt` | `wpctl status`, sinks, cards, PipeWire quantum/rate, Bluetooth card profile and codec |
| `bluetooth.txt` | Adapter, per-device `bluetoothctl info` (paired/bonded/trusted), bluetoothd and WirePlumber logs |
| `network.txt` | NM state, radios, rfkill, regulatory domain, joined network's band/signal/rate (no name), NetworkManager and wpa_supplicant logs |
| `hardware.txt`, `games.txt`, `config.json` | PCI/USB, memory, disks, battery, GPU renderer and driver, kernel/Hyprland/Quickshell/Mesa/NVIDIA package versions; Proton tools; behaviour config |
| `session.txt` | Lock marker, whether shell/supervisor/hypridle/inhibitor run, logind session, inhibitors, `modern-session`/`modern-power`/`modern-shell` journal, greetd, login screen log and auth trace, desktop session log (headers, warnings, errors only), hypridle log |
| `boot.txt` | Kernel command line, boot timing and critical chain, boot entries, splash/boot-confirm/greetd units, the end of the previous boot (its shutdown) |
| `update.txt`, `update-log.txt`, `install-log.txt` | Update exit status and markers, system-update unit, release history, update logs, `install.sh` log and the ISO installer's late-phase log |
| `apps.txt` | System application logs (Texteditor, Imageviewer and Mediaplayer): launcher notes plus each window's own qs output (`scripts/lib/app-log.sh`, 1 MB, one previous file kept). A "System applications" report quotes it in the issue |

Every file name needs a `bugReport.files.<name>` label in `en.json` and
`de.json`; `tests/test-bug-report.sh` fails on one without.

Never collected (`_forbidden`): `secrets.json`, `.env`, keyrings, SSH
and GnuPG, browser profiles. Redacted in every text file: tokens,
`key=value` secrets, URL queries, mail addresses, IPs, MAC addresses
(last byte kept), Wi-Fi names (quoted, `SSID:` fields, `ssid=`), serial
numbers (`"serial"` fields, `Serial Number:`, `ID_SERIAL`), the
hostname, the username and the home path. JSON loses every value under
an account, location, serial, UUID or secret key.

Reports are private issues labelled `bug`, `Work Required` and one
`area:*` per chosen category. `Work Required` stays until the report
is fixed, then it is removed. A public issue that leaves logs and
screenshots out: `scripts/report-to-issue.sh` (`docs/GIT.md`, "From a
report to a branch").

Tests: `tests/test-bug-report.sh` (stubbed tools, fake GitHub server in
`tests/lib/fake-github.py`), `tests/test-report-device.py`,
`tests/test-report-to-issue.sh`.
