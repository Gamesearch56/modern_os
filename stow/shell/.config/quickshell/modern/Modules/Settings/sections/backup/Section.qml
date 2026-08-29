import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    Component.onCompleted: Snapshots.refresh()

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.snapper"
        MSwitch {
            checked: Config.backup.snapperEnabled
            onToggled: (v) => ConfigWrite.set("backup.snapperEnabled", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.preUpdateSnapshot"
        MSwitch {
            checked: Config.backup.preUpdateSnapshot
            onToggled: (v) => ConfigWrite.set("backup.preUpdateSnapshot", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.restic"
        MSwitch {
            checked: Config.backup.resticEnabled
            onToggled: (v) => ConfigWrite.set("backup.resticEnabled", v)
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
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    MSectionHeader { key: "settings.backup.snapshots" }
    Repeater {
        model: Snapshots.items.length
        MListItem {
            required property int index
            readonly property var snap: Snapshots.items[index] || ({})
            Layout.fillWidth: true
            titleValue: snap.description || snap.number || ""
            subtitleValue: snap.date || ""
            MButton {
                kind: "tonal"
                key: "settings.snapshotDelete"
                onClicked: Snapshots.remove(snap.number)
            }
        }
    }
    MEmptyState {
        visible: Snapshots.items.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 3
        iconName: "drive-harddisk"
        titleKey: "settings.snapshotEmpty"
    }

    MHint { key: "settings.hints.restoreGated"; Layout.fillWidth: true }
    MButton {
        kind: "tonal"
        key: "settings.refresh"
        onClicked: Snapshots.refresh()
    }
}
