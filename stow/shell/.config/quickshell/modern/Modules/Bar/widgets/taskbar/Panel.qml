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
    property string menuKind: "window"
    property var menuEntry: null
    property real menuRowY: 0
    property real menuRowH: 0

    readonly property int count: Taskbar.count

    function workspaceLabel(id: int): string {
        const p = {};
        p.id = id;
        return I18n.t("bar.taskbarWorkspace", p);
    }

    function closeMenu() {
        root.menuIndex = -1;
        root.menuAddress = "";
        root.menuBackground = false;
        root.menuKind = "window";
        root.menuEntry = null;
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
                            readonly property var entry: (Taskbar.entries || [])[index]
                            readonly property string address: String(item.entry?.address || "")
                            readonly property int wsId: Number(item.entry?.wsId || 0)
                            readonly property string cls: String(item.entry?.cls || "application-x-executable")
                            readonly property bool background: !!(item.entry?.background)
                            readonly property bool headless: item.entry?.kind === "tray" || item.entry?.kind === "process"
                            readonly property bool tray: item.entry?.kind === "tray"

                            Layout.fillWidth: true
                            iconName: item.tray ? "" : String(item.entry?.icon || item.cls)
                            imageSource: item.tray ? String(item.entry?.iconUrl || "") : ""
                            tintIcon: false
                            preferSymbolic: false
                            titleValue: String(item.entry?.title || item.cls)
                            subtitleValue: item.background ? I18n.t("bar.taskbarBackground") : (item.wsId > 0 ? root.workspaceLabel(item.wsId) : "")
                            selected: !!(item.entry?.activated) || root.menuIndex === item.index
                            onClicked: {
                                root.closeMenu();
                                Taskbar.activate(item.entry);
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
                                root.menuKind = item.headless ? (item.tray ? "tray" : "process") : "window";
                                root.menuEntry = item.entry;
                                root.menuIndex = item.index;
                            }

                            MIconButton {
                                close: true
                                visible: !item.headless
                                iconName: "window-close-symbolic"
                                key: "bar.close"
                                size: Tokens.spacing.xl
                                iconSize: Tokens.icon.xs
                                onClicked: Taskbar.close(item.entry)
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
            item.menuKind = Qt.binding(() => root.menuKind);
            item.menuEntry = Qt.binding(() => root.menuEntry);
            item.menuRowY = Qt.binding(() => root.menuRowY);
            item.menuRowH = Qt.binding(() => root.menuRowH);
            item.closed.connect(root.closeMenu);
        }
    }
}
