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
| `00-hw-*` | auto or `--hw` | CPU microcode (`amd` / `intel`) |
| `10-desktop` | all profiles | Hyprland, Quickshell, portals, audio/network/bluetooth stack, clipboard/screenshot tools |
| `20-theming` | all profiles | fonts, matugen, GTK/Qt theming support |
| `30-apps` | `m0`+ | terminal, file manager, browser, minimal daily-driver apps |
| `40-dev` | `dev`, `full` | languages, toolchains, containers, Cursor |
| `50-gaming` | `gaming`, `full` | Steam, launchers, gamemode/gamescope |
| `50-hw-*` | gaming/full + `--hw` | GPU Vulkan (`amd` RADV/ROCm, `nvidia` utils) |
| `60-flatpak` | `full` | flatpak-distributed apps |
| `90-accounts.aur` | `--extra proton` | Proton Mail / Pass |

Run `scripts/snapshot-packages.sh --diff` any time to see drift between
this machine's installed packages and these manifests.
