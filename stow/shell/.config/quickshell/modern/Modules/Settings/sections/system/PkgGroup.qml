import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"

ColumnLayout {
    id: root

    property string titleKey: ""
    property var packages: []
    property bool expanded: true

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    Item {
        id: head
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.titleKey.length > 0 ? I18n.t(root.titleKey) : ""
        Accessible.onPressAction: root.expanded = !root.expanded
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.expanded = !root.expanded;
                event.accepted = true;
            }
        }

        RowLayout {
            id: header
            width: parent.width
            spacing: Tokens.spacing.md

            MText {
                key: root.titleKey
                styleName: "titleSmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MText {
                value: String(root.packages.length)
                styleName: "titleSmall"
                color: Colors.color.onSurfaceVariant
            }
            MIcon {
                name: root.expanded ? "go-down" : "go-next"
                size: Tokens.icon.sm
                color: Colors.color.onSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                head.forceActiveFocus();
                root.expanded = !root.expanded;
            }
        }

        MFocusRing {
            radius: Tokens.radius.small
        }
    }

    Repeater {
        model: root.expanded ? root.packages.length : 0
        PkgCard {
            required property int index
            pkg: root.packages[index]
        }
    }
}
