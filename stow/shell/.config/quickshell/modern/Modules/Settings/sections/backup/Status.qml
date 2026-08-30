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
        if (Snapshots.status === "ready")
            return "settings.backup.ready";
        if (Snapshots.status === "unconfigured")
            return "settings.backup.unconfigured";
        return "settings.backup.missing";
    }

    readonly property string _hintKey: {
        if (Snapshots.status === "ready")
            return "settings.hints.snapperReady";
        if (Snapshots.status === "unconfigured")
            return "settings.hints.snapperUnconfigured";
        return "settings.hints.snapperMissing";
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MIcon {
                name: "document-save"
                size: Tokens.spacing.xxl * 2
                color: Colors.color.onSurface
                tint: true
                preferSymbolic: true
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xs
                MText {
                    key: "settings.backup.engine"
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
