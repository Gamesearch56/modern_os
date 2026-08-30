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

    implicitHeight: col.implicitHeight

    Component.onCompleted: Snapshots.watching = true
    Component.onDestruction: Snapshots.watching = false

    readonly property string _emptyKey: Snapshots.status === "unconfigured"
        ? "settings.backup.unconfigured"
        : "settings.backup.missing"

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
                    key: "settings.fields.preUpdateSnapshot"
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MSwitch {
                    checked: Config.backup.preUpdateSnapshot
                    onToggled: (v) => ConfigWrite.set("backup.preUpdateSnapshot", v)
                }
            }
            MHint {
                key: "settings.hints.preUpdateSnapshot"
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.backup.snapshots"
                styleName: "titleSmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MIconButton {
                iconName: "view-refresh"
                key: "settings.refresh"
                iconSize: Tokens.icon.sm
                enabled: !Snapshots.running
                onClicked: Snapshots.refresh()
            }
            MButton {
                kind: "filled"
                key: "settings.backup.create"
                enabled: Snapshots.ready && !Snapshots.running
                onClicked: Snapshots.create()
            }
        }

        MLinearProgress {
            visible: Snapshots.running
            Layout.fillWidth: true
            indeterminate: true
        }
        MText {
            visible: Snapshots.step.length > 0
            value: Snapshots.step
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        MText {
            visible: Snapshots.error.length > 0 && !Snapshots.running
            value: Snapshots.error
            styleName: "bodySmall"
            color: Colors.color.error
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Repeater {
            model: Snapshots.items.length
            SnapshotCard {
                required property int index
                snap: Snapshots.items[index]
                onRequestDelete: (s) => root.pending = s
            }
        }
        MEmptyState {
            visible: Snapshots.items.length === 0 && !Snapshots.running
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.xxl * 4
            iconName: "document-save"
            titleKey: Snapshots.ready ? "settings.snapshotEmpty" : root._emptyKey
        }

        MHint {
            key: "settings.hints.restoreGated"
            Layout.fillWidth: true
        }
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pending !== null
        titleKey: "settings.backup.deleteTitle"
        bodyKey: "settings.backup.deleteBody"
        bodyParams: ({
            n: root.pending ? String(root.pending.number || "") : "",
            date: root.pending ? String(root.pending.date || "") : ""
        })
        confirmKey: "settings.snapshotDelete"
        cancelKey: "powerMenu.cancel"
        destructive: true
        onConfirmed: {
            if (root.pending)
                Snapshots.remove(root.pending.number);
            root.pending = null;
        }
        onCancelled: root.pending = null
    }
}
