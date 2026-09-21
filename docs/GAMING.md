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

Set per-game (Steam launch options / Battle.net wrapper) or enable
**Settings → Gaming → HDR for Proton games** (`gaming.hdrSession`).
That exports the vars below from `env.lua` for the Hyprland session and
from `scripts/battlenet` for the Proton prefix (so WoW inherits them).

Also turn **HDR on for the display** under Settings → Displays (your
AW2725DF profile already can). Not every title needs Proton Wayland;
Battle.net stays on XWayland (`PROTON_ENABLE_WAYLAND=0`) so its UI does
not white-screen. True HDR in-engine still depends on the game offering
an HDR option.

```
DXVK_HDR=1
ENABLE_HDR_WSI=1
PROTON_ENABLE_HDR=1
# gamescope --hdr-enabled --hdr-debug-force-output -- %command%
```

Optional `gaming.protonWayland: true` exports `PROTON_ENABLE_WAYLAND=1`
session-wide — do not enable that while using Battle.net’s Chromium UI.
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

## Automatic fullscreen and per-window optimize

Hyprland matches Steam (`steam_app_*`), `gamescope`, Wine `*.exe`, and
native titles such as Project Zomboid (`ProjectZomboid*`, window title
`Project Zomboid`) — see `gaming.matchClass` / `gaming.matchTitle` in
`config.json`. Launchers stay windowed. Those game windows get:

- **Exclusive fullscreen once**, when Hyprland can identify the game.
  Static `fullscreen` window rules stay off so `SUPER+F` can leave
  exclusive mode. Java/LWJGL titles (Project Zomboid) often map tiled
  first and rename after boot — `games.lua` dispatches
  `fullscreen_state 2 2` on `window.open` / `window.class` /
  `window.title`, then leaves that window alone. Listeners re-read
  `gaming.autoFullscreen` so the Settings toggle still stops new
  windows from being forced. The bar hides while the focused window is
  exclusive fullscreen; HUD binds and `SUPER+F` set `dont_inhibit` and
  `allow_input_capture` so the game cannot swallow them.
- **Tearing** (`immediate`) — only that window, and only while it is
  exclusive fullscreen. Other clients stay vsync.
- **No blur / no shadow / opaque / content: game** on the game surface
  (no compositor titlebar)

`general.allow_tearing` is the master switch; it does not tear browsers
or terminals. Blur and animations stay on for everything else.

If `gamemoded` is installed it is started at login. Steam/Lutris titles
that call GameMode raise the CPU governor for the game's lifetime, then
restore the previous policy.

Settings → Gaming can turn fullscreen or optimize off. An old
`windowRules` entry named `steam-game` is ignored (it used to send games
to `special:game` and hide them). That name is no longer in the defaults.

Fullscreen games cover the bar, so AI (`SUPER + A`) and the taskbar
(`SUPER + DELETE`) open as Overlay layer-shell windows — the same path
as the launcher and control panel — instead of bar-anchored popups.

## Battle.net / World of Warcraft (no Lutris)

Preferred stack: **Steam non-Steam game + Proton Experimental (launcher) +
XWayland**, with a stowed `.desktop` so Super+Space lists Battle.net.
GE-Proton is fine for *games* launched from the client; the Battle.net
CEF UI itself often dies on GE 11.x (see below). Lutris stays in the
gaming manifest for other titles; Battle.net’s Chromium UI under Proton
Wayland often white-screens on Hyprland.

### Packages

- `steam`, `gamemode`, `lib32-gamemode`, `umu-launcher` (`50-gaming.txt`)
- `protonup-qt`, `wowup-cf-bin` (AUR)
- AMD: `vulkan-radeon` + `lib32-vulkan-radeon` (RADV). Prefer RADV over
  `amdvlk` if both are installed (`AMD_VULKAN_ICD=RADV`).

Install GE-Proton via ProtonUp-Qt (Steam compatibility tools).

### One-time host tweaks (gated)

```bash
sudo cp install/system/sysctl.d/99-modern-gaming.conf /etc/sysctl.d/
sudo sysctl --system
```

Raises `vm.max_map_count` and optionally disables split-lock mitigation
(see sections above). Raise `nofile` if Wine hits EMFILE.

### Steam install

1. Add the Battle.net installer as a **Non-Steam game**.
2. Compatibility: **Proton Experimental** for the launcher (GE-Proton 11.x
   has been aborting the CEF UI — see below). Use GE on individual games
   in Steam if needed.
