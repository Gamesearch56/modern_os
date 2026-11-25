import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    property var snap: ({})

    readonly property bool _update: {
        const d = String(snap.description || "").trim();
        return d === "ModernOS Update" || d === "modern update";
    }
    readonly property string _title: {
        if (root._update)
            return I18n.t("settings.backup.update");
        const d = String(snap.description || "").trim();
        if (d.length)
            return d;
        return I18n.t("settings.backup.untitled", ({ n: snap.number || "" }));
    }

    Layout.fillWidth: true
    level: 1
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    signal requestDelete(var snap)
    signal requestRestore(var snap)

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MIcon {
                name: root._update ? "" : "document-save"
                source: root._update ? Paths.brandLogo : ""
                size: Tokens.spacing.xxl * 2
                color: Colors.color.primary
                tint: !root._update
                preferSymbolic: false
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.md
                    MText {
                        value: root._title
                        styleName: "titleLarge"
                        Layout.fillWidth: true
                    }
                    MButton {
                        kind: "outlined"
                        key: "settings.backup.restore"
                        enabled: !Snapshots.running
                        onClicked: root.requestRestore(root.snap)
                    }
                    MButton {
                        kind: "destructive"
                        key: "settings.snapshotDelete"
                        enabled: !Snapshots.running
                        onClicked: root.requestDelete(root.snap)
                    }
                }
                MText {
                    visible: String(snap.date || "").length > 0
                    value: {
                        void Config.language.dateFormat;
                        void Config.language.timeFormat;
                        return Snapshots.formatWhen(snap.date || "");
                    }
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            Repeater {
                model: {
                    const out = [];
                    if (snap.number)
                        out.push("#" + snap.number);
                    if (snap.type)
                        out.push(String(snap.type));
                    if (snap.cleanup)
                        out.push(String(snap.cleanup));
                    if (snap.user)
                        out.push(String(snap.user));
                    return out;
                }
                Rectangle {
                    required property var modelData
                    implicitHeight: Tokens.spacing.xl
                    implicitWidth: chipLab.implicitWidth + Tokens.spacing.md * 2
                    radius: Tokens.radius.full
                    color: Colors.color.surfaceContainerHighest
                    MText {
                        id: chipLab
                        anchors.centerIn: parent
                        value: modelData
                        styleName: "labelLarge"
                    }
                }
            }
        }
    }
}
