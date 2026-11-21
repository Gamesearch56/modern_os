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

## Extra-user testing (optional)

```bash
scripts/check-isolation.sh
sudo install/system/create-devuser.sh   # default username: devuser

# as that user
git clone <repo-url> ~/modern_dotfile
cd ~/modern_dotfile
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0
```

Start the session on **another TTY** (`Ctrl+Alt+F3`) with
`start-hyprland`. Do not run the `Hyprland` binary — Hyprland ≥ 0.53
needs the wrapper or the bar never appears. Return with `Ctrl+Alt+F1`
or `F2`. Existing-account install: `docs/CUTOVER.md`.

## `install.sh` (existing user)

```bash
./install/install.sh --profile m0 --dry-run
./install/install.sh --profile m0 --target /home/otheruser
```

Profiles: `m0` (bar/launcher/session), `dev` (+ Cursor/toolchain),
`gaming` (+ Proton/MangoHud), `full`. Manifests:
`install/manifests/README.md`.

`install.sh` installs packages, stows listed packages into
`--target` (default `$HOME`): hypr, shell, theme, kitty, gtk,
qt, bash, git, modern, systemd, xdg, fontconfig, fastfetch, pipewire,
plus each `stow` name in `install/manifests/default-apps.json`.
It copies the greeter via `install/lib/greetd.sh` and enables greetd on
a real user home (`--dry-run` and `--target /tmp` skip that). Stow
conflict backups go under `$TARGET/.local/state/modern/stow-backups`.

Calamares late on a new machine is `./install/install.sh --profile m0 --yes`
as the new user, then `MODERN_ISO_PROVISION=1 install/system/provision-iso.sh`
(NVIDIA initramfs, keyboard/locale seed). Do not run `provision-iso.sh`
on a machine you live on unless you want those extras.

Clone + install is the **designed** desktop (`config.default.json`:
English UI, `kbLayout` `us`).

`--allow-live-home` disables the `MODERN_PROTECT_HOME` guard. Use it
only when that account *is* the one you want to own, following
`docs/CUTOVER.md`. Not for extra-user testing.

Installer log: `install/install.log` (gitignored) and
`journalctl -t modern-install`.

## Create an extra test user (gated)

```bash
sudo install/system/create-devuser.sh          # default: devuser
sudo install/system/create-devuser.sh tester   # any unused name
```

This does **not** change autologin. Rollback: `sudo userdel -r <username>`.

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
./scripts/iso-qemu.sh --headless   # no GTK; serial still goes to iso/out/vm-serial.log
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
guest serial to `iso/out/vm-serial.log`. `--headless` drops GTK/GL so
you can wait on that serial without a display. BIOS/CSM firmware takes
Calamares' GRUB path: an msdos table, then `shellprocess@biosboot` puts
`vmlinuz-linux-zen` and both initramfs images in `/boot` before
`grub-mkconfig` runs. `iso-qemu.sh` only boots UEFI, so that path is
covered by `test-calamares-late.sh`, not a VM run.
`--unattended` sets QEMU fw_cfg `opt/org.modernos/unattended`; the live
wrapper writes `/etc/calamares/unattended` so Calamares auto-advances
and fills user `modern` / password `modern`. `scripts/test-iso-qemu-install.sh`
runs that until serial shows `late install finished` (about an hour;
not part of `ci-check.sh`).

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

QEMU has no 802.11 adapter, and the virtio NIC always looks like
Ethernet, so the Network step never shows its Wi-Fi list in a normal
VM. `--wifi-sim` drops that NIC and sets fw_cfg
`opt/org.modernos/wifi-sim`; `live-setup.sh` then runs
`live-wifi-sim.sh`, which loads `mac80211_hwsim` and brings up WPA2
access points (`ModernOS-Test-1`, passphrase `modernwifi`) for the
installer to scan. The guest has no uplink — use this to try the Wi-Fi
page, not to run a full install.

```bash
./scripts/iso-qemu.sh --wifi-sim
```

`--no-iso` implies `--keep-nvram` so the `Linux Boot Manager` entry that
the bootloader job wrote survives, and it does not need an ISO in
`iso/out/` at all.

