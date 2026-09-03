// Window switcher tile: tonal preview well, full-color app icon,
// title + caption. Stateless — the host resolves the icon name.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string titleValue: ""
    property string subtitleValue: ""
    property bool selected: false

    signal clicked()
    signal hovered()

    implicitWidth: Tokens.spacing.xxl * 7
    implicitHeight: Tokens.spacing.xxl * 7
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.titleValue
    Accessible.description: root.subtitleValue
    Accessible.onPressAction: root.clicked()
    Keys.onPressed: (event) => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        root.clicked();
        event.accepted = true;
    }

    MCard {
        anchors.fill: parent
        level: root.selected ? 3 : 1
        highlighted: root.selected
        padding: Tokens.spacing.sm

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            Rectangle {
                id: well
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.radius.small
                color: Colors.color.surfaceContainerHighest
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.color.primary
                    opacity: root.selected ? Tokens.interaction.focus : Chrome.stateLayer(ma.containsMouse, ma.pressed)
                }

                MIcon {
                    anchors.centerIn: parent
                    name: root.iconName.length ? root.iconName : "application-x-executable"
                    size: Math.max(Tokens.icon.lg, Math.round(Math.min(well.width, well.height) * 0.42))
                    tint: false
                    preferSymbolic: false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xxs

                MText {
                    value: root.titleValue
                    styleName: "titleSmall"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
                MText {
                    visible: root.subtitleValue.length > 0
                    value: root.subtitleValue
                    styleName: "labelSmall"
                    color: Colors.color.onSurfaceVariant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.clicked()
    }
}
