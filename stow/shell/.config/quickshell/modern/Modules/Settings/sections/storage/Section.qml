import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Component.onCompleted: {
        Storage.watching = true;
        StorageUsage.watching = true;
    }
    Component.onDestruction: {
        Storage.watching = false;
        StorageUsage.watching = false;
    }

    SystemCard {
        visible: (Storage.systemDrive && Storage.systemDrive.name)
            || Storage.internal.length > 0
        Layout.fillWidth: true
    }
    MEmptyState {
        visible: Storage.internal.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "drive-harddisk"
        titleKey: "settings.storage.emptyInternal"
    }

    MSectionHeader {
        visible: Storage.otherInternal.length > 0
        key: "settings.storage.otherDrives"
        topMargin: Tokens.spacing.xl
    }
    Repeater {
        model: Storage.otherInternal.length
        DriveCard {
            required property int index
            drive: Storage.otherInternal[index]
        }
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
