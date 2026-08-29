// Live MD3 palette from tokens.json. Wallpaper / theme-apply rewrite
// that file; FileView picks it up without restarting Quickshell.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property string mode: "dark"
    property string sourceColor: "#8020e6"
    property var color: ({
        primary: "#74d7ca",
        onPrimary: "#003732",
        primaryContainer: "#005049",
        onPrimaryContainer: "#91f4e6",
        secondary: "#ecb8ce",
        onSecondary: "#482536",
        secondaryContainer: "#613b4d",
        onSecondaryContainer: "#ffd8e7",
        tertiary: "#e7b7e8",
        onTertiary: "#46234a",
        tertiaryContainer: "#5e3962",
        onTertiaryContainer: "#ffd5ff",
        error: "#ffb4ab",
        onError: "#690005",
        errorContainer: "#93000a",
        onErrorContainer: "#ffdad6",
        background: "#171118",
        onBackground: "#ebdfe9",
        surface: "#171118",
        onSurface: "#ebdfe9",
        surfaceVariant: "#4e4350",
        onSurfaceVariant: "#d2c2d2",
        surfaceDim: "#171118",
        surfaceBright: "#3e373f",
        surfaceContainerLowest: "#120c13",
        surfaceContainerLow: "#201a21",
        surfaceContainer: "#241d25",
        surfaceContainerHigh: "#2f282f",
        surfaceContainerHighest: "#3a323a",
        outline: "#9b8c9b",
        outlineVariant: "#4e4350",
        inverseSurface: "#ebdfe9",
        inverseOnSurface: "#352e36",
        inversePrimary: "#006a61",
        shadow: "#000000",
        scrim: "#000000"
    })

    FileView {
        path: root.home + "/.config/modern/tokens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._apply(text())
    }

    function _apply(raw: string) {
        try {
            const j = JSON.parse(raw);
            if (j.mode)
                root.mode = String(j.mode);
            if (j.sourceColor)
                root.sourceColor = String(j.sourceColor);
            if (j.color && typeof j.color === "object")
                root.color = j.color;
        } catch (e) {
        }
    }
}
