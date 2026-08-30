import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Component.onCompleted: Storage.watching = true
    Component.onDestruction: Storage.watching = false

    MSectionHeader {
        key: "settings.storage.internal"
        topMargin: 0
    }
    Repeater {
        model: Storage.internal.length
        DriveCard {
            required property int index
            drive: Storage.internal[index]
        }
    }
    MEmptyState {
        visible: Storage.internal.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "drive-harddisk"
        titleKey: "settings.storage.emptyInternal"
    }

    MSectionHeader {
        key: "settings.storage.external"
        topMargin: Tokens.spacing.xl
    }
    Repeater {
        model: Storage.external.length
        DriveCard {
            required property int index
            drive: Storage.external[index]
        }
    }
    MEmptyState {
        visible: Storage.external.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "drive-removable-media"
        titleKey: "settings.storage.emptyExternal"
    }
}
