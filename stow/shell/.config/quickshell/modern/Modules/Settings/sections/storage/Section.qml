import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    Component.onCompleted: Storage.watching = true
    Component.onDestruction: Storage.watching = false

    MSectionHeader { key: "settings.storage.mounts" }
    Repeater {
        model: Storage.mounts
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.target
            subtitleValue: modelData.usedLabel + " / " + modelData.sizeLabel + " · " + modelData.freeLabel
        }
    }

    MSectionHeader { key: "settings.storage.devices" }
    Repeater {
        model: Storage.devices
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: (modelData.model || modelData.name || "") + (modelData.tran ? " · " + modelData.tran : "")
            subtitleValue: modelData.size || ""
            MButton {
                visible: !!(modelData.rm)
                kind: "tonal"
                key: "settings.storage.eject"
                onClicked: Storage.eject(modelData.name)
            }
        }
    }
}
