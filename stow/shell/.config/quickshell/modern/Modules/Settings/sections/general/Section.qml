import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.hub.title" }
    MHint { key: "settings.hub.hint"; Layout.fillWidth: true }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.sections.displays"
        iconName: "video-display"
        onClicked: Settings.openAt("displays", "")
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.sections.design"
        iconName: "preferences-desktop-theme"
        onClicked: Settings.openAt("design", "")
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.sections.audio"
        iconName: "audio-volume-high"
        onClicked: Settings.openAt("audio", "")
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.systemUpdate"
        iconName: "system-software-update"
        onClicked: Settings.openAt("system", "update")
    }
}
