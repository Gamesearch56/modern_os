// Splits a slot into pills. Each id is its own bubble unless it belongs
// to the wifi/bt cluster or the battery/control/power cluster.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"

Item {
    id: root

    property var ids: []
    property bool vertical: false
    property var barScreen: null

    readonly property var groups: {
        void root.ids;
        return root._split(root.ids);
    }

    implicitWidth: lay.implicitWidth
    implicitHeight: lay.implicitHeight

    function isBubble(id: string): bool {
        return id !== "network" && id !== "bluetooth"
            && id !== "battery" && id !== "settings" && id !== "power";
    }

    function _split(list: var): var {
        const ids = list || [];
        const out = [];
        let cur = [];
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i];
            if (root.isBubble(id)) {
                if (cur.length > 0) {
                    out.push(cur);
                    cur = [];
                }
                out.push([id]);
            } else {
                cur.push(id);
            }
        }
        if (cur.length > 0)
            out.push(cur);
        return out;
    }

    function _singleHit(group: var): bool {
        if (!group || group.length !== 1)
            return false;
        const id = group[0];
        return id !== "workspaces" && id !== "connectivity" && id !== "media";
    }

    function _empty(group: var): bool {
        if (!group || group.length === 0)
            return true;
        if (group.length !== 1)
            return false;
        if (group[0] === "media")
            return false;
        if (group[0] === "battery")
            return !Battery.hasBattery;
        return false;
    }

    GridLayout {
        id: lay
        columns: root.vertical ? 1 : 16
        rows: root.vertical ? 16 : 1
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Tokens.spacing.sm
        columnSpacing: Tokens.spacing.sm

        Repeater {
            model: root.groups
            delegate: BarIsland {
                id: island
                required property var modelData
                vertical: root.vertical
                empty: {
                    void Hypr.workspaces;
                    void Hypr.monitors;
                    void Hypr.toplevels;
                    void Hypr.focusedWorkspace;
                    void Media.hasPlayer;
                    void Media.playing;
                    void Media.trackTitle;
                    void Media.identity;
                    void Audio.playback;
                    void Battery.hasBattery;
                    void Battery.onBattery;
                    return root._empty(modelData);
                }
                singleHit: root._singleHit(modelData)

                Repeater {
                    model: island.modelData
                    WidgetLoader {
                        barScreen: root.barScreen
                    }
                }
            }
        }
    }
}
