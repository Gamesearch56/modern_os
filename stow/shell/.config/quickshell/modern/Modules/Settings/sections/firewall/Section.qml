import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

Item {
    id: root

    property var pending: null
    property string pendingToggle: ""

    implicitHeight: col.implicitHeight

    Component.onCompleted: Firewall.watching = true
    Component.onDestruction: Firewall.watching = false

    Connections {
        target: Store
        function onOpenChanged() {
            if (!Store.open)
                Firewall.refresh();
        }
        function onLastNameChanged() {
            if (String(Store.lastName) === "ufw")
                Firewall.refresh();
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Tokens.spacing.lg

        Status {
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.md
                MText {
                    key: "settings.firewall.enable"
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MIconButton {
                    iconName: "view-refresh"
                    key: "settings.refresh"
                    iconSize: Tokens.icon.sm
                    enabled: Firewall.present && !Firewall.running
                    onClicked: Firewall.refresh()
                }
                MSwitch {
                    checked: Firewall.active
                    enabled: Firewall.present && !Firewall.running && root.pendingToggle.length === 0
                    onToggled: (v) => {
                        if (Firewall.running || root.pendingToggle.length)
                            return;
                        root.pendingToggle = v ? "enable" : "disable";
                    }
                }
            }
        }

        MLinearProgress {
            visible: Firewall.running
            Layout.fillWidth: true
            indeterminate: true
        }
        MText {
            visible: Firewall.error.length > 0 && !Firewall.running
            value: Firewall.error
            styleName: "bodySmall"
            color: Colors.color.error
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        RulesTable {
            policy: "allow"
            rules: Firewall.allow
            onAddClicked: {
                addDlg.policy = "allow";
                addDlg.open = true;
            }
            onRemoveClicked: (r) => root.pending = r
        }

        RulesTable {
            policy: "deny"
            rules: Firewall.deny
            onAddClicked: {
                addDlg.policy = "deny";
                addDlg.open = true;
            }
            onRemoveClicked: (r) => root.pending = r
        }
    }

    RuleDialog {
        id: addDlg
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pending !== null
        titleKey: "settings.firewall.deleteTitle"
        bodyKey: "settings.firewall.deleteBody"
        bodyParams: ({
            to: root.pending ? String(root.pending.to || "") : "",
            from: root.pending ? String(root.pending.from || "") : ""
        })
        confirmKey: "settings.firewall.delete"
        cancelKey: "settings.cancel"
        destructive: true
        onConfirmed: {
            if (root.pending)
                Firewall.remove(root.pending.number);
            root.pending = null;
        }
        onCancelled: root.pending = null
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pendingToggle === "enable"
        titleKey: "settings.firewall.enableTitle"
        bodyKey: "settings.firewall.enableBody"
        confirmKey: "settings.firewall.enable"
        cancelKey: "settings.cancel"
        onConfirmed: {
            Firewall.setEnabled(true);
            root.pendingToggle = "";
        }
        onCancelled: root.pendingToggle = ""
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pendingToggle === "disable"
        titleKey: "settings.firewall.disableTitle"
        bodyKey: "settings.firewall.disableBody"
        confirmKey: "settings.firewall.disable"
        cancelKey: "settings.cancel"
        destructive: true
        onConfirmed: {
            Firewall.setEnabled(false);
            root.pendingToggle = "";
        }
        onCancelled: root.pendingToggle = ""
    }
}
