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

    MHint {
        visible: !Passwd.canManage
        key: "settings.systemAdminOnly"
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
            enabled: Passwd.canManage && Update.pending.length > 0 && !Update.running && !Update.mirrorsRunning
            onClicked: Update.start()
        }
        MButton {
            kind: "tonal"
            key: "settings.mirrorsUpdate"
            iconName: "view-refresh"
            busy: Update.mirrorsRunning
            enabled: Passwd.canManage && !Update.running && !Update.checking
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
        visible: Update.pending.length > 0 && !Update.checking
        key: "settings.update.headline"
        styleName: "titleLarge"
        topMargin: Tokens.spacing.xxl
    }

    PkgGroup {
        visible: Update.systemPkgs.length > 0 && !Update.checking
        titleKey: "settings.update.packages"
        packages: Update.systemPkgs
        expanded: Update.pending.length === 0
    }
    PkgGroup {
        visible: Update.otherPkgs.length > 0 && !Update.checking
        titleKey: "settings.update.otherPackages"
        packages: Update.otherPkgs
        expanded: false
    }

    MEmptyState {
        visible: Update.systemPkgs.length === 0 && Update.otherPkgs.length === 0 && !Update.checking
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "system-software-update"
        preferSymbolic: false
        titleKey: "settings.update.empty"
    }
}
