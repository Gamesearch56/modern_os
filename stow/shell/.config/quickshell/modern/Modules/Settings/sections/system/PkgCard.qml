import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    property var pkg: ({})

    readonly property bool _update: {
        if (String(pkg.kind || "") === "desktop")
            return pkg.pending === true || String(pkg.reason || "") === "notag";
        return String(pkg.from || "").length > 0 && String(pkg.to || "").length > 0;
    }
    readonly property string _logo: String(pkg.iconSource || "")
    readonly property string _icon: {
        if (root._logo.length > 0)
            return "";
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
            source: root._logo
            size: Tokens.spacing.xxl * 2
            color: Colors.color.primary
            tint: root._logo.length === 0
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
        MButton {
            visible: root._update
            kind: "tonal"
            key: "settings.update.changelog"
            Layout.alignment: Qt.AlignVCenter
            onClicked: Update.openChangelog(root.pkg)
        }
    }
}
