// Window switcher tile: tonal preview well, identity chip, title +
// captions. Stateless — the host fills the well and resolves names.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string titleValue: ""
    property string subtitleValue: ""
    property string captionValue: ""
    property bool selected: false
    property bool previewReady: false
    default property alias preview: wellHost.data

    signal clicked()
    signal hovered()

    implicitWidth: Tokens.recents.cardWidth
    implicitHeight: Tokens.recents.cardHeight
    activeFocusOnTab: false
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
        level: root.selected ? 4 : 1
        highlighted: root.selected
        padding: Tokens.spacing.sm

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            Rectangle {
                id: well
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Tokens.recents.wellHeight
                radius: Tokens.radius.medium
                color: Colors.color.surfaceContainerHighest
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: !root.previewReady
                    color: Colors.color.primary
                    opacity: root.selected ? Tokens.interaction.focus : Chrome.stateLayer(ma.containsMouse, ma.pressed)
                }

                MIcon {
                    anchors.centerIn: parent
                    visible: !root.previewReady
                    name: root.iconName.length ? root.iconName : "application-x-executable"
                    size: Math.max(Tokens.icon.lg, Math.round(Math.min(well.width, well.height) * 0.42))
                    tint: false
                    preferSymbolic: false
                }

                Item {
                    id: wellHost
                    anchors.fill: parent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.sm

                MIcon {
                    name: root.iconName.length ? root.iconName : "application-x-executable"
                    size: Tokens.icon.md
                    tint: false
                    preferSymbolic: false
                    Layout.alignment: Qt.AlignVCenter
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
                    MText {
                        visible: root.captionValue.length > 0
                        value: root.captionValue
                        styleName: "labelSmall"
                        color: Colors.color.onSurfaceVariant
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
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
