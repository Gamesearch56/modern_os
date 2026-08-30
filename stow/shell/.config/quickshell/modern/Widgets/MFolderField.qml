// Read-only path row that opens a folder picker. The Module owns the
// Service call and ConfigWrite — this only shows the path and emits.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string path: ""
    property string titleKey: "folderPicker.title"

    signal browse()

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(root.titleKey)
    Accessible.onPressAction: root.browse()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.browse();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
        border.color: root.activeFocus || hover.hovered ? Colors.color.primary : Colors.color.outline
        border.width: root.activeFocus ? 2 : 1

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.sm
        spacing: Tokens.spacing.xs

        MText {
            value: root.path
            styleName: "bodyMedium"
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        MIcon {
            name: "folder-symbolic"
            size: Tokens.icon.md
            color: Colors.color.onSurfaceVariant
            tint: true
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.browse();
        }
    }
}
