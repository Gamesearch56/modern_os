# Package manifests

Hand-curated, one package per line, `# comment` explaining why it's here.
No pacman hook regenerates these — see `docs/DECISIONS.md` §11. Blank
lines and `#`-prefixed lines are ignored by `install/lib/pkg.sh`.

- `NN-name.txt` — native repo packages (`pacman -S`).
- `NN-name.aur.txt` — AUR/foreign packages (built via the bootstrapped
  `yay`, never `pacman -S` — see the audit bug this fixes in
  `docs/DECISIONS.md`).
- `60-flatpak.txt` — flatpak application IDs.

Layers, applied in order by `install.sh --profile <name>`:

| Layer | Profile membership | Content |
|---|---|---|
| `00-base` | all profiles | kernel/firmware, filesystem tools, shell essentials, `stow`, `yay` bootstrap deps |
| `00-hw-cpu-*` | auto or `--cpu` | CPU microcode (`amd` / `intel`) |
| `00-hw-gpu-*` | auto or `--hw` | GPU stack for every profile (RADV, Intel, NVIDIA DKMS) |
| `10-desktop` | all profiles | Hyprland, Quickshell, portals, audio/network/bluetooth stack, clipboard/screenshot tools, kitty, Nautilus, Vivaldi, gedit, mpv, imv. AUR: `phylax-git` (`10-desktop.aur.txt`) |
| `20-theming` | all profiles | fonts, matugen, GTK/Qt theming support |
| `30-apps` | `m0`+ | codecs, Spotify, Steam, GameMode, gamescope, umu-launcher (Battle.net) |
| `30-hw-gpu-*` | with `30-apps`, auto or `--hw` | Steam's 32-bit Vulkan driver for this GPU (else pacman picks `lib32-vulkan-radeon`) |
| `50-gaming` | `gaming`, `full` | 32-bit Mesa and GameMode, launchers, MangoHud |
| `50-hw-*` | gaming/full + `--hw` | 32-bit GPU libraries (`lib32-*`) |
| `60-flatpak` | `full` | flatpak-distributed apps |
| `90-accounts.aur` | `--extra proton` | Proton Mail / Pass |

Run `scripts/snapshot-packages.sh --diff` any time to see drift between
this machine's installed packages and these manifests.

Settings → Store treats `00-*`, `10-*` and `20-*` as the undeletable
system set (`scripts/pkg-manifest-names.sh --core`, also enforced by
`scripts/pkg-mutate.sh`). `30-apps` and the gaming layers stay
removable there. Installer-only packages from the live ISO (Calamares,
the kiosk, Firefox, …) are removed by `calamares-late.sh` after the
desktop is provisioned.