3. Launch options:

   ```
   PROTON_ENABLE_WAYLAND=0 WINE_SIMULATE_WRITECOPY=1 AMD_VULKAN_ICD=RADV gamemoderun %command%
   ```

4. After install, retarget the shortcut to `Battle.net Launcher.exe`.
5. Install **World of Warcraft on NVMe/SSD** (HDD streaming hitching is
   common).
6. Copy the env example and point it at the **Launcher EXE** inside
   `compatdata/<id>/pfx` (not `STEAM_APPID` — Non-Steam
   `-applaunch` / `steam://rungameid/` often fails with “game
   configuration is not available” on Linux):

   ```bash
   cp stow/modern/.config/modern/battlenet.env.example \
      ~/.config/modern/battlenet.env
   # set BATTLENET_EXE=…/Battle.net Launcher.exe
   # set WINEPREFIX=…/compatdata/<id>/pfx
   # PROTONPATH defaults to Proton Experimental if unset
   ```

`scripts/battlenet` / `modern battlenet` runs that EXE with Proton
(Experimental preferred; GE if you set `PROTONPATH`) via `umu-run` when
installed, otherwise Steam’s `proton waitforexitandrun`, under GameMode +
RADV + XWayland. No gamescope or MangoHud by default.

Optional: `STEAM_APPID` still tries `steam://rungameid/` without wrapping
the Steam client in GameMode — use only if the EXE path is unavailable.

**Battle.net UI vs Warcraft III:** leave `PROTONPATH` on **Proton
Experimental** so the launcher starts. GE-Proton 11.x has been aborting
the CEF client (`win32u.NtGdiDdDDIQueryFSEBlock`). Games you start *from*
Battle.net use that same runner — there is no separate Steam
“Compatibility” for WC3 unless you add `Warcraft III.exe` as its own
non-Steam shortcut.

For the Forsaken Kingdom / certificate-chain fix, either run the full
official **GE-Proton11-7** (when the launcher works on it again), or
transplant that release’s `crypt32.dll` into Experimental per the
GE-Proton11-7-crypt32 README (`files/lib/wine/{x86_64,i386}-windows/`).
Do not put those DLLs in the prefix `system32`.

### Hyprland behaviour

- **Battle.net:** excluded from `games.lua` auto-fullscreen/optimize so
  it stays a normal window. Default `windowRules` entry
  `battlenet-launcher` floats, centers, and sizes to `1280 800`.
- **World of Warcraft / Warcraft III:** matched by title (and common
  Proton classes) for Settings → Gaming `autoFullscreen` +
  `autoOptimize` — exclusive FS, tearing, opaque game content.
  Relaunch the game after a Hyprland reload if an older session still
  maps them windowed.
- **HDR:** enable Settings → Gaming → HDR for Proton games (and Displays
  HDR on the panel). Restart Battle.net so the Proton prefix inherits
  `DXVK_HDR` / `ENABLE_HDR_WSI` / `PROTON_ENABLE_HDR`. Turn HDR on in
  the game’s graphics menu when available.

Existing machines that already have a `windowRules` array must **merge**
`battlenet-launcher` into live `config.json` (JsonAdapter does not
deep-merge rule arrays). Then reload Hyprland / `modern config restore`
is not enough for this key alone — edit or paste the rule.

After first launch, confirm with `hyprctl clients` if the title/class
differs; tighten the rule. WoW’s title must not match Battle.net.

### In-client

- Battle.net: disable **hardware acceleration** if the UI is black/white
  (Settings, or set `"HardwareAcceleration": "false"` in
  `…/AppData/Roaming/Battle.net/Battle.net.config`). The wrapper also
  passes `--in-process-gpu` by default.
- WoW: DirectX 12, exclusive fullscreen, match monitor refresh.
- Optional stutter experiment only: `RADV_PERFTEST=gpl` (not default).

### WowUp CF addons

1. Launch WowUp CF (`wowup-cf-bin`).
2. Point it at the retail AddOns folder, typically under the Steam Proton
   prefix:

   ```
   …/compatdata/<id>/pfx/drive_c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns
   ```

   Or the path you chose when installing WoW on SSD. Create
   `Interface/AddOns` if missing.
3. Install/update addons there; start WoW from Battle.net as usual.

### App manager

- Desktop: `stow/xdg/.local/share/applications/battlenet.desktop`
- Icon: `stow/xdg/.local/share/icons/hicolor/scalable/apps/battlenet.svg`
  (replace with your branded SVG if you have one)
- After restow: Super+Space → **Battle.net**
