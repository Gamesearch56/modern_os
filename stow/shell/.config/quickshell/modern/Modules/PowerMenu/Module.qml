import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    id: root

    IpcHandler {
        target: "powermenu"
        function toggle() { PowerMenu.toggle(); }
        function show() { PowerMenu.show(); }
        function hide() { PowerMenu.hide(); }
    }

    property string pending: ""

    LazyLoader {
        active: PowerMenu.open

        PanelWindow {
            visible: PowerMenu.open
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            Rectangle {
                anchors.fill: parent
                color: Colors.color.scrim
                opacity: 0.45
                MouseArea { anchors.fill: parent; onClicked: PowerMenu.hide() }
            }

            MCard {
                level: 4
                width: Tokens.spacing.xxl * 14
                height: Tokens.spacing.xxl * 8
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.lg

                    MText { key: "powerMenu.title"; styleName: "headlineSmall" }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing.lg

                        MButton { kind: "tonal"; key: "powerMenu.lock"; iconName: "system-lock-screen"; onClicked: { Session.lock(); PowerMenu.hide(); } }
                        MButton { kind: "tonal"; key: "powerMenu.logout"; iconName: "system-log-out"; onClicked: root._ask("logout") }
                        MButton { kind: "tonal"; key: "powerMenu.suspend"; iconName: "system-suspend"; onClicked: { Power.suspend(); PowerMenu.hide(); } }
                        MButton { kind: "filled"; key: "powerMenu.restart"; iconName: "system-reboot"; onClicked: root._ask("reboot") }
                        MButton { kind: "filled"; key: "powerMenu.poweroff"; iconName: "system-shutdown"; onClicked: root._ask("poweroff") }
                    }
                }
            }

            MDialog {
                anchors.fill: parent
                open: root.pending.length > 0
                titleKey: "powerMenu.confirmTitle"
                bodyKey: "powerMenu.confirmBody"
                bodyParams: ({ action: I18n.t("powerMenu." + (root.pending === "reboot" ? "restart" : root.pending)), seconds: 0 })
                confirmKey: "powerMenu." + (root.pending === "reboot" ? "restart" : (root.pending || "poweroff"))
                onConfirmed: {
                    if (root.pending === "logout") Power.logout();
                    else if (root.pending === "reboot") Power.reboot();
                    else if (root.pending === "poweroff") Power.poweroff();
                    root.pending = "";
                    PowerMenu.hide();
                }
                onCancelled: root.pending = ""
            }

            Shortcut { sequence: "Escape"; onActivated: { root.pending = ""; PowerMenu.hide(); } }
        }
    }

    function _ask(action: string) {
        root.pending = action;
    }
}
