// Window header: title (+ optional subtitle) on the left, close on the
// right. `titleColumnWidth` pins the title over a Settings-style sidebar.
import QtQuick
import QtQuick.Layouts
import "../Commons"

RowLayout {
    id: root

    property string titleKey: ""
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property string actionKey: ""
    property string actionIcon: ""
    property real titleColumnWidth: 0
    property bool busy: false

    readonly property bool _hasSubtitle: root.subtitleKey.length > 0 || root.subtitleValue.length > 0

    signal closed()
    signal actionClicked()

    Layout.fillWidth: true
    spacing: Tokens.spacing.md

    ColumnLayout {
        Layout.preferredWidth: root.titleColumnWidth > 0 ? root.titleColumnWidth : -1
        Layout.fillWidth: root.titleColumnWidth <= 0
        spacing: Tokens.spacing.xs

        MText {
            key: root.titleKey
            value: root.titleValue
            styleName: "headlineSmall"
            Layout.fillWidth: true
        }

        MText {
            visible: root._hasSubtitle
            key: root.subtitleKey
            value: root.subtitleValue
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
    }

    Item {
        Layout.fillWidth: true
    }

    MIconButton {
        visible: root.actionKey.length > 0 || root.actionIcon.length > 0
        iconName: root.actionIcon.length > 0 ? root.actionIcon : "list-add"
        key: root.actionKey
        onClicked: root.actionClicked()
    }

    Item {
        visible: root.busy
        implicitWidth: Tokens.icon.md
        implicitHeight: Tokens.icon.md
        Layout.alignment: Qt.AlignVCenter
        Accessible.role: Accessible.Status
        Accessible.name: I18n.t("settings.saving")

        MIcon {
            id: saveGlyph
            anchors.centerIn: parent
            name: "view-refresh"
            size: Tokens.icon.md
            color: Colors.color.primary
            tint: true

            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: Motion.extraLongMs
                loops: Animation.Infinite
            }
        }

        onVisibleChanged: {
            if (!visible)
                saveGlyph.rotation = 0;
        }
    }

    MIconButton {
        close: true
        iconName: "window-close"
        key: "bar.close"
        onClicked: root.closed()
    }
}
