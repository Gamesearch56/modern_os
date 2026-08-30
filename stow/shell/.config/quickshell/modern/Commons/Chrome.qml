// Shared filled / tonal / nav-selected role maps so Widgets never
// disagree on which MD3 pair a chrome variant uses.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var filled: ({
        bg: Colors.color.primary,
        fg: Colors.color.onPrimary
    })

    readonly property var tonal: ({
        bg: Colors.color.primaryContainer,
        fg: Colors.color.onPrimaryContainer
    })

    readonly property var navSelected: ({
        bg: Colors.color.primary,
        fg: Colors.color.onPrimary
    })

    readonly property var navIdle: ({
        bg: "transparent",
        fg: Colors.color.onSurface
    })

    function stateLayer(hover: bool, press: bool): real {
        if (press)
            return Tokens.interaction.press;
        if (hover)
            return Tokens.interaction.hover;
        return 0;
    }
}
