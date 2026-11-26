// Progress for Settings → Update from the `@@progress <stage> [n]`
// markers modern-update.sh and update-apply.sh print. pacman's text is
// translated and its (n/m) counter restarts per phase and per run, so
// only the stages are trusted. Never moves backwards; 1 is set by the
// caller when the update has exited successfully.
import QtQuick

QtObject {
    id: root

    property real value: -1
    property string stage: ""
    property int _pkgs: 0
    property int _lines: 0

    // Each stage owns a slice of the bar.
    readonly property var _slices: ({
            desktop: [0.02, 0.3],
            system: [0.3, 0.32],
            snapshot: [0.32, 0.38],
            pacman: [0.38, 0.85],
            hooks: [0.85, 0.95],
            finish: [0.95, 0.99]
        })

    function reset() {
        root.value = -1;
        root.stage = "";
        root._pkgs = 0;
        root._lines = 0;
    }

    // Returns true for a marker line, which stays out of the log.
    function feed(line: string): bool {
        const m = line.match(/^@@progress\s+(\w+)(?:\s+(\d+))?/);
        if (m) {
            root._enter(m[1]);
            if (m[1] === "system")
                root._pkgs = Number(m[2] || 0);
            return true;
        }
        root._lines += 1;
        const phase = line.match(/Phase (\d+)\/(\d+)/);
        const hook = line.match(/^\((\d+)\/(\d+)\)/);
        if (root.stage === "desktop" && phase)
            root._at(Number(phase[1]) / Number(phase[2]));
        else if ((root.stage === "pacman" || root.stage === "hooks") && hook) {
            root._enter("hooks");
            root._at(Number(hook[1]) / Number(hook[2]));
        } else if (root.stage === "pacman")
            // Download, five checks, then one line per package.
            root._at(Math.min(1, root._lines / (2 * Math.max(1, root._pkgs) + 8)));
        return false;
    }

    function _enter(stage: string) {
        if (!root._slices[stage] || stage === root.stage)
            return;
        root.stage = stage;
        root._lines = 0;
        root._at(0);
    }

    function _at(fraction: real) {
        const s = root._slices[root.stage];
        if (!s)
            return;
        root.value = Math.max(root.value, s[0] + (s[1] - s[0]) * fraction);
    }
}
