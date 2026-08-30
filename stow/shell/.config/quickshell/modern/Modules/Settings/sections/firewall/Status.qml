import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    Layout.fillWidth: true
    level: 0
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2
    Layout.preferredHeight: implicitHeight

    readonly property string _statusKey: {
        if (Firewall.status === "active")
            return "settings.firewall.active";
        if (Firewall.status === "inactive")
            return "settings.firewall.inactive";
        return "settings.firewall.missing";
    }

    readonly property string _hintKey: {
        if (Firewall.status === "active")
            return "settings.hints.firewallActive";
        if (Firewall.status === "inactive")
            return "settings.hints.firewallInactive";
        return "settings.hints.firewallMissing";
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MIcon {
                name: "preferences-security-firewall"
                size: Tokens.spacing.xxl * 2
                color: Colors.color.onSurface
                tint: true
                preferSymbolic: false
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xs
                MText {
                    key: "settings.firewall.engine"
                    styleName: "titleLarge"
                    Layout.fillWidth: true
                }
                MText {
                    key: root._statusKey
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }
        }

        MHint {
            key: root._hintKey
            Layout.fillWidth: true
        }
    }
}
