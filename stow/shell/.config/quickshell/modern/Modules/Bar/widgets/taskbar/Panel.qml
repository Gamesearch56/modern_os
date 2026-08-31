import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root

    property var barScreen: null
    property int menuIndex: -1
    property string menuAddress: ""
    property bool menuBackground: false
    property real menuRowY: 0
    property real menuRowH: 0

    readonly property int count: Hypr.taskbarCount(root.barScreen)

    function workspaceLabel(id: int): string {
        const p = {};
        p.id = id;
        return I18n.t("bar.taskbarWorkspace", p);
    }

    function closeMenu() {
        root.menuIndex = -1;
        root.menuAddress = "";
        root.menuBackground = false;
    }

    function focusFirst() {
        for (let i = 0; i < col.children.length; i++) {
            const c = col.children[i];
            if (c && c.forceActiveFocus && c.titleValue !== undefined) {
                c.forceActiveFocus();
                return;
            }
        }
    }

    Component.onCompleted: Qt.callLater(root.focusFirst)

    BarPanelChrome {
        anchors.fill: parent
        titleKey: "bar.taskbar"

        MPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: col.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                visible: root.count > 0

                ColumnLayout {
                    id: col
                    width: flick.width
                    spacing: Tokens.spacing.sm

                    Repeater {
                        model: root.count

                        MListItem {
                            id: item
                            required property int index
                            readonly property var win: (Hypr.toplevelList || [])[index]
                            readonly property string address: String(item.win?.address || "")
                            readonly property int wsId: item.win?.workspace ? Number(item.win.workspace.id) : 0
                            readonly property string cls: item.win?.lastIpcObject?.class ?? "application-x-executable"
                            readonly property bool background: {
                                const ipc = item.win?.lastIpcObject;
                                return item.wsId < 0 || !!(ipc && (ipc.hidden === true || ipc.mapped === false));
                            }

                            Layout.fillWidth: true
                            iconName: item.cls
                            tintIcon: false
                            titleValue: item.win?.title || item.cls
                            subtitleValue: item.background ? I18n.t("bar.taskbarBackground") : (item.wsId > 0 ? root.workspaceLabel(item.wsId) : "")
                            selected: item.win?.activated === true || root.menuIndex === item.index
                            onClicked: {
                                root.closeMenu();
                                Hypr.activateWindow(item.address);
                                Popups.dismiss();
                                Taskbar.hide();
                            }
                            onRightClicked: {
                                if (root.menuIndex === item.index) {
                                    root.closeMenu();
                                    return;
                                }
                                const host = Window.window ? Window.window.contentItem : root;
                                const p = item.mapToItem(host, 0, 0);
                                root.menuRowY = p.y;
                                root.menuRowH = item.height;
                                root.menuAddress = item.address;
                                root.menuBackground = item.background;
                                root.menuIndex = item.index;
                            }

                            MIconButton {
                                close: true
                                iconName: "window-close-symbolic"
                                key: "bar.close"
                                size: Tokens.spacing.xl
                                iconSize: Tokens.icon.xs
                                onClicked: Hypr.closeWindow(item.address)
                            }
                        }
                    }
                }
            }

            MEmptyState {
                visible: root.count === 0
                anchors.fill: parent
                iconName: "focus-windows-symbolic"
                titleKey: "bar.taskbarEmpty"
                hintKey: "bar.taskbarEmptyHint"
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.menuIndex >= 0
        source: Qt.resolvedUrl("Menu.qml")
        onLoaded: {
            if (!item)
                return;
            item.menuAddress = Qt.binding(() => root.menuAddress);
            item.menuBackground = Qt.binding(() => root.menuBackground);
            item.menuRowY = Qt.binding(() => root.menuRowY);
            item.menuRowH = Qt.binding(() => root.menuRowH);
            item.closed.connect(root.closeMenu);
        }
    }
}
