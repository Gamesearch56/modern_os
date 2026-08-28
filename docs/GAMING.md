# Gaming

System tweaks and helpers for Proton / native games on this Hyprland
setup. Kernel sysctls live under `install/system/` and are **gated** —
`install.sh` never applies them. Read `docs/ISOLATION.md` first.

## Kernel: `vm.max_map_count`

Some Proton/Wine titles mmap huge numbers of regions. The default
`vm.max_map_count` (often 65530) is too low.

Staged file: `install/system/sysctl.d/99-modern-gaming.conf`

```
vm.max_map_count = 1048576
```

Apply only when you intend this machine-wide:

```bash
sudo cp install/system/sysctl.d/99-modern-gaming.conf /etc/sysctl.d/
sudo sysctl --system
```

## File-descriptor limits

Wine also opens many files. systemd user sessions inherit `DefaultLimitNOFILE`
from `/etc/systemd/system.conf` / `user.conf`. A typical raise:

```
# /etc/security/limits.d/99-modern-gaming.conf  (gated, not shipped)
* soft nofile 1048576
* hard nofile 1048576
```

`config.json` → `gaming.systemFixes.fileDescriptorLimits` records the
preference; it does not write limits files.

## `kernel.split_lock_mitigate`

The kernel's split-lock mitigation can add large stalls on some games.
The staged sysctl sets `kernel.split_lock_mitigate = 0`. Measure frame
times before and after; this is a throughput trade against a class of
buggy userspace, not a free lunch. Default in `config.json` is
`gaming.systemFixes.splitLockMitigate: false` (do not assume it is on).

## HDR environment variables

Set per-game (Steam launch options) or in a wrapper — not globally in
the session, because not every compositor/client is HDR-ready.

```
# Vulkan / DXVK / Proton (keep as launch options, not ~/.bashrc)
DXVK_HDR=1
ENABLE_HDR_WSI=1
PROTON_ENABLE_HDR=1
# gamescope HDR (needs a gamescope session that supports it)
# gamescope --hdr-enabled --hdr-debug-force-output -- %command%
```

## AMD environment presets

These are **not** injected by `scripts/game-profile.sh`. Paste only the
ones a given title needs:

```
# RADV / Mesa
RADV_PERFTEST=gpl          # graphics pipeline library; try if compile stutters
AMD_VULKAN_ICD=RADV        # force RADV over amdvlk if both are installed
mesa_glthread=true         # GL; ignore for pure Vulkan titles

# DXVK / vkd3d (Proton)
DXVK_ASYNC=1               # legacy; prefer a DXVK build that does not need it
VKD3D_CONFIG=dxr           # raytracing path; title-specific
```

## OptiScaler

[OptiScaler](https://github.com/OptiScaler-Releases/OptiScaler) is
dropped next to a game's EXE as a DXGI (or other) proxy DLL. This repo
never deletes the game's own `dxgi.dll`: `scripts/optiscaler.sh apply`
copies the original into `GAME_DIR/.modern-optiscaler-backup/` first.

```bash
scripts/optiscaler.sh fetch                 # GitHub latest → ~/.local/share/modern/optiscaler/<tag>/
scripts/optiscaler.sh list
scripts/optiscaler.sh games                 # Steam library folders from ~/.steam/steam/steamapps/libraryfolders.vdf
scripts/optiscaler.sh apply GAME_DIR [dxgi] # proxy name without .dll
scripts/optiscaler.sh remove GAME_DIR       # restore backup
```

Needs `curl` and `jq`. A failed network fetch prints a clear error and
leaves the game directory untouched.

## modern game CLI

`scripts/modern-game` is the alias wrapper (`modern game` in
`scripts/modern` execs it):

```bash
modern-game optiscaler fetch
modern-game optiscaler list
modern-game optiscaler apply GAME_DIR [proxy]
modern-game optiscaler remove GAME_DIR
modern-game optiscaler games
```

Launch-option string (no AMD env — see above):

```bash
scripts/game-profile.sh --gamemode --gamescope --mangohud
# → gamemoderun gamescope -- mangohud %command%
```
