import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    property var snap: ({})

    readonly property string _title: {
        const d = String(snap.description || "").trim();
        if (d.length)
            return d;
        return I18n.t("settings.backup.untitled", ({ n: snap.number || "" }));
    }

    Layout.fillWidth: true
    level: 1
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    signal requestDelete(var snap)

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
                preferSymbolic: false
                Layout.alignment: Qt.AlignTop
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
                        kind: "destructive"
                        key: "settings.snapshotDelete"
                        enabled: !Snapshots.running
                        onClicked: root.requestDelete(root.snap)
                    }
                }
                MText {
                    visible: String(snap.date || "").length > 0
                    value: snap.date || ""
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
