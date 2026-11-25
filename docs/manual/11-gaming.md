# Gaming

ModernOS is set up for playing games out of the box. This chapter covers
what is already installed, the **Gaming** page in System Settings, how
games behave on the desktop, graphics drivers, and what to do when a game
runs poorly.

## What is already installed

Every ModernOS installation includes:

- **Steam**, with **Proton** to run Windows games;
- **GameMode**, which gives a running game more processor power;
- **gamescope**, for per-game resolution and upscaling;
- **umu-launcher**, which ModernOS uses to run **Battle.net**.

GameMode starts by itself when you sign in. Games that ask for it get the
faster processor setting while they run, and the normal setting comes back
when you quit.

## The Gaming page

Open **System Settings** (**Systemeinstellungen**) with **SUPER + I** and
choose **Gaming** (**Spiele**).

### Your library at a glance

The top of the page shows tiles about the games on this computer:

| Tile | Shows |
|---|---|
| **Last played** (**Zuletzt gespielt**) | The date and name of the last game you played |
| **Hours played** (**Spielzeit**) | Your total play time |
| **Installed** (**Installiert**) | How many games are installed |
| **Library** (**Bibliothek**) | How much disk space your games use |
| **Open now** (**Gerade offen**) | A game that is running right now |

The numbers come from Steam, Lutris, Heroic and Battle.net on this
computer. Nothing is looked up online.

### Play

- **Gaming mode** (**Spielmodus**) keeps the session awake while a game
  is open and marks that window as a game.
- **Fullscreen games automatically** (**Spiele automatisch im Vollbild**)
  puts a game into fullscreen as soon as its window appears, instead of
  waiting for the game to ask for it. This is on by default.
- **HDR for games** (**HDR für Spiele**) lets games use HDR while the rest
  of the screen stays as it is. It can only be turned on when an HDR
  display is connected; otherwise the page says **No HDR display is
  connected**. The HDR section below has the details.

### Performance

**Drop effects for speed** (**Effekte für Tempo weglassen**) is meant for
slow PCs and laptops. It turns off blur, shadows and the wobble when
moving windows across the whole desktop, and makes panels and windows
opaque. Games show their frames directly, and the browser runs lighter
once you have quit and reopened it.

## How games behave on the desktop

ModernOS recognises game windows: Steam games, gamescope, Windows games
running through Proton, and a list of well-known titles. Launchers such as
Steam itself and Battle.net stay normal windows.

- **Fullscreen.** A game that already covers the screen is left alone. A
  game that is still a normal tile goes fullscreen. A game in "windowed
  fullscreen" is maximised so the bar stays visible.
- **The bar** hides while a game is in fullscreen and comes back when you
  leave it.
- **SUPER + F** leaves or enters fullscreen, also in games. Your other
  shortcuts keep working, and the game cannot swallow them.
- **AI chat** (SUPER + A) and **Applications** (SUPER + DELETE) open on top
  of a fullscreen game.
- With **Drop effects for speed** on, the game window also gets no blur,
  no shadows and no animations.

If you never want games forced into fullscreen, turn off **Fullscreen
games automatically**. New game windows are then left as they open.

## Steam and Proton

Start Steam from its own entry in the launcher (SUPER + SPACE). The very
first start downloads and sets up Steam; let it finish without changing
anything.

To give a single game extra speed, use its launch options in Steam
(right-click the game, then Properties). For example:

```
gamemoderun %command%
```

This asks GameMode to boost the processor for that game.

### Proton versions

Steam brings its own Proton versions, such as Proton Experimental. If you
add extra Proton builds yourself, keep only **one** extra build in
`~/.local/share/Steam/compatibilitytools.d/`. Every tool in that folder
makes Steam re-check your graphics card on each start, and many of them
can make Steam and even sound noticeably slow. Move builds you do not use
out of that folder.

## Battle.net

Choose **Battle.net** in the launcher. No setup file is needed:

1. On the first start, ModernOS downloads Blizzard's installer and runs
   it. Follow it, and Battle.net opens when it is done.
2. Later starts find the installed client and open it directly.
3. Preparing Proton for the first start can take a few minutes.

Because there is no terminal, every problem appears as a notification,
for example when the download fails or Battle.net closes right after
starting. The details are written to `~/.local/state/modern/battlenet.log`.

Tips:

- If the Battle.net window is black or white, turn off hardware
  acceleration in Battle.net's own settings.
- Install World of Warcraft on an SSD or NVMe drive; a hard disk often
  causes hitching.

## HDR

1. Turn HDR on for your monitor under **System Settings → Display**
   (**Anzeige**).
2. Turn on **HDR for games** on the Gaming page.
3. **Battle.net games** pick it up the next time Battle.net starts.
4. **Steam games** need it in that game's launch options:

```
DXVK_HDR=1 ENABLE_HDR_WSI=1 PROTON_ENABLE_HDR=1 %command%
```

5. If the game has an HDR option in its graphics menu, turn it on there
   as well.

HDR is deliberately not switched on for the whole desktop, because that
makes browsers and the Steam window lag.

## Graphics drivers

The installer picks the driver for your graphics card:

- **AMD**: the standard open-source Vulkan driver (RADV).
- **Intel**: the open-source drivers, including video decoding for older
  chips.
- **NVIDIA, Turing generation (GeForce GTX 16 and RTX 20 series) and
  newer**: NVIDIA's open kernel driver.
- **Older NVIDIA cards** (for example GeForce GTX 10 series or MX150): the
  open-source nouveau driver, because NVIDIA's own driver for these cards
  is no longer offered.

Steam also needs a 32-bit Vulkan driver for your card; that is installed
together with Steam.

## The performance widget

The bar can show your current processor and memory load. Open **System
Settings → Bar** (**Leiste**), find **Performance** (**Leistung**) under
**Available widgets** (**Verfügbare Widgets**) and turn it on. The bar
then shows **CPU** and **RAM** in percent. The widget only measures while
it is visible, so it costs nothing when you hide it.

## When a game runs poorly

- **Turn on Gaming mode** so the session stays awake while you play.
- **Try `gamemoderun %command%`** in the game's launch options.
- **Turn on Drop effects for speed** on slower hardware.
- **Check your Proton tools** and remove extra builds (see above).
- **Install large games on an SSD.**
- **Report it.** Press **SUPER + #** and choose **Games** (**Spiele**) as
  the affected area. The report includes your graphics driver and the
  Proton tools you have installed. See
  [Troubleshooting](14-troubleshooting.md).

Some games need system-wide tweaks, such as a higher memory map limit,
that ModernOS does not apply by default. These are described for advanced
users in [../GAMING.md](../GAMING.md).

## Related chapters

- [Settings](07-settings.md) for the Display and Energy pages.
- [Keyboard shortcuts](06-keyboard-shortcuts.md) for SUPER + F and the
  other shortcuts that work in games.
- [Apps](09-apps.md) for installing more launchers from the App Store.
