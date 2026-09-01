import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"

MCard {
    id: root

    property var pkg: ({})

    readonly property string _icon: {
        const n = String(pkg.iconName || "");
        if (!n.length || n === "package-x-generic")
            return "package-x-generic-symbolic";
        return n;
    }

    Layout.fillWidth: true
    level: 1
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    RowLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.lg

        MIcon {
            name: root._icon
            size: Tokens.spacing.xxl * 2
            color: Colors.color.primary
            tint: true
            preferSymbolic: false
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            MText {
                value: pkg.name || ""
                styleName: "titleLarge"
                Layout.fillWidth: true
            }
            MText {
                visible: String(pkg.subtitle || "").length > 0
                value: pkg.subtitle || ""
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MText {
                visible: String(pkg.subtitle || "").length === 0
                key: "settings.update.fromTo"
                params: ({ from: pkg.from || "", to: pkg.to || "" })
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }
    }
}
