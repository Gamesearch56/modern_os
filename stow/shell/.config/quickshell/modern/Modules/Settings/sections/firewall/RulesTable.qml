import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root

    property string policy: "allow"
    property var rules: []

    signal addClicked()
    signal removeClicked(var rule)

    readonly property bool _busy: Firewall.running || !Firewall.present
    readonly property real fromWidth: Tokens.spacing.xxl * 7
    readonly property real actionWidth: Tokens.spacing.xxl * 2

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: root.policy === "deny" ? "settings.firewall.deny" : "settings.firewall.allow"
            styleName: "titleSmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            visible: root.rules.length > 0
            value: String(root.rules.length)
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MButton {
            kind: "filled"
            key: "settings.firewall.add"
            enabled: !root._busy
            onClicked: root.addClicked()
        }
    }

    RowLayout {
        visible: root.rules.length > 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.firewall.port"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            key: "settings.firewall.colFrom"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
            Layout.preferredWidth: root.fromWidth
            Layout.maximumWidth: root.fromWidth
        }
        Item {
            Layout.preferredWidth: root.actionWidth
            Layout.maximumWidth: root.actionWidth
        }
    }
    MDivider {
        visible: root.rules.length > 0
        Layout.fillWidth: true
    }

    Repeater {
        model: root.rules.length
        RuleRow {
            required property int index
            rule: root.rules[index]
            busy: root._busy
            onRemoveClicked: (r) => root.removeClicked(r)
        }
    }

    MEmptyState {
        visible: root.rules.length === 0 && !Firewall.running
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "preferences-security-firewall"
        titleKey: root.policy === "deny" ? "settings.firewall.emptyDeny" : "settings.firewall.emptyAllow"
    }
}
