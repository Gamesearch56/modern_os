// Design tokens as JSON for windows that run in their own qml6 process
// (the wallpaper provider's WebEngine). They cannot import Commons, so
// the shell hands them the live palette, sizes, type and motion as argv.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    function json(): string {
        const c = Colors.color;
        const label = Typography.style("bodyMedium");
        return JSON.stringify({
            color: {
                primary: String(c.primary),
                onSurface: String(c.onSurface),
                onSurfaceVariant: String(c.onSurfaceVariant),
                surface: String(c.surface),
                surfaceContainer: String(c.surfaceContainer),
                outlineVariant: String(c.outlineVariant),
                error: String(c.error)
            },
            spacing: {
                xs: Tokens.spacing.xs, sm: Tokens.spacing.sm, md: Tokens.spacing.md,
                lg: Tokens.spacing.lg, xl: Tokens.spacing.xl, xxl: Tokens.spacing.xxl
            },
            radius: { full: Tokens.radius.full },
            icon: { md: Tokens.icon.md },
            stroke: { hairline: Tokens.stroke.hairline, focus: Tokens.stroke.focus },
            interaction: { hover: Tokens.interaction.hover, press: Tokens.interaction.press },
            motion: { short: Motion.shortMs },
            font: {
                family: Typography.family.ui,
                pixelSize: label.pixelSize,
                weight: label.weight,
                letterSpacing: label.letterSpacing
            }
        });
    }

    // `keys` maps a name the window reads to a translation key.
    function strings(keys: var): string {
        const out = {};
        for (const name in keys)
            out[name] = I18n.t(keys[name]);
        return JSON.stringify(out);
    }
}
