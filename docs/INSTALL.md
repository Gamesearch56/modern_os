# Install

Three paths: packages + stow onto an Arch user (`install.sh`), a live-ISO
bootstrap that **prints** partitioning (`scripts/bootstrap.sh`), or an
**ISO** (Calamares + late `install.sh --profile m0 --yes`).
System-wide files under `install/system/` are **never** applied by
`install.sh` — `docs/ISOLATION.md`. `provision-iso.sh` is Calamares-late
only and refuses when `MODERN_PROTECT_HOME` is set. Git / release tags:
`docs/GIT.md`. Existing account: `docs/CUTOVER.md`.

## Prerequisites

- Arch Linux (or an Arch live ISO for bootstrap)
- This repo cloned where the **target** user can read it (a `700` home
  means clone a copy as that user)
- Optional: set `MODERN_PROTECT_HOME` so `install.sh` refuses that path
  unless you pass `--allow-live-home`

## Extra-user testing (`devuser`)

```bash
scripts/check-isolation.sh
sudo install/system/create-devuser.sh

# as devuser (sudo -iu devuser)
git clone <repo-url> ~/modern_dotfile
cd ~/modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Start the session on **another TTY** (`Ctrl+Alt+F3`) with
`start-hyprland`. Do not run the `Hyprland` binary — Hyprland ≥ 0.53
needs the wrapper or the bar never appears. Return with `Ctrl+Alt+F1`
or `F2`.

## `install.sh` (existing user)

```bash
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0 --target /home/devuser
```

Profiles: `m0` (bar/launcher/session), `dev` (+ Cursor/toolchain),
`gaming` (+ Proton/MangoHud), `full`. Manifests:
`install/manifests/README.md`.

`install.sh` only installs packages and stows listed packages into
`--target` (default `$HOME`): hypr, shell, theme, kitty, dolphin, gtk,
qt, bash, git, modern, systemd, xdg, fontconfig, fastfetch, mpv, imv. It does **not** stow
`greeter`. It never copies `install/system/` and never enables greetd.
Stow conflict backups go under `$TARGET/.local/state/modern/stow-backups`.

Calamares late on a new machine is `./install/install.sh --profile m0 --yes`
as the new user, then `MODERN_ISO_PROVISION=1 install/system/provision-iso.sh`.
That gated script is the only allowed applier of greetd / NetworkManager
enable. Do not run it on a machine you live on.

Clone + install is the **designed** desktop (`config.default.json`:
English UI, `kbLayout` `us`).

`--allow-live-home` disables the `MODERN_PROTECT_HOME` guard. Use it
only when that account *is* the one you want to own, following
`docs/CUTOVER.md`. Not for `devuser` testing.

Installer log: `install/install.log` (gitignored) and
`journalctl -t modern-install`.

## Create `devuser` (gated)

```bash
sudo install/system/create-devuser.sh
```

This does **not** change autologin. Rollback: `sudo userdel -r devuser`.

## Bare metal (`bootstrap.sh`)

From the live ISO, copy `install/hardware.conf.example` to
`install/hardware.conf` and set `DISK=`. **Default is dry-run** (prints
partition → btrfs `@ @home @pkg @log @snapshots @swap` → pacstrap →
arch-chroot → chain `install.sh`). Disks are not wiped unless you pass
`--yes --disk /dev/X` together, and this process still does not call
`mkfs` — you run the printed steps as root after review.

```bash
./scripts/bootstrap.sh --dry-run
./scripts/bootstrap.sh --vm          # QEMU recipe only
```

## ISO (Calamares)

Build on this PC or CI. Output is gitignored `iso/out/` (throwaway
`HOME` for matugen). `--mkarchiso` needs **root**, `archiso`, and about
**8G free** on that directory — not `/tmp`. It does **not** run
`provision-iso.sh` or touch live `/etc` except a throwaway AUR builder
user that is deleted when the script exits.

```bash
sudo pacman -S --needed archiso qemu-desktop edk2-ovmf qt6-tools
sudo ./scripts/iso-build.sh --mkarchiso
./scripts/iso-qemu.sh          # UEFI live image + 64G qcow2 (Calamares needs ≥ 16 GiB)
./scripts/iso-qemu.sh --headless   # no GTK; CI smoke uses this
./scripts/iso-qemu.sh --reset-disk # wipe a previous VM install, still boot the ISO
./scripts/test-iso-qemu-install.sh # unattended QEMU until late install finishes
```

The **live** ISO is this clone (kiosk, branding, Calamares). After
install, Calamares late clones the baked-in **release tag** (`--tag` or
the latest `vX.Y.Z`). First boot of the **installed** system is greetd
+ password.

The **live** image autologins `liveuser` into `cage`. Cage's client is
Xwayland; Calamares runs as root on X11 (`sudo` + `xhost`) so partitioning
works. Root cannot be a Wayland client of liveuser's compositor, and a
root compositor never painted in QEMU. `locale-gen` runs beside greetd,
not before it. `iso-qemu.sh` boots OVMF (install `edk2-ovmf`) and writes
guest serial to `iso/out/vm-serial.log`. `--headless` drops GTK/GL so CI
can wait for `modern-ci: calamares` on that serial. BIOS QEMU makes
Calamares try GRUB, which this image does not ship.
`--unattended` sets QEMU fw_cfg `opt/org.modernos/unattended`; the live
wrapper writes `/etc/calamares/unattended` so Calamares auto-advances
and fills user `modern` / password `modern`. `scripts/test-iso-qemu-install.sh`
runs that until serial shows `late install finished` (about an hour;
not part of `ci-check.sh` or the ISO Action).

The VM always attaches `iso/out/vm-disk.qcow2`. After a previous
Calamares run, OVMF NVRAM (`iso/out/ovmf-vars.fd`) can boot that disk
instead of the ISO. UEFI ignores `-boot order=d`, so an unfinished
install shows `ERROR: '' device did not show up` in initramfs — not an
empty live TTY. Each `iso-qemu.sh` resets firmware NVRAM and gives the
CD `bootindex=1`. Use `--reset-disk` to recreate the qcow2. Use
`--keep-nvram` only when you want to reboot into a finished install.

That `bootindex=1` is also why **Restart now** on the Finish page lands
you back in Calamares: rebooting the guest re-runs the firmware, which
still finds the CD first. `--keep-nvram` does not help, because the boot
order comes from the CD's bootindex and not from NVRAM. To boot what you
just installed, quit QEMU and start it again with no CD at all:

```bash
./scripts/iso-qemu.sh --no-iso
```

`--no-iso` implies `--keep-nvram` so the `Linux Boot Manager` entry that
the bootloader job wrote survives, and it does not need an ISO in
`iso/out/` at all.

Installer checks are two gates. Every PR runs `scripts/ci-check.sh`
(QSS/config/schema, AUR patch fixtures, `calamares-late.sh` clone against
a local git tag). The ISO Action (release only) boots the built image
until Calamares starts; a red job does not attach the ISO. It does not
click through pages or run late clone of GitHub.

`stylesheet.qss` paints scroll viewports, Summary `#summaryContent` /
`#summaryItemWrap` / `#summaryPartition`, `#summaryItemBody` cards, and
`#partitionLabel` (legend names still need the AUR patch: Calamares
paints Boot/root with `Qt::black`).
Combo boxes have no QSS radius. Native combo lists stay `Qt::Popup`
(an in-window overlay SIGSEGV'd Calamares on start). Cancel is hidden
during Install (`disable-cancel-during-exec` plus `quitVisible`). Late
jobs set `verbose: false` so a failure dialog shows stdout (Calamares
`verbose: true` streams output to the session log and leaves the dialog
empty). Failures also tee to `/var/log/modern-calamares-late.log`.
Late `ensure_dns` replaces a dangling systemd `/etc/resolv.conf`
symlink, strips loopback nameservers, and rewrites `nsswitch.conf`
`hosts:` to `files dns`. Arch's default `resolve [!UNAVAIL=return]`
lets nss-resolve fail before glibc ever reads resolv.conf, so yay's
`git clone` died with `Could not resolve host: aur.archlinux.org`
even after writing `1.1.1.1`. Late desktop uses `runuser` (not
`sudo -iu`) and `Defaults !use_pty` so install.sh can run in the
Calamares chroot without `/dev/pts`. It does not chmod `/etc` to 0750
(that blocked the target user from `/etc/gitconfig` during yay
bootstrap). `iso-build.sh` bundles the pin at `/usr/share/modern/dotfile`; late
clone copies that tree (the GitHub remote is private, so a network
clone would fail). The ISO pin must be a real `vX.Y.Z` tag (`--tag` or
the latest tag in the clone).

**Only `iso/` is built from your working tree.** The bundle is
`git clone --branch <pin>`, so `install/`, `stow/` and `scripts/` reach
the installed system as the *tag's* copy. Editing `provision-iso.sh` or a
`stow/` dotfile and rebuilding puts the change on the live ISO and leaves
it out of the machine you then boot, which reads as the fix silently not
working. `iso-build.sh` now refuses to build when those three directories
differ from the pin, listing the files; commit and tag, or pass
`--stale-bundle` to deliberately ship the pin's copy. An explicit `--tag`
also skips the check, since naming a pin is a deliberate choice — that is
how the ISO workflow rebuilds an older release from `main`'s scripts.

Because the bundle is cloned from the clone rather than the remote, the
checkout needs a real `.git` **with tags** — hence `fetch-depth: 0` in
`iso.yml`, since a shallow checkout of `main` carries none.
`iso-build.sh` checks for the repository and the tag up front rather than
letting git report "repository does not exist" against the destination
path, and prints git's own message, which distinguishes a missing `.git`
from a refusal on ownership.

The ISO job is **not** a `container:` job, and that is load-bearing.
GitHub guarantees only 14 GB free on `ubuntu-latest` and mkarchiso needs
considerably more, so a host step deletes the preinstalled toolchains
(`/usr/share/dotnet`, `/opt/hostedtoolcache`, …) first — paths a
containerised step cannot see. The build itself then runs through
`docker run --privileged` via `scripts/ci-iso-container.sh`, which also
re-marks the workspace safe for git (`actions/checkout` writes
`safe.directory` to a temporary global config that is gone by then) and
chowns the output back so `upload-artifact` can read it.

Location Region/Zone combos stay on the page; the **Change…** locale
dialogs are hidden. They open a modal X11 window that cage maps as an
unclosable grey stripe. Keyboard layout changes call `setxkbmap` on
Xwayland (`xorg-setxkbmap`; `useLocale1: false` so systemd-localed is
not used instead).

The Keyboard step always opens on English. `guessLayout: false` turns off
Calamares' locale→layout guess, which otherwise flipped the page to German
the moment German was picked on Welcome or Location. The initial selection
then comes from `setxkbmap -print` (a fresh Xwayland reports `pc+us`), and
if that ever returned nothing Calamares falls back to the first row of the
model — sorted by description, so "English (US)" before "German". Both
paths land on `us`; picking German by hand still works and still reaches
the installed system.

The Keyboard step's own job only writes `/etc/vconsole.conf` (the TTY) and
`/etc/X11/xorg.conf.d/00-keyboard.conf` (Xwayland clients). Hyprland reads
`kb_layout` from `config.json` (`modules/input.lua`) and greetd runs a
*second* Hyprland that reads neither, so picking German used to leave both
the login prompt and the desktop on `us`. `provision-iso.sh` closes that:
it parses `XkbLayout` / `XkbVariant` out of the X11 snippet Calamares just
wrote, sets `input.kbLayout` / `input.kbVariant` in the user's
`config.json` with `jq` (leaving the rest of the file untouched), and
appends a matching `hl.config({ input = ... })` to
`/etc/greetd/hyprland.lua`. The value is passed through verbatim, so a
comma-joined non-ASCII pair like `us,ru` still works — Hyprland accepts
that form too. A missing snippet is a warning, not a failure. Changing the
layout later in Settings → Keyboard updates the desktop but not the TTY,
X11 snippet, or greetd.

The **Network** / **Netzwerk** page sits after Keyboard. Next stays off
until a default IPv4 or IPv6 route exists — Ethernet is enough;
otherwise Wi-Fi turns on (no toggle) and the page matches Settings →
Network (ethernet row, nearby list, password card). Ethernet already
up shows a centered “You're connected with Ethernet” page instead.
Live setup enables NetworkManager and stops `iwd` so they do not fight
over the radio. Unattended QEMU already has virtio-net, so auto-next is
not blocked. `stylesheet.qss` paints `#networkPage`, `#networkOkPage`,
and `#wifiList` from the same tokens as the rest of Calamares. The C++
module is copied into AUR Calamares at build (`iso/releng/calamares-modernnet`).
Late `pacman` still needs that route.

`provision-iso.sh` enables `NetworkManager`, `greetd`, `bluetooth` and
`systemd-timesyncd` **one unit per call** — `systemctl enable a b c`
aborts the whole list on the first unit that does not exist, so one
missing package used to take the install down. NetworkManager and greetd
are required; the other two log and continue. `bluez` is its own manifest
entry: `bluez-utils` is only `bluetoothctl` and does not depend on it, so
without `bluez` there is no `bluetoothd`, no `bluetooth.service`, and no
`org.bluez` for `Services/Bluetooth` to bind. Late desktop also installs
the packages behind those units directly, so pins predating that manifest
line still provision. `ufw`, `openssh`, `samba` and `wsdd` are installed
but deliberately not enabled — see `docs/SECURITY.md`.

Late clone restores the exec bit across the bundled repo from its own git
index. `mkarchiso` copies the profile airootfs with
`cp -af --no-preserve=ownership,mode`, so `/usr/share/modern/dotfile`
lands entirely 0644 — `profiledef.sh`'s `file_permissions` only covers
`/usr/lib/modern`. Without the restore, `provision-iso.sh` fails its
`-x` guard, and install.sh's *direct* calls to `scripts/theme-apply.sh`,
`mime-defaults.sh` and `nautilus-prefs.sh` die on Permission denied
behind a `log_warn`, so the install "succeeds" with no `tokens.json`.

After **Install**, the exec page copies the squashfs (`unpackfs`). That
lays the *live* root down as the installed root, so `calamares-late.sh
strip` (`shellprocess@striplive`) runs next and deletes the live-only
files it carried over. This is not tidying — the target does not boot
without it. archiso ships `/etc/mkinitcpio.conf.d/archiso.conf`, and
mkinitcpio reads `conf.d` *after* `mkinitcpio.conf`, so its
`HOOKS=(… archiso …)` beats anything `initcpiocfg` writes. The `archiso`
hook replaces the root mount handler with one that mounts
`$archisodevice`, which only a `archisolabel=` cmdline sets, so a disk
boot lands in the initramfs rescue shell with `ERROR: '' device did not
show up after 30 seconds`. Same file list also drops
`etc-pacman.d-gnupg.mount` (a tmpfs over the keyring) and
`pacman-init.service` (re-creates it every boot), the `/dev/null` mask on
`getty@tty1` (no console left when greetd fails), the
`greetd.service.wants` links to `modern-live-setup.service` (which
creates the passwordless `liveuser` that `99-liveuser` and the polkit
rule hand root to), the live `xdg-open` shim, and the `iwd` / `sshd`
enablement archiso wants but an installed desktop did not ask for.

Order matters in both directions: `striplive` reads the account the
`users` job creates, and both it and `initcpiocfg` must precede
`bootloader`, because that job calls `kernel-install` — with
`etc/kernel/install.conf` pinning `layout=bls` and
`initrd_generator=mkinitcpio` — and that is what actually builds the
initramfs. There is no `initcpio` job after `initcpiocfg` for the same
reason: a preset-driven `mkinitcpio -P` would only add an unused second
image to the ESP. `scripts/test-iso-live-kiosk.sh` asserts the ordering
and `scripts/test-calamares-late.sh` asserts that every live-only file
tracked under `iso/airootfs` is on the strip list.

The Calamares packages job does not `pacman -S` anything (no sync db on the
squashfs; a `-Sy` plus kernel download froze the bar in QEMU). Late
desktop inits a target keyring (`pacman-key --init` / `--populate`,
same as `pacstrap -K` — unpackfs does not copy the live overlay's
`pacman-init` gnupg home), then `pacman --disable-sandbox -Sy
archlinux-keyring` (pacman 7's landlock sandbox cannot download
inside the Calamares chroot), enables
`[multilib]` (needed for `lib32-gamemode`), sets `IgnorePkg` for
`jack2` / `pulseaudio` (`--noconfirm` answers **No** to “Remove jack2?”),
installs the PipeWire stack, overlays pin `install_native` so old tags
cannot one-shot ffmpeg+pipewire-jack, rewrites pin `matugen` /
`bibata-cursor-theme` (including a trailing comment) to the `-bin`
packages already on the squashfs, `NoExtract`s `resolv.conf` so a
`systemd` upgrade cannot point DNS at an empty `/run`, then
`install.sh --profile m0 --yes` (`--needed` skips native packages already
unpacked; `install_aur` skips names `pacman -Q` already has, and
`MODERN_SKIP_AUR=1` never calls `yay` — `yay -S --needed` still
queries `aur.archlinux.org` and dies when chroot DNS is gone), then `provision-iso.sh`.
A failed `install.sh` reprints its last 40 lines (and `install/install.log`)
into the Calamares dialog — `log_error` otherwise only hits stderr. The ISO
also ships m0 AUR packages (`matugen-bin`, `bibata-cursor-theme-bin`, `phylax-git`)
so late install does not have to build them. Source AUR `matugen` needs
rustup and is stuck on 3.0.0; `matugen-bin` is 4.2.0 and provides `matugen`.
Source `bibata-cursor-theme` needs AUR `python-clickgen`; the `-bin`
package does not.
The bar only moves when a job reports; unpack in QEMU can sit still for
many minutes. If the bundle is missing, late git has a 180s timeout
instead of hanging for two hours.

The **Finish** page is a congratulation, not a form: a 112px check badge
above `#finishedMainText` (20px, so the `<h1>All done.</h1>` scales with
it) and one filled **Restart now** pill. Calamares' own control there is a
`QCheckBox` that only records intent for the footer **Done**, and this page
has no footer — `calamares-limit-languages.py` hides Back, Next and Done
once `isAtVeryEnd`. The checkbox stays hidden and the pill sets
`restartNowWanted` then quits, which is what fires `restartNowCommand` from
`aboutToQuit`. That needs `finished.conf`: with no config the mode is
`never`, and `Config` then forces `restartNowWanted` false, so the control
renders and does nothing. The button reuses the checkbox's own translated
label, so German needs no new string. Hiding the footer cannot strand
anyone — a failed install quits from the error dialog and never reaches
this page.
If you land on a TTY, this image never started greetd:

```bash
/usr/lib/modern/live-session.sh
```

Welcome **Support** / **Known issues** open GitHub in Firefox on the
same Xwayland display. Cage does not decorate X11 windows, so the live
session runs **openbox** (Calamares stays fullscreen without a titlebar).
Close Firefox with its window-close button or Alt+F4 to return to the
installer. There is no Donate button. The VM needs virtio 3D.

Calamares is still Qt Widgets for every *page* (Welcome, Partitions,
Users, …). `stylesheet.qss` can restyle those: colors, field radii,
buttons, the exec bar. Combo lists are `Qt::Popup` windows, so the AUR
build also applies that QSS on `qApp`. Cage still maps those lists at
`(0,0)`. It cannot round the default left-hand step list —
that is a C++ delegate. `sidebar: qml` + `calamares-sidebar.qml` is the
escape hatch used here (nav pills and a padded About, like Settings).
The logo is `iso/airootfs/etc/calamares/branding/modern/logo.png`.

Settings → Update later tracks the latest GitHub **release tag**, not
`dev` or the tip of `main`.

## After stow (on the **target** user)

`install.sh` phase 5 applies `~/.config/modern/wallpapers/default.jpg`
(tokens, GTK/Qt/kitty). `wallpaper-sync.sh` writes lock assets to
`~/.local/state/modern/session` until gated `/var/lib/modern/session`
exists. Nautilus sidebar starts with Downloads, Pictures, and Videos
(`nautilus-prefs.sh`, XDG dirs for the target user). First-hour UI is
**English**. Power-menu lock is an overlay
preview, not a real lock. Titlebars need a one-time `hyprpm` + pkexec
in a graphical session (`docs/TROUBLESHOOTING.md`).

To use a different image later:

1. `scripts/theme-apply.sh --wallpaper PATH` (writes `tokens.json` and
   syncs lock/login assets)
2. `start-hyprland` on a TTY (not the `Hyprland` binary). Autostart
   starts `qs -c modern` as a child of Hyprland. Skip
   `systemctl --user enable` on a text TTY (`docs/BOOT.md`).
3. `scripts/doctor.sh`
4. Optional gated files that **exist**: Plymouth README, sysctl, ufw
   KDE Connect, tmpfiles, ESP hook, snapper, `create-devuser.sh` —
   each file's header comment has the copy command. Greetd drop-ins live
   under `install/system/greetd/` but stay gated — only `provision-iso.sh`
   in a Calamares chroot applies them.

Hand-edit reference is `config.default.json` (no `config.schema.json`).

Firewall reminder if a later mobile/LAN API is involved: listen on
`0.0.0.0` and `sudo ufw allow <port>/tcp` — not needed for this desktop
shell itself.

## Verify

```bash
scripts/ci-check.sh
scripts/check-isolation.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
scripts/doctor.sh
```

`test-iso-qemu-smoke.sh` is **not** part of `ci-check.sh`. It needs a
built ISO and QEMU; the ISO workflow runs it after mkarchiso.

If `MODERN_PROTECT_HOME` is your `$HOME`, do **not** run
`./install/install.sh --dry-run --profile m0` without `--target` — the
live-home guard will fail, which is the point.
