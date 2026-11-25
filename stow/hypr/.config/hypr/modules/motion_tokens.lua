-- Numeric motion tokens, kept in sync BY HAND with
-- stow/shell/.config/quickshell/modern/Commons/Motion.qml (see
-- docs/MOTION.md — a build step was judged more complexity than the
-- drift risk, since these values change rarely). If you change one side,
-- change the other in the same commit.
--
-- durationMs values here match Motion.qml's Duration* properties.
-- Hyprland's hl.animation() "speed" is measured in ds (1ds = 100ms), so
-- modules/animations.lua divides these by 100.

return {
    durationShortMs = 100,
    durationMediumMs = 250,
    durationLongMs = 400,
    durationExtraLongMs = 600,

    -- control points for the two inner handles of each cubic bezier,
    -- matching Motion.qml's easing* arrays exactly.
    bezier = {
        emphasized = { 0.2, 0.0, 0.0, 1.0 },
        emphasizedDecelerate = { 0.05, 0.7, 0.1, 1.0 },
        emphasizedAccelerate = { 0.3, 0.0, 0.8, 0.15 },
        standard = { 0.2, 0.0, 0.0, 1.0 },
    },
}
