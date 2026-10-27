// What each connected display can actually do, so Settings > Displays
// only offers switches the panel supports. HDR and wide gamut come from
// the EDID (di-edid-decode, libdisplay-info); VRR from the kernel's
// immutable vrr_capable connector property (modetest, libdrm) — an EDID
// refresh range alone does not prove adaptive sync.
// Keyed by connector name as Hyprland reports it; unknown = show all.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var caps: ({})
    property int gen: 0

    function refresh() {
        probe.running = false;
        Qt.callLater(() => {
            probe.running = true;
        });
    }

    function capsFor(connector: string): var {
        void root.gen;
        const c = root.caps[String(connector || "")];
        return c || { known: false, hdr: true, wide: true, vrr: true };
    }

    function _parse(text: string): var {
        const out = {};
        const blocks = String(text || "").split("\n@@ ");
        for (let i = 0; i < blocks.length; i++) {
            const b = blocks[i].replace(/^@@ /, "");
            const nl = b.indexOf("\n");
            if (nl < 0)
                continue;
            const head = b.slice(0, nl).trim().split(" ");
            const body = b.slice(nl + 1);
            const name = head[0] || "";
            if (!name.length)
                continue;
            const edid = body.trim().length > 0;
            out[name] = {
                known: edid,
                hdr: !edid || /SMPTE ST2084|Hybrid Log-Gamma/.test(body),
                wide: !edid || /BT2020RGB|DCI-P3|Display P3/.test(body),
                vrr: head[1] !== "0"
            };
        }
        return out;
    }

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "vrr=$(modetest -c 2>/dev/null | awk '/^[0-9]+\\t[0-9]+\\t(connected|disconnected)/{c=$4} /vrr_capable:/{v=1} v&&/value:/{print c\"=\"$2; v=0}'); for e in /sys/class/drm/card*-*/edid; do d=$(di-edid-decode \"$e\" 2>/dev/null); [ -n \"$d\" ] || continue; c=${e%/edid}; c=${c##*/}; c=${c#card*-}; v=$(printf '%s\\n' \"$vrr\" | awk -F= -v c=\"$c\" '$1==c{print $2; exit}'); printf '@@ %s %s\\n%s\\n' \"$c\" \"${v:-?}\" \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.caps = root._parse(this.text);
                root.gen++;
            }
        }
    }
}
