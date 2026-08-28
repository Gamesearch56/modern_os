// Reactive view of ~/.config/modern/tokens.json — the color half of
// the two-flow contract (docs/ARCHITECTURE.md). Matugen writes that
// file; this singleton never generates colors itself. Fallback values
// are the MD3 dark baseline so the shell still paints before the first
// theme-apply.sh run, rather than rendering unstyled.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // MD3 dark baseline (source #6750A4). Used until tokens.json loads.
    readonly property var _fallback: ({
        primary: "#D0BCFF",
        onPrimary: "#381E72",
        primaryContainer: "#4F378B",
        onPrimaryContainer: "#EADDFF",
        secondary: "#CCC2DC",
        onSecondary: "#332D41",
        secondaryContainer: "#4A4458",
        onSecondaryContainer: "#E8DEF8",
        tertiary: "#EFB8C8",
        onTertiary: "#492532",
        tertiaryContainer: "#633B48",
        onTertiaryContainer: "#FFD8E4",
        error: "#F2B8B5",
        onError: "#601410",
        errorContainer: "#8C1D18",
        onErrorContainer: "#F9DEDC",
        background: "#141218",
        onBackground: "#E6E0E9",
        surface: "#141218",
        onSurface: "#E6E0E9",
        surfaceVariant: "#49454F",
        onSurfaceVariant: "#CAC4D0",
        surfaceDim: "#141218",
        surfaceBright: "#3B383E",
        surfaceContainerLowest: "#0F0D13",
        surfaceContainerLow: "#1D1B20",
        surfaceContainer: "#211F26",
        surfaceContainerHigh: "#2B2930",
        surfaceContainerHighest: "#36343B",
        outline: "#938F99",
        outlineVariant: "#49454F",
        inverseSurface: "#E6E0E9",
        inverseOnSurface: "#322F35",
        inversePrimary: "#6750A4",
        shadow: "#000000",
        scrim: "#000000"
    })

    property var color: root._fallback
    property string mode: "dark"
    property string sourceColor: "#6750A4"

    FileView {
        id: file
        path: `${root.home}/.config/modern/tokens.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.mode)
                    root.mode = data.mode;
                if (data.sourceColor)
                    root.sourceColor = data.sourceColor;
                if (data.color)
                    root.color = data.color;
            } catch (e) {
                Logger.error("Colors", "tokens.json parse failed, keeping fallback: " + e);
            }
        }
        onLoadFailed: {
            root.color = root._fallback;
            Logger.warn("Colors", "tokens.json missing — using MD3 dark baseline");
        }
    }
}
