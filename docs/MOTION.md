# Motion system

The target feel is MD3 *expressive* motion: smooth but snappy, slightly
overshooting, spatially coherent. `Commons/Motion.qml` is the only place
duration/easing/spring numbers exist — nothing else in the codebase
contains a literal millisecond value or bezier curve.

## Tokens

```qml
// Commons/Motion.qml (excerpt)
readonly property int durationShort: 100
readonly property int durationMedium: 250
readonly property int durationLong: 400
readonly property int durationExtraLong: 600

// Ready to assign to `easing.bezierCurve` directly: QML's BezierSpline
// format is [cx1, cy1, cx2, cy2, endX, endY, ...] and must end at (1, 1)
// (see https://doc.qt.io/qt-6/qml-qtquick-propertyanimation.html). The
// 4 raw MD3 control-point numbers are what's mirrored in
// modules/motion_tokens.lua's `bezier` table, since Hyprland's
// `hl.curve()` doesn't need the trailing anchor point.
readonly property var easingEmphasized: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
readonly property var easingEmphasizedDecelerate: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
readonly property var easingEmphasizedAccelerate: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
readonly property var easingStandard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

readonly property real scale: Config.motion.scale ?? 1.0 // 0 = off, 1.5 = slow-mo
function short(): int { return Math.round(durationShort * scale); }
function medium(): int { return Math.round(durationMedium * scale); }
function long(): int { return Math.round(durationLong * scale); }
function extraLong(): int { return Math.round(durationExtraLong * scale); }
```

- **Durations**: `short` 100ms (state toggles), `medium` 250ms (popups,
  panel open/close), `long` 400ms (page transitions), `extraLong` 600ms
  (session surfaces, large overlays). Bind `Motion.shortMs` /
  `mediumMs` / `longMs` / `extraLongMs` (and `overlaysFade` /
  `overlaysZoom`) so `motion.scale` re-evaluates. The `short()` /
  `medium()` functions remain as aliases.
- **Easing**: `emphasized` for anything entering/leaving the screen,
  `emphasizedDecelerate` for enters, `emphasizedAccelerate` for exits,
  `standard` for small in-place state changes (hover, press).
- **Springs**: named `SpringAnimation` presets — real QML `SpringAnimation`
  properties are `spring` (stiffness), `damping` (0–1, lower = faster
  settle), `mass` (default 1.0), not the `stiffness`/`damping`-as-tension
  naming other motion libraries (Framer Motion, React Native Reanimated)
  use. `snappy` (`spring: 3.5, damping: 0.4` — buttons, toggles, workspace
  pills), `gentle` (`spring: 2.2, damping: 0.5` — panels, popups), `bouncy`
  (`spring: 4.0, damping: 0.25` — launcher open, wallpaper picker grid).
  Starting points, not final — tune by eye once the shell actually
  renders. Applied via `Behavior on x/y/scale/opacity { SpringAnimation {
  spring: Motion.springBouncy.spring; damping: Motion.springBouncy.damping } }`.

## Rules

1. **State changes use `Behavior`, never an imperative `.start()`.** This
   is what makes interruption mid-animation work — flicking the volume
   pill twice doesn't queue two animations, it redirects the running one.
2. **Animate GPU-cheap properties**: `opacity`, `scale`, `x`, `y`. Avoid
   animating `width`/`height`/anything inside a `Layout`, which forces a
   relayout every frame.
3. **Every duration and easing reference goes through `Motion.qml`.**
   `scripts/lint-layers.sh` greps for bare `Animation { duration: <number>` /
   `easing.bezierCurve: [` outside `Commons/Motion.qml` and fails on a hit.
4. **`config.json`'s `motion.scale`** multiplies every duration
   (`0` = instant/off for accessibility or a slow machine, `1` = default,
   `1.5` = slow-mo for demos/screenshots). Implemented once, in
   `Motion.qml`'s duration getters — nothing downstream needs to know it
   exists.
5. **`config.json`'s `motion.overlay`** (`fade` | `zoom` | `fadeZoom`,
   default `fadeZoom`) is how every `MOverlay` / `MPopup` / `MDialog`
   enters and exits. Scrim always fades. The card uses
   `Motion.overlayOpacity(open)` / `Motion.overlayScale(open)` so Modules
   never branch on the string. Fade = opacity 0↔1; zoom = scale ~0.92↔1
   (open zooms in, close zooms out); fadeZoom = both. Durations/easings
   only via `Motion.mediumMs` with `easingEmphasizedDecelerate` (enter) and
   `easingEmphasizedAccelerate` (exit). When `motion.scale` is 0, motion is
   instant. Settings → Design owns the chips.

## Hyprland side

`stow/hypr/.config/hypr/modules/animations.lua` derives a matching bezier
set from the same numbers (`emphasized`, `emphasizedDecelerate`,
`emphasizedAccelerate`, `standard`) so window open/close/move animations
feel like the same motion system as the shell, not a second one bolted on.
This uses Hyprland 0.55+'s real Lua animation API — `hl.curve(name, {
type = "bezier", points = {{x0,y0},{x1,y1}} })` to define a curve from its
two inner control points, and `hl.animation({ leaf, enabled, speed,
bezier, style })` to apply one to an animation-tree leaf, where `speed` is
in deciseconds (1ds = 100ms):

```lua
-- modules/animations.lua (excerpt)
local tokens = require("modules.motion_tokens") -- hand-kept in sync with Motion.qml
local scale = config.value("motion.scale", 1.0)
local function speed(ms) return (ms * scale) / 100.0 end

for name, p in pairs(tokens.bezier) do
    hl.curve(name, { type = "bezier", points = { { p[1], p[2] }, { p[3], p[4] } } })
end

hl.animation({ leaf = "windowsIn", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasizedDecelerate", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasizedAccelerate", style = "popin 92%" })
hl.animation({ leaf = "fade", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasized" })
hl.animation({ leaf = "workspaces", enabled = true, speed = speed(tokens.durationLongMs), bezier = "emphasizedDecelerate", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = speed(tokens.durationShortMs), bezier = "standard" })
```

`popin 92%` is the same closed floor as `Motion.overlayScale(false)`.
`motion.scale <= 0` disables the `global` leaf instead of animating at
zero speed.

Overlay menus (control panel, bar popups) use `Motion.overlay*` and
`motion.scale` from Settings → Design. Hyprland window open/close and
awww wallpaper fades use the same tokens in `animations.lua` /
`theme-apply.sh`. Session lock enter uses `Motion.extraLongMs`.

`modules/motion_tokens.lua` is hand-kept in sync with the numeric
constants in `Commons/Motion.qml`'s source — a comment pointer in both
files rather than a build step, since the values change rarely and a
build step would be more complexity than the drift risk it prevents. This
whole file was executed against a mocked `hl` API during development
(134 calls, zero runtime errors) to catch structural mistakes before ever
touching a real compositor — see `docs/TROUBLESHOOTING.md`.
