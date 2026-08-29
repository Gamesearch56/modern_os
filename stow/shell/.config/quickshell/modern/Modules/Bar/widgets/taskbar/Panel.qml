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

    readonly property int count: Hypr.taskbarCount(root.barScreen)

    function workspaceLabel(id: int): string {
        const p = {};
        p.id = id;
        return I18n.t("bar.taskbarWorkspace", p);
    }

    function closeMenu() {
        root.menuIndex = -1;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MText {
                key: "bar.taskbar"
                styleName: "headlineMedium"
                Layout.fillWidth: true
            }
            MIconButton {
                close: true
                iconName: "window-close"
                key: "bar.close"
                onClicked: Popups.dismiss()
            }
        }

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
                    spacing: Tokens.spacing.xxs

                    Repeater {
                        model: Hypr.toplevels

                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool onScreen: Hypr.windowOnScreen(modelData, root.barScreen)
                            readonly property int wsId: modelData.workspace ? Number(modelData.workspace.id) : 0
                            readonly property string cls: modelData.lastIpcObject?.class ?? "application-x-executable"

                            visible: row.onScreen
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? item.implicitHeight : 0

                            MListItem {
                                id: item
                                width: row.width
                                iconName: row.cls
                                tintIcon: false
                                titleValue: modelData.title || row.cls
                                subtitleValue: row.wsId > 0 ? root.workspaceLabel(row.wsId) : ""
                                selected: modelData.activated === true
                                onClicked: {
                                    root.closeMenu();
                                    Hypr.focusWindow(modelData.address);
                                    Popups.dismiss();
                                }
                                onRightClicked: {
                                    const next = root.menuIndex !== row.index;
                                    root.closeMenu();
                                    if (next)
                                        root.menuIndex = row.index;
                                }
                            }

                            BarPopup {
                                id: menu
                                open: false
                                grab: true
                                elevation: 0
                                anchorItem: item
                                implicitWidth: Tokens.spacing.xxl * 8
                                implicitHeight: Tokens.spacing.xxl * 9
                                onOpenChanged: {
                                    if (!open && root.menuIndex === row.index)
                                        root.menuIndex = -1;
                                }

                                Connections {
                                    target: root
                                    function onMenuIndexChanged() {
                                        menu.open = root.menuIndex === row.index;
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    MListItem {
                                        Layout.fillWidth: true
                                        iconName: "focus-windows-symbolic"
                                        titleKey: "bar.taskbarShow"
                                        onClicked: {
                                            root.closeMenu();
                                            Hypr.focusWindow(modelData.address);
                                            Popups.dismiss();
                                        }
                                    }
                                    MListItem {
                                        Layout.fillWidth: true
                                        iconName: "view-restore-symbolic"
                                        titleKey: "bar.taskbarFloat"
                                        onClicked: {
                                            root.closeMenu();
                                            Hypr.toggleFloating(modelData.address);
                                        }
                                    }
                                    MListItem {
                                        Layout.fillWidth: true
                                        iconName: "view-fullscreen-symbolic"
                                        titleKey: "bar.taskbarFullscreen"
                                        onClicked: {
                                            root.closeMenu();
                                            Hypr.toggleFullscreen(modelData.address);
                                        }
                                    }
                                    MDivider {
                                        Layout.fillWidth: true
                                        Layout.topMargin: Tokens.spacing.xs
                                        Layout.bottomMargin: Tokens.spacing.xs
                                    }
                                    MListItem {
                                        Layout.fillWidth: true
                                        iconName: "window-close-symbolic"
                                        titleKey: "bar.close"
                                        destructive: true
                                        onClicked: {
                                            root.closeMenu();
                                            Hypr.closeWindow(modelData.address);
                                        }
                                    }
                                }
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
}
