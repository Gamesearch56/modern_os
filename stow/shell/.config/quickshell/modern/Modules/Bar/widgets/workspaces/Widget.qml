import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Row {
    id: root
    property var barScreen: null
    spacing: Tokens.spacing.xxs

    readonly property var ids: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        void Hypr.toplevels;
        return Hypr.workspaceIdsFor(root.barScreen);
    }

    Repeater {
        model: root.ids.length

        Item {
            id: chip
            required property int index
            readonly property int wsId: root.ids[index] || 0
            readonly property var ws: Hypr.workspaceById(chip.wsId)
            readonly property bool current: Hypr.isActiveOnScreen(root.barScreen, chip.wsId)
            readonly property bool urgent: !!(chip.ws && chip.ws.urgent)

            width: Math.max(Tokens.spacing.xl, label.implicitWidth + Tokens.spacing.sm * 2)
            height: Tokens.spacing.xl

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.full
                color: {
                    if (chip.current)
                        return Chrome.navSelected.bg;
                    if (chip.urgent)
                        return Colors.color.error;
                    return Chrome.navIdle.bg;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.full
                color: Colors.color.primary
                opacity: chip.current ? 0 : Chrome.stateLayer(hit.containsMouse, false)
            }

            MText {
                id: label
                anchors.centerIn: parent
                value: String(chip.wsId)
                styleName: "labelSmall"
                color: {
                    if (chip.current)
                        return Chrome.navSelected.fg;
                    if (chip.urgent)
                        return Colors.color.onError;
                    return Chrome.navIdle.fg;
                }
            }

            MouseArea {
                id: hit
                anchors.fill: parent
                z: 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(chip.wsId)
            }
        }
    }
}
