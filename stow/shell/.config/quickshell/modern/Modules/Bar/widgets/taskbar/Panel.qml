import QtQuick
import QtQuick.Layouts
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

    BarPanelChrome {
        anchors.fill: parent
        titleKey: "bar.taskbar"

        MPane {
            Layout.fillWidth: true
            Layout.fillHeight: true

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
                        model: Hypr.toplevelList

                        MListItem {
                            id: item
                            required property var modelData
                            required property int index
                            readonly property string address: String(modelData.address || "")
                            readonly property int wsId: modelData.workspace ? Number(modelData.workspace.id) : 0
                            readonly property string cls: modelData.lastIpcObject?.class ?? "application-x-executable"
                            readonly property bool background: {
                                const ipc = modelData.lastIpcObject;
                                return item.wsId < 0 || !!(ipc && (ipc.hidden === true || ipc.mapped === false));
                            }

                            Layout.fillWidth: true
                            iconName: item.cls
                            tintIcon: false
                            titleValue: modelData.title || item.cls
                            subtitleValue: item.background ? I18n.t("bar.taskbarBackground") : (item.wsId > 0 ? root.workspaceLabel(item.wsId) : "")
                            selected: modelData.activated === true || root.menuIndex === item.index
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
                                const p = item.mapToItem(root, 0, 0);
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

    Menu {
        anchors.fill: parent
        visible: root.menuIndex >= 0
        menuAddress: root.menuAddress
        menuBackground: root.menuBackground
        menuRowY: root.menuRowY
        menuRowH: root.menuRowH
        onClosed: root.closeMenu()
    }
}
