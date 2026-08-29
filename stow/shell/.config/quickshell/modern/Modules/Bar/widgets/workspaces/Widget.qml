import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Row {
    id: root
    property var barScreen: null
    spacing: Tokens.spacing.sm

    readonly property var ids: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        void Hypr.toplevels;
        return Hypr.workspaceIdsFor(root.barScreen);
    }

    // Next id in this monitor's assigned range (1-5 left, 6-10 next),
    // not the next globally empty workspace.
    readonly property int nextId: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        const range = Hypr.reservedRange(root.barScreen);
        if (!range)
            return 0;
        let active = 0;
        for (let id = range.from; id <= range.to; id++) {
            if (Hypr.isActiveOnScreen(root.barScreen, id)) {
                active = id;
                break;
            }
        }
        const next = active + 1;
        if (next >= range.from && next <= range.to)
            return next;
        return 0;
    }

    Row {
        spacing: Tokens.spacing.xxs

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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton)
                            Hypr.closeWorkspace(chip.wsId);
                        else
                            Hypr.focusWorkspace(chip.wsId);
                    }
                }
            }
        }
    }

    MIconButton {
        visible: root.nextId > 0
        anchors.verticalCenter: parent.verticalCenter
        iconName: "list-add-symbolic"
        key: "bar.workspaceAdd"
        size: Tokens.spacing.lg
        iconSize: Tokens.icon.xs
        onClicked: Hypr.focusWorkspace(root.nextId)
    }
}
