# Troubleshooting

Start with `scripts/doctor.sh` — it never mutates the machine. Critical
missing repo files exit 1; everything else is a warning and exit 0.

## Isolation / wrong account

Symptoms: `~/.config` on the daily-driver account changed; unexpected
symlinks.

```bash
scripts/check-isolation.sh
```

See `docs/ISOLATION.md`. Stow only with `--target /home/devuser` (or as
devuser). Never run `install.sh` against the live user.

## Shell does not start / black bar

- `systemctl --user status modern-shell.service`
- Run `quickshell -p ~/.config/quickshell/modern` in kitty — QML errors
  go to that terminal
- `TypeError: … is not a function` on a singleton: the type is missing
  from `Services/qmldir` (or Commons/Widgets). See `docs/DECISIONS.md` #19
  and `AGENTS.md`

## No colors / ugly defaults

`tokens.json` is optional until the first successful matugen run.

```bash
scripts/theme-apply.sh --wallpaper /path/to/image
```

`scripts/doctor.sh` warns when `~/.config/modern/tokens.json` is absent.

## `secrets.json` missing

Expected until you create gitignored
`~/.config/modern/secrets.json`. Weather/AI keys do not belong in
`config.default.json`. Doctor warns; it is not fatal.

## Portal file picker / screenshot broken

Confirm `~/.config/xdg-desktop-portal/hyprland-portals.conf` is stowed
and `xdg-desktop-portal-hyprland` plus `xdg-desktop-portal-gtk` /
kde are installed. Restart: `systemctl --user restart xdg-desktop-portal`.

## KDE Connect phone does not see the PC

Ports 1714–1764 TCP/UDP. Staged rules:
`install/system/ufw/kdeconnect.rules`. Not applied by `install.sh`.

## Games stutter / Proton fails to start

See `docs/GAMING.md`: `vm.max_map_count`, file-descriptor limits,
`split_lock_mitigate`. Sysctls are gated. OptiScaler: never delete the
game `dxgi.dll` — use `scripts/optiscaler.sh remove` to restore
`.modern-optiscaler-backup/`.

## First-run wizard loops

Onboarding runs while `~/.config/modern/config.json` is missing.
`FirstRun.complete()` copies `config.default.json`. If that file was not
stowed, copy it by hand then restart the shell.

## Overview (`SUPER + TAB`) empty

Needs Hyprland toplevels over IPC. Confirm `Hypr.toplevels` in a running
session; the overlay binds `Services/Overview.open`.

## Layer lint / i18n

```bash
scripts/lint-layers.sh
```

Fails on Commons←Services imports, Modules spawning `Process`/`FileView`,
hardcoded `#hex` in QML, or keys present in only one of `en.json` /
`de.json`.
