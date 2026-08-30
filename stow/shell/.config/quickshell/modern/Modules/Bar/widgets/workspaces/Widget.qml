import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    property var barScreen: null
    implicitWidth: row.implicitWidth + root._inset * 2
    implicitHeight: Config.bar.height

    readonly property real _inset: Tokens.spacing.xs
    readonly property real _chip: Config.bar.height - root._inset * 2

    readonly property var ids: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        void Hypr.toplevels;
        return Hypr.workspaceIdsFor(root.barScreen);
    }

    readonly property int activeId: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        const range = Hypr.reservedRange(root.barScreen);
        if (!range)
            return 0;
        for (let id = range.from; id <= range.to; id++) {
            if (Hypr.isActiveOnScreen(root.barScreen, id))
                return id;
        }
        return 0;
    }

    // First unused id after the active one in this monitor's range
    // (1-5 left, 6-10 next). Skip workspaces already on the strip.
    readonly property int nextId: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        void Hypr.toplevels;
        const range = Hypr.reservedRange(root.barScreen);
        if (!range || root.activeId <= 0)
            return 0;
        const taken = ({});
        const shown = root.ids || [];
        for (let i = 0; i < shown.length; i++)
            taken[Number(shown[i])] = true;
        for (let id = root.activeId + 1; id <= range.to; id++) {
            if (!taken[id])
                return id;
        }
        return 0;
    }

    readonly property bool canAdd: {
        void Hypr.toplevelList;
        void Hypr.workspaces;
        void Hypr.focusedWorkspace;
        return root.nextId > 0 && root.activeId > 0 && Hypr._workspaceHasWindows(root.activeId);
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        Row {
            anchors.verticalCenter: parent.verticalCenter
            height: root._chip
            spacing: Tokens.spacing.xs

            Repeater {
                model: root.ids.length

                Item {
                    id: chip
                    required property int index
                    readonly property int wsId: root.ids[index] || 0
                    readonly property var ws: Hypr.workspaceById(chip.wsId)
                    readonly property bool current: Hypr.isActiveOnScreen(root.barScreen, chip.wsId)
                    readonly property bool urgent: !!(chip.ws && chip.ws.urgent)

                    width: root._chip
                    height: root._chip

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

        Item {
            visible: root.canAdd
            width: Tokens.spacing.xs
            height: 1
        }

        MIconButton {
            tabFocus: false
            visible: root.canAdd
            anchors.verticalCenter: parent.verticalCenter
            iconName: "list-add-symbolic"
            key: "bar.workspaceAdd"
            size: Tokens.spacing.xl
            iconSize: Tokens.icon.sm - Tokens.spacing.xxs
            checked: false
            onClicked: Hypr.focusWorkspace(root.nextId)
        }

        Item {
            visible: root.canAdd
            width: Tokens.spacing.xs
            height: 1
        }
    }
}
