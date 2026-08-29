import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

ColumnLayout {
    id: root

    property var item: null
    property bool searching: false

    signal confirmed()

    spacing: Tokens.spacing.md

    MText {
        key: root.searching ? "launcher.results" : "launcher.mostUsed"
        styleName: "labelSmall"
        color: Colors.color.onSurfaceVariant
        font.capitalization: Font.AllUppercase
    }

    MText {
        visible: root.item !== null
        value: root.item ? (root.item.name || "") : ""
        styleName: "headlineSmall"
        Layout.fillWidth: true
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            visible: root.item !== null
            anchors.centerIn: parent
            spacing: Tokens.spacing.md

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                name: root.item ? (root.item.icon || "application-x-executable") : ""
                size: Tokens.spacing.xxl * 3
                tint: root.item && (root.item.kind === "settings" || root.item.kind === "power")
            }

            MText {
                visible: !!(root.item && root.item.genericName)
                Layout.alignment: Qt.AlignHCenter
                value: root.item ? (root.item.genericName || "") : ""
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
            }
        }

        MEmptyState {
            visible: root.item === null
            anchors.fill: parent
            iconName: "edit-find-symbolic"
            titleKey: "launcher.noResults"
        }
    }

    MButton {
        visible: root.item !== null
        Layout.fillWidth: true
        kind: "filled"
        key: "launcher.open"
        onClicked: root.confirmed()
    }
}