Installer checks are two gates. Every PR runs `scripts/ci-check.sh`
(QSS/config/schema, AUR patch fixtures, `calamares-late.sh` clone against
a local git tag). The ISO itself is built locally, never by CI
(`sudo ./scripts/iso-build.sh --mkarchiso`); `scripts/test-iso-qemu-install.sh`
then clicks through an unattended install.

`stylesheet.qss` paints scroll viewports, Summary `#summaryContent` /
`#summaryItemWrap` / `#summaryPartition`, `#summaryItemBody` cards, and
`#partitionLabel` (legend names still need the AUR patch: Calamares
paints Boot/root with `Qt::black`).
Combo boxes have no QSS radius. Combo lists are drawn in-window as
`#modernComboOverlay` (see below), styled from the same tokens with
`padding: 0` so the AUR patch can size them. Cancel is hidden
during Install (`disable-cancel-during-exec` plus `quitVisible`). Late
jobs set `verbose: false` so a failure dialog shows stdout (Calamares
`verbose: true` streams output to the session log and leaves the dialog
empty). Failures also tee to `/var/log/modern-calamares-late.log`.
Late `ensure_dns` replaces a dangling systemd `/etc/resolv.conf`
symlink, strips loopback nameservers, and rewrites `nsswitch.conf`
`hosts:` to `files dns` for the chroot only. Arch's default
`resolve [!UNAVAIL=return]` lets nss-resolve fail before glibc ever
reads resolv.conf, so yay's `git clone` died with `Could not resolve
host: aur.archlinux.org` even after writing `1.1.1.1`. After provision, `restore_boot_dns` points `resolv.conf` at the
systemd-resolved stub again, and `dns.conf` tells NetworkManager to
send the Wi-Fi nameservers there. `iwd` is masked so its D-Bus service
cannot take the radio back. Left as a regular file, resolv.conf keeps
the cable's nameservers, and a later Wi-Fi connection looks up with a
DNS server that is no longer reachable. Late desktop uses `runuser` (not
`sudo -iu`) and `Defaults !use_pty` so install.sh can run in the
Calamares chroot without `/dev/pts`. It does not chmod `/etc` to 0750
(that blocked the target user from `/etc/gitconfig` during yay
bootstrap). `iso-build.sh` bundles the pin at `/usr/share/modern/dotfile`; late
clone copies that tree so Calamares does not depend on a GitHub fetch.
The ISO pin must be a real `vX.Y.Z` tag (`--tag` or the latest tag in
the clone).

**Only `iso/` is built from your working tree.** The bundle is
`git clone --branch <pin>`, so `install/`, `stow/` and `scripts/` reach
the installed system as the *tag's* copy. Editing `provision-iso.sh` or a
`stow/` dotfile and rebuilding puts the change on the live ISO and leaves
it out of the machine you then boot, which reads as the fix silently not
working. `iso-build.sh` now refuses to build when those three directories
differ from the pin, listing the files; commit and tag, or pass
`--stale-bundle` to deliberately ship the pin's copy. An explicit `--tag`
also skips the check, since naming a pin is a deliberate choice — that is
how you rebuild an older release with newer ISO scripts.

Because the bundle is cloned from the clone rather than the remote, the
build needs a real `.git` **with tags**; a shallow clone carries none.
`iso-build.sh` checks for the repository and the tag up front rather than
letting git report "repository does not exist" against the destination
path, and prints git's own message, which distinguishes a missing `.git`
from a refusal on ownership.

Location Region/Zone combos stay on the page; the **Change…** locale
dialogs are hidden. They open a modal X11 window that cage maps as an
unclosable grey stripe. Keyboard layout changes call `setxkbmap` on
Xwayland (`xorg-setxkbmap`; `useLocale1: false` so systemd-localed is
not used instead). Upstream starts that apply from the *variant* signal;
`live-xkb-filter.py` drops every variant, so picking German never ran
`setxkbmap` and the Users password was typed on `us`. The AUR patch
calls `Config::somethingChanged()` on a layout change too. A first pick
of German still left the test field on `us`: cage's Xwayland ignores
`setxkbmap -layout de` until a call also passes `-option` (India does,
because it is in `non-ascii-layouts`). The same patch now always sends
`-option` and runs `setxkbmap` twice.

The Keyboard step opens on the Welcome language's layout. English stays
`us`, German is `de`, from `installer-locales.json`. `guessLayout: false`
stays off: Calamares' own guess flipped this page when the Location step
settled on a timezone, including while Welcome was still English.
Startup detection only sees the live ISO locale (`setxkbmap -print` is
`pc+us`), so the same detection runs again when the Keyboard page opens.
A layout picked on that page is kept. Do not treat the combo's first row
as the default — Calamares sorts by description, so Arabic would lead the
shared catalog.

The Keyboard combo lists the common layouts in
`iso/releng/installer-locales.json` `layouts` (same ids as Settings →
Keyboard / `keyboard-layouts.json`). Welcome languages stay English and
German only.

The Keyboard step's own job only writes `/etc/vconsole.conf` (the TTY) and
`/etc/X11/xorg.conf.d/00-keyboard.conf` (Xwayland clients). Hyprland reads
`kb_layout` from `config.json` (`modules/input.lua`). The greetd kiosk is a
second Hyprland and used to ignore that file, so picking German left the
login prompt on `us`. `provision-iso.sh` parses `XkbLayout` / `XkbVariant`
out of the X11 snippet Calamares just wrote, sets `input.kbLayout` /
`input.kbVariant` in the user's `config.json` with `jq` (leaving the rest
of the file untouched), and writes the same pair to
`/var/lib/modern/session/keyboard.json`. The kiosk `hyprland.lua` applies
that snapshot at start. The value is passed through verbatim, so a
comma-joined non-ASCII pair like `us,ru` still works — Hyprland accepts
that form too. A missing snippet is a warning, not a failure. Changing the
layout later in Settings → Keyboard updates the desktop live and rewrites
`keyboard.json` so the next login matches. TTY and the X11 snippet stay
as Calamares left them.

The Locale step follows the same Welcome choice. Its job writes `LANG=`
to `/etc/locale.conf` (`de` → `de_DE.UTF-8`), which covers the system
locale every PAM session and `install/lib/i18n.sh` inherit, but
`Commons/I18n.qml` picks its translation file from `language.ui` in
`config.json`. `provision-iso.sh` reads `LANG` out of `/etc/locale.conf`
and sets `language.ui` with `jq`, leaving the rest of the file (including
`language.fallback`, always English) untouched. The mapping is
`de_DE.UTF-8` → `de`: everything before the first `_` or `.`, lowercased.
The Location step used to keep a `LANG` already stored from the live ISO,
so choosing German on Welcome still installed `en_US.UTF-8`. The AUR
patch reads the Welcome language first.
It is accepted only if `translations/<code>.json` exists in the user's home,
so anything else the installer could produce — and `C.UTF-8` — lands on `en`
rather than on a file `I18n` cannot open. A missing `/etc/locale.conf` or a
missing `LANG` is a warning, not a failure, and leaves `config.json` alone.
`language.ui` is the single source of truth: Settings → Language writes that
same key and `session-chrome-sync.sh` rebakes the greeter `chrome.json`.

The greeter strings come from `/var/lib/modern/session/chrome.json`, which
`session-chrome-sync.sh` (via wallpaper-sync or Settings → Language) bakes
from `language.ui`. Keyboard layout is the sibling snapshot
`keyboard.json`. `greetd_apply` bakes both while it copies the greeter, so
that call has to come after `language.ui` and `kbLayout` are in
`config.json`. An earlier bake left the login screen in English on a `us`
layout even when the desktop later followed the install. The second
wallpaper-sync still refreshes the same files.
`scripts/test-calamares-late.sh` pins that ordering.

The **Network** / **Netzwerk** page sits after Keyboard. Next stays off
until Ethernet or Wi-Fi is up (or a default route exists). Wi-Fi turns
on (no toggle): nearby list with lock/open labels, **Connect** on each
row, **Refresh**, and a password card for secured networks. Ethernet or
Wi-Fi already up shows a centered “You're connected with …” page.
Live setup enables NetworkManager on the wpa_supplicant backend,
masks `iwd`, and releases any Wi-Fi interface systemd-networkd already
claimed. A reload alone leaves that interface out of NetworkManager, so
the scan list stays empty. Before Calamares
starts, it points `unpackfs` at the `airootfs` image archiso actually
mounted (the stick, or `copytoram` after that boot entry). Unattended QEMU already has virtio-net, so auto-next is
not blocked. `stylesheet.qss` paints `#networkPage`, `#networkOkPage`,
and `#wifiList` from the same tokens as the rest of Calamares. The C++
module is copied into AUR Calamares at build (`iso/releng/calamares-modernnet`).
Late `pacman` still needs that route.

