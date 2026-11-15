// One display in ProfileList. Ctrl+Left/Right is the keyboard path for
// what dragging does with the pointer.
import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    property var monitor: null
    property bool active: false
    property bool dragging: false
    property bool dropTarget: false
    property bool dropping: false

    signal activated()
    signal nudged(int step)

    readonly property string portName: String(root.monitor?.name || "")
    implicitHeight: Tokens.icon.lg + Tokens.spacing.xxl * 3 + Tokens.spacing.lg
    level: root.dragging ? 4 : (root.active ? 3 : 1)
    // While a drop slot is shown only the target's border marks the spot.
    highlighted: root.dragging || (!root.dropping && (root.active || activeFocus))
    borderColor: root.dropTarget ? Colors.color.primary : "transparent"
    borderWidth: root.dropTarget ? Tokens.stroke.focus : 0
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.monitor?.description || root.monitor?.name || ""
    Accessible.onPressAction: root.activated()
    Keys.onPressed: (event) => {
        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            root.nudged(event.key === Qt.Key_Left ? -1 : 1);
            event.accepted = true;
            return;
        }
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        root.activated();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.xs

        MText {
            value: root.monitor?.description || root.monitor?.name || ""
            styleName: "titleSmall"
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
        }
        MIcon {
            name: "video-display"
            size: Tokens.icon.lg
            color: root.active ? Colors.color.primary : Colors.color.onSurfaceVariant
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
        }
        MText {
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            // The menu writes monitors.profiles[].mode. The live Hyprland
            // rate lags that write, so the card was stuck on the old Hz.
            value: {
                void Hypr.monitorGen;
                void Config.monitors;
                const desc = String(root.monitor?.description || "");
                const saved = (Config.monitors?.profiles || {})[desc] || ({});
                const parsed = Hypr.parseMode(String(saved.mode || ""));
                const w = parsed ? parsed.w : Number(root.monitor?.width || 0);
                const h = parsed ? parsed.h : Number(root.monitor?.height || 0);
                const hz = parsed ? Math.round(parsed.hz) : Hypr.hzFor(root.monitor);
                const mode = w && h ? (w + " × " + h + (hz > 0 ? (" · " + hz + " Hz") : "")) : "";
                if (mode.length && root.portName.length)
                    return mode + " · " + root.portName;
                return mode.length ? mode : root.portName;
            }
        }
    }
}
