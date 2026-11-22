# Package manifests

For developers and packagers: which packages ModernOS installs, how they
are split into layers, and which install profile pulls each layer in.

Hand-curated, one package per line, `# comment` explaining why it's here.
No pacman hook regenerates these — see `docs/DECISIONS.md` §11. Blank
lines and `#`-prefixed lines are ignored by `install/lib/pkg.sh`.

- `NN-name.txt` — native repo packages (`pacman -S`).
- `NN-name.aur.txt` — AUR/foreign packages (built via the bootstrapped
  `yay`, never `pacman -S` — see the audit bug this fixes in
  `docs/DECISIONS.md`).
- `60-flatpak.txt` — flatpak application IDs.
- `default-apps.json` — text editor, image viewer, and video player.
  Each role has a desktop id, pacman packages, and optional `exec`,
  `stow`, and `windowRule` for an external app. The shipped defaults are
  the ModernOS Texteditor, Imageviewer and Mediaplayer, which need no
  extra packages. `install.sh`, `pkg-manifest-names.sh`, `files-open.sh`,
  and `mime-defaults.sh` read this file. `config.default.json`
  `apps.defaults` repeats the desktop id so Settings can seed
  `config.json`.

Layers, applied in order by `install.sh --profile <name>` (profiles:
`m0`, the default, `gaming`, `full`):

| Layer | Profile membership | Content |
|---|---|---|
| `00-base` | all profiles | kernel/firmware, filesystem tools, shell essentials, `stow`, `yay` bootstrap deps |
| `00-hw-cpu-*` | auto or `--cpu` | CPU microcode (`amd` / `intel`) |
| `00-hw-gpu-*` | auto or `--hw` | GPU stack for every profile (RADV, Intel, NVIDIA DKMS, or nouveau for `nvidia-legacy`) |
| `00-hw-wifi-broadcom-wl` | auto (Broadcom chip detected) | `broadcom-wl-dkms` for chips that need the `wl` driver |
| `10-desktop` | all profiles | Hyprland, Quickshell, portals, audio/network/bluetooth stack, clipboard/screenshot tools, kitty, Vivaldi. The file manager is the shell, not a packaged app. AUR: `phylax-git` (`10-desktop.aur.txt`). Text editor, image viewer, and video player packages are `default-apps.json`, not inlined in this layer. |
| `20-theming` | all profiles | fonts, matugen, GTK/Qt theming support |
| `30-apps` | all profiles | codecs, ffmpeg, neovim, btop, fastfetch, Spotify, Steam, GameMode, gamescope, umu-launcher (Battle.net). AUR: `proton-pass-bin` (`30-apps.aur.txt`). |
| `30-hw-gpu-*` | with `30-apps`, auto or `--hw` | Steam's 32-bit Vulkan driver for this GPU (else pacman picks `lib32-vulkan-radeon`) |
| `50-gaming` | `gaming`, `full` | 32-bit Mesa and GameMode, protontricks, Proton VPN, MangoHud |
| `50-hw-*` | `gaming`, `full`; GPU auto or `--hw` | 32-bit GPU libraries (`lib32-*`) |
| `60-flatpak` | `full` | flatpak-distributed apps (Bottles) |
| `70-workstation` | `full` | development (Docker, Node, Rust, Java, Godot), VMs and ISO building (QEMU, libvirt, archiso), Samba, Ollama, Discord, Lutris, Shotcut, command-line tools. AUR: Cursor, Ventoy, downgrade, game companions (`70-workstation.aur.txt`). `install/lib/workstation.sh` enables `docker.socket` and `libvirtd.socket` and adds the `docker` and `libvirt` groups; Samba stays off until it has shares. |
| `70-hw-gpu-*` | `full`; GPU auto or `--hw` | GPU compute (ROCm on AMD, for Ollama) |
| `90-accounts.aur` | `--extra proton` | Proton Mail |

Run `scripts/snapshot-packages.sh --diff` any time to see drift between
the installed packages and these manifests.

Settings → Store treats `00-*`, `10-*` and `20-*` as the undeletable
system set (`scripts/pkg-manifest-names.sh --core`, also enforced by
`scripts/pkg-mutate.sh`). `30-apps` and the gaming layers stay
removable there. Installer-only packages from the live ISO (Calamares,
the kiosk, Firefox, …) are removed by `calamares-late.sh` after the
desktop is provisioned.
