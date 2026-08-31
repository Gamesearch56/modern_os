import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Component.onCompleted: Update.watching = true
    Component.onDestruction: Update.watching = false

    Status {
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MButton {
            kind: "filled"
            key: "settings.systemUpdate"
            iconName: "system-software-update"
            Layout.fillWidth: true
            enabled: Update.pending.length > 0 && !Update.running && !Update.mirrorsRunning
            onClicked: Update.start()
        }
        MButton {
            kind: "tonal"
            key: "settings.mirrorsUpdate"
            iconName: "view-refresh"
            busy: Update.mirrorsRunning
            enabled: !Update.running && !Update.checking
            onClicked: Update.refreshMirrors()
        }
    }

    MText {
        visible: Update.error.length > 0 && !Update.running && !Update.mirrorsRunning
        value: Update.error
        styleName: "bodySmall"
        color: Colors.color.error
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    MSectionHeader {
        visible: Update.pending.length > 0
        key: "settings.update.headline"
        styleName: "titleLarge"
        topMargin: Tokens.spacing.xxl
    }

    PkgGroup {
        visible: Update.pending.length > 0
        titleKey: "settings.update.packages"
        packages: Update.systemPkgs
        expanded: false
    }
    PkgGroup {
        visible: Update.pending.length > 0
        titleKey: "settings.update.otherPackages"
        packages: Update.otherPkgs
        expanded: false
    }

    MEmptyState {
        visible: Update.pending.length === 0 && !Update.checking
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "system-software-update"
        preferSymbolic: false
        titleKey: "settings.update.empty"
    }
}
