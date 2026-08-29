import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.gaming" }
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("Gaming.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => width);
        }
    }

    MButton {
        kind: "tonal"
        key: "settings.mirrorsUpdate"
        iconName: "view-refresh"
        onClicked: Update.refreshMirrors()
    }
    MButton {
        kind: "filled"
        key: "settings.systemUpdate"
        iconName: "system-software-update"
        onClicked: Update.start()
    }

    Loader {
        active: Update.open
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("UpdateOverlay.qml")
    }
}
