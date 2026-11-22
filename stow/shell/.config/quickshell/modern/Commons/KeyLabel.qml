pragma Singleton

import Quickshell
import QtQuick

// A Qt key sequence ("Ctrl+Shift+S", "Left") in the words of the current
// language, for menus and tooltips. Letters and F-keys stay as written.
Singleton {
    id: root

    readonly property var _names: ({
        Ctrl: "keys.ctrl",
        Shift: "keys.shift",
        Alt: "keys.alt",
        Del: "keys.delete",
        Delete: "keys.delete",
        Space: "keys.space",
        Return: "keys.enter",
        Esc: "keys.escape",
        Escape: "keys.escape",
        Backspace: "keys.backspace",
        Left: "keys.left",
        Right: "keys.right",
        Up: "keys.up",
        Down: "keys.down",
        Home: "keys.home",
        End: "keys.end",
        PgUp: "keys.pageUp",
        PgDown: "keys.pageDown"
    })

    function of(sequence: string): string {
        const parts = String(sequence || "").split("+");
        return parts.map((part, i) => {
            if (part === "" && i === parts.length - 1)
                return "+";
            const key = root._names[part];
            return key ? I18n.t(key) : part;
        }).filter(p => p.length).join("+");
    }
}
