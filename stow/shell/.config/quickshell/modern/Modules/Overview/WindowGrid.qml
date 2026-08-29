import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int currentIndex: 0
    readonly property int columns: Math.max(1, Math.floor(Math.max(width, 1) / (Tokens.spacing.xxl * 8)))
    readonly property int count: {
        const t = Hypr.toplevels;
        if (!t)
            return 0;
        if (t.values && t.values.length !== undefined)
            return t.values.length;
        if (t.count !== undefined)
            return t.count;
        return 0;
    }

    function moveBy(delta: int) {
        const n = root.count;
        if (n <= 0)
            return;
        root.currentIndex = ((root.currentIndex + delta) % n + n) % n;
        root._ensureVisible();
    }

    function activate() {
        const win = tiles.itemAt(root.currentIndex);
        if (!win || !win.address)
            return;
        Hypr.focusWindow(win.address);
        Overview.hide();
    }

    function _ensureVisible() {
        const tile = tiles.itemAt(root.currentIndex);
        if (!tile || flick.height <= 0)
            return;
        const top = tile.y;
        const bottom = tile.y + tile.height;
        if (top < flick.contentY)
            flick.contentY = Math.max(0, top);
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = Math.max(0, bottom - flick.height);
    }

    onCountChanged: {
        if (root.currentIndex >= root.count)
            root.currentIndex = Math.max(0, root.count - 1);
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: layout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: layout
            width: flick.width
            columns: root.columns
            columnSpacing: Tokens.spacing.sm
            rowSpacing: Tokens.spacing.sm

            Repeater {
                id: tiles
                model: Hypr.toplevels
                delegate: MCard {
                    required property var modelData
                    required property int index
                    readonly property string address: modelData.address || ""
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: (layout.width - layout.columnSpacing * Math.max(0, root.columns - 1)) / root.columns
                    Layout.preferredHeight: Tokens.spacing.xxl * 4
                    level: (modelData.activated || root.currentIndex === index) ? 3 : 1
                    padding: Tokens.spacing.sm
                    highlighted: root.currentIndex === index

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.xs

                        IconImage {
                            Layout.preferredWidth: Tokens.spacing.xl
                            Layout.preferredHeight: Tokens.spacing.xl
                            source: Quickshell.iconPath(modelData.lastIpcObject?.class ?? "application-x-executable", true)
                            asynchronous: true
                        }

                        MText {
                            value: modelData.title || ""
                            styleName: "labelLarge"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.currentIndex = index
                        onClicked: {
                            root.currentIndex = index;
                            Hypr.focusWindow(modelData.address);
                            Overview.hide();
                        }
                    }
                }
            }
        }
    }
}