`install.sh` and `provision-iso.sh` call the same `greetd_apply`, which
enables `NetworkManager`, `greetd`, `bluetooth` and `systemd-timesyncd`
**one unit per call** — `systemctl enable a b c` aborts the whole list
on the first unit that does not exist, so one missing package used to
take the install down. NetworkManager and greetd are required; the
other two log and continue. `bluez` is its own manifest
entry: `bluez-utils` is only `bluetoothctl` and does not depend on it, so
without `bluez` there is no `bluetoothd`, no `bluetooth.service`, and no
`org.bluez` for `Services/Bluetooth` to bind. Late desktop also installs
the packages behind those units directly, so pins predating that manifest
line still provision. `ufw` and `openssh` are installed
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
`[multilib]` (needed for `steam` and `lib32-gamemode`), sets `IgnorePkg` for
`jack2` / `pulseaudio` (`--noconfirm` answers **No** to “Remove jack2?”),
installs the PipeWire stack, overlays pin `install_native` so old tags
cannot one-shot ffmpeg+pipewire-jack, rewrites pin `matugen` /
`bibata-cursor-theme` (including a trailing comment) to the `-bin`
packages already on the squashfs, `NoExtract`s `resolv.conf` so a
`systemd` upgrade cannot point DNS at an empty `/run`, then
`install.sh --profile m0 --yes` (`--needed` skips native packages already
unpacked; `install_aur` skips names `pacman -Q` already has (and
skips `foo-bin` when source `foo` is installed — they conflict), and
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
label, so the pill itself needs no new string. Hiding the footer cannot
strand anyone — a failed install quits from the error dialog and never
reaches this page.

The message above the pill is patched too. Upstream ends with an offer to
"continue using the %2 Live environment", and `%2` is branding
`productName` — that is where **ModernOS Live** came from on a page about
the installed system. `calamares-limit-languages.py` replaces that
`tr()` with `<h1>All done.</h1><br/>%1 is installed and ready.<br/>Restart
to start using your new desktop.` and rewrites the matching
`FinishedPage` entry in Calamares' own `lang/calamares_de.ts`, so both
languages change together. `productName` stays **ModernOS**: it is also
the Welcome title, the summary and the bootloader entry, and none of those
are wrong.

If you land on a TTY, this image never started greetd:

```bash
/usr/lib/modern/live-session.sh
```

Welcome **Support** / **Known issues** open GitHub in Firefox on the
same Xwayland display. Cage does not decorate X11 windows, so the live
session runs **openbox** (Calamares stays fullscreen without a titlebar).
Close Firefox with its window-close button or Alt+F4 to return to the
installer. **Donate** opens https://ko-fi.com/gamesearch56. The VM needs virtio 3D.

Calamares is still Qt Widgets for every *page* (Welcome, Partitions,
Users, …). `stylesheet.qss` can restyle those: colors, field radii,
buttons, the exec bar. The AUR build also applies that QSS on `qApp`,
because Qt-owned child windows do not inherit the main window's sheet.
Combo lists are **not** `Qt::Popup` windows here: cage ignores the X11
`ConfigureWindow` Qt sends for one, so a native list always mapped at
the screen origin over the sidebar. The AUR patch suppresses the combo's
own popup and draws the list as a `QListView` child of the installer
window (`#modernComboOverlay`), placed with
`combo->mapTo( window, { 0, 0 } )` at the field's width — below the
field, above it when there is no room below, clamped and scrolling when
the list is taller than either side. Every `QComboBox` in the installer
goes through that one filter. It cannot round the default left-hand step list —
that is a C++ delegate. `sidebar: qml` + `calamares-sidebar.qml` is the
escape hatch used here (nav pills and a padded About, like Settings).
The logo is `iso/airootfs/etc/calamares/branding/modern/logo.png`.

Settings → Update later tracks the latest GitHub **release tag**, not
`dev` or the tip of `main`.

### Real hardware (laptops)

A VM has virtio Ethernet, no radio and UEFI. A laptop differs here:

- **Secure Boot off.** The ISO and the installed systemd-boot/GRUB are
  unsigned. Prefer UEFI mode; Legacy/CSM works through the GRUB path.
- **Boot menu is hidden.** systemd-boot starts the default entry at once
  (`timeout 0` in Calamares `bootloader.conf`); hold Space while the
  machine starts to open the menu. A kernel that fails to boot falls
  back to the recovery kernel on its own.
- **Network during install is required** — the desktop phase downloads
  packages. Wi-Fi in the Network step goes through NetworkManager.
  The live image builds `wl.ko` for its linux-zen and loads it only for
  Broadcom chips that need it (BCM4311/4312/4321/4322/43142/43227/
  43228/4331/4352/4360). Every other radio stays on the in-tree driver.
  Refresh on the Network step re-runs `live-wifi-up.sh` (unblock, `wl`,
  hand the radio to NetworkManager, rescan). An empty list then says
  why: a Wi-Fi switch, a chip with no driver (with its PCI id), or no
  adapter at all.
  A chip left without an interface gets its driver loaded by PCI id.
  If that is `rtw88` (RTL8821CE, RTL8822CE, ...) and the probe still
  fails, it is reloaded with `rtw88_pci disable_aspm=y disable_msi=y`,
  and the strip phase writes the same option to the target's
  `/etc/modprobe.d/modern-rtw88.conf`.
  `install.sh` still installs `broadcom-wl-dkms` for those chips so the
  installed kernel keeps the module. Ethernet or USB tethering remains
  a way through the Network step when the radio itself has no firmware.
- **Installed networking** is NetworkManager alone (default
  wpa_supplicant backend) for wired and Wi-Fi; the live image's
  systemd-networkd and iwd split is stripped. The Wi-Fi joined in the
  installer is copied over by `networkcfg`.
- **GPU.** Turing and newer NVIDIA get `nvidia-open-dkms`. Older NVIDIA
  (Kepler … Volta, e.g. GeForce MX150/GTX 10xx) runs nouveau — the
  proprietary branch for them is no longer in the repos. Intel gets both
  VA-API drivers so pre-Broadwell iGPUs decode video too.
- **Failure:** the error dialog shows the tail of the failed step; the
  full log is `/var/log/modern-calamares-late.log` on the target.

## After stow (on the **target** user)

`install.sh` phase 5 applies `~/.config/modern/wallpapers/default.jpg`
(tokens, GTK/Qt/kitty). `wallpaper-sync.sh` writes lock/login assets to
`/var/lib/modern/session` after greetd apply (else
`$XDG_STATE_HOME/modern/session`). Nautilus sidebar starts with Downloads, Pictures, and Videos
(`nautilus-prefs.sh`, XDG dirs for the target user). First-hour UI is
**English**. Power-menu lock is `WlSessionLock` and checks the session
password with PAM. Titlebars need a one-time `hyprpm` + pkexec
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
   each file's header comment has the copy command. Greetd is applied by
   `install.sh` (`install/lib/greetd.sh`); `provision-iso.sh` calls the
   same function.

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

If `MODERN_PROTECT_HOME` is your `$HOME`, pass `--allow-live-home` (or
`--target` elsewhere). See `docs/CUTOVER.md`.
