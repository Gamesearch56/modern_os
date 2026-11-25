import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    property var barScreen: null
    implicitWidth: BarLayout.vertical ? BarLayout.height : (root._content + root._inset * 2)
    implicitHeight: BarLayout.vertical ? (root._content + root._inset * 2) : BarLayout.height
    width: implicitWidth
    height: implicitHeight
    clip: true

    readonly property real _inset: Tokens.spacing.xs
    readonly property real _chip: BarLayout.height - root._inset * 2
    readonly property real _addSize: Tokens.spacing.xl
    readonly property int _n: (root.ids || []).length
    readonly property real _content: {
        const n = root._n;
        const add = root.canAdd ? 1 : 0;
        if (n + add <= 0)
            return 0;
        return n * root._chip + (root.canAdd ? root._addSize : 0)
            + Math.max(0, n + add - 1) * Tokens.spacing.xs;
    }

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
        if (!range) {
            const shown = root.ids || [];
            for (let i = 0; i < shown.length; i++) {
                const id = Number(shown[i]);
                if (Hypr.isActiveOnScreen(root.barScreen, id))
                    return id;
            }
            return 0;
        }
        for (let id = range.from; id <= range.to; id++) {
            if (Hypr.isActiveOnScreen(root.barScreen, id))
                return id;
        }
        return 0;
    }

    // Fixed: first unused id after the active one in this monitor's
    // five-slot range. Dynamic: first free global id (opens on the
    // monitor under the cursor).
    readonly property int nextId: {
        void Hypr.workspaces;
        void Hypr.monitors;
        void Hypr.focusedWorkspace;
        void Hypr.toplevels;
        void Config.monitors;
        const mode = Config.monitors?.workspaceMode || "dynamic";
        if (mode !== "fixed")
            return Hypr.nextFreeWorkspaceId();
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
        void Config.monitors;
        if ((Config.monitors?.workspaceMode || "dynamic") !== "fixed")
            return true;
        return root.nextId > 0 && root.activeId > 0 && Hypr._workspaceHasWindows(root.activeId);
    }

    Grid {
        id: row
        anchors.left: BarLayout.vertical ? undefined : parent.left
        anchors.leftMargin: BarLayout.vertical ? 0 : root._inset
        anchors.verticalCenter: BarLayout.vertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: BarLayout.vertical ? parent.horizontalCenter : undefined
        anchors.top: BarLayout.vertical ? parent.top : undefined
        anchors.topMargin: BarLayout.vertical ? root._inset : 0
        columns: BarLayout.vertical ? 1 : 32
        flow: BarLayout.vertical ? Grid.TopToBottom : Grid.LeftToRight
        spacing: Tokens.spacing.xs
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

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
                        return Colors.color.surfaceContainerHighest;
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
                    anchors.fill: parent
                    z: 1
                    value: String(chip.wsId)
                    styleName: "labelSmall"
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
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

        Repeater {
            model: root.canAdd ? 1 : 0
            MIconButton {
                tabFocus: false
                iconName: "list-add-symbolic"
                key: "bar.workspaceAdd"
                size: root._addSize
                iconSize: Tokens.icon.sm - Tokens.spacing.xxs
                checked: false
                onClicked: {
                    if (root.nextId > 0)
                        Hypr.focusWorkspace(root.nextId);
                }
            }
        }
    }
}
