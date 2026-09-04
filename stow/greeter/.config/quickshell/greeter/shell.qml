// Separate Quickshell package for greetd. Cannot import the desktop
// shell's Commons/Widgets — those live in a different stow package
// and the greeter user has no $HOME view of them. Colors come from the
// shared session dir (docs/DECISIONS.md #14).
import Quickshell
import QtQuick

ShellRoot {
    id: root

    // Leftmost output (then topmost). Names like DP-1 are machine-specific.
    readonly property var loginScreen: {
        void Quickshell.screens;
        const raw = Quickshell.screens?.values ?? Quickshell.screens ?? [];
        let best = null;
        for (let i = 0; i < raw.length; i++) {
            const s = raw[i];
            if (!s)
                continue;
            if (!best
                || (s.x ?? 0) < (best.x ?? 0)
                || ((s.x ?? 0) === (best.x ?? 0) && (s.y ?? 0) < (best.y ?? 0)))
                best = s;
        }
        return best;
    }

    SessionChrome {
        id: chrome
    }

    GreetdAuth {
        id: auth
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: {
                const p = root.loginScreen;
                return !!(p && modelData && p.name === modelData.name);
            }

            SessionSurface {
                anchors.fill: parent
                chrome: chrome
                auth: auth
                interactive: {
                    const p = root.loginScreen;
                    return !!(p && modelData && p.name === modelData.name);
                }
            }
        }
    }
}
