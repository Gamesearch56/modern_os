// Separate Quickshell package for greetd. Cannot import the desktop
// shell's Commons/Widgets — those live in a different stow package
// and the greeter user has no $HOME view of them. Colors come from the
// shared session dir (docs/DECISIONS.md #14).
import Quickshell
import QtQuick

ShellRoot {
    id: root

    SessionChrome {
        id: sessionChrome
    }

    SessionUsers {
        id: sessionUsers
    }

    GreetdAuth {
        id: sessionAuth
    }

    // Leftmost (then topmost). Connector names are machine-specific.
    function isLeftmost(screen: var): bool {
        const screens = Quickshell.screens;
        if (!screen)
            return false;
        if (!screens || screens.length <= 1)
            return true;
        let best = null;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s)
                continue;
            if (!best || s.x < best.x || (s.x === best.x && s.y < best.y))
                best = s;
        }
        if (!best)
            return true;
        if (best === screen)
            return true;
        return !!(best.name && screen.name && best.name === screen.name);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: sessionChrome.color.surface || "#141218"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            SessionSurface {
                anchors.fill: parent
                chrome: sessionChrome
                auth: sessionAuth
                users: sessionUsers
                interactive: true
                autoFocus: root.isLeftmost(win.modelData)
            }
        }
    }
}
