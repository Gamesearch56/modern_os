// Single-line text field. Placeholder is an I18n key. Used by launcher
// search, Settings search, lock-screen password (echoMode Password).
import QtQuick
import "../Commons"

Item {
    id: root

    property alias text: input.text
    property string placeholderKey: ""
    property string iconName: ""
    property int echoMode: TextInput.Normal
    property bool enabled: true

    signal accepted()
    signal textEdited()
    signal upPressed()
    signal downPressed()

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.small
        color: Colors.color.surfaceContainerHighest
        border.color: input.activeFocus ? Colors.color.primary : Colors.color.outline
        border.width: input.activeFocus ? 2 : 1

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MIcon {
        visible: root.iconName.length > 0
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        name: root.iconName
        size: Tokens.spacing.lg
        color: Colors.color.onSurfaceVariant
        tint: true
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.iconName.length > 0 ? Tokens.spacing.xxl + Tokens.spacing.xs : Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        verticalAlignment: TextInput.AlignVCenter
        color: Colors.color.onSurface
        selectionColor: Colors.color.primaryContainer
        selectedTextColor: Colors.color.onPrimaryContainer
        font.family: Typography.family.ui
        font.pixelSize: Typography.style("bodyLarge").pixelSize
        echoMode: root.echoMode
        enabled: root.enabled
        clip: true
        onAccepted: root.accepted()
        onTextChanged: root.textEdited()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Down) {
                root.downPressed();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.upPressed();
                event.accepted = true;
            }
        }
    }

    MText {
        visible: input.text.length === 0 && !input.activeFocus
        anchors.fill: input
        key: root.placeholderKey
        styleName: "bodyLarge"
        color: Colors.color.onSurfaceVariant
    }

    function forceActiveFocus() {
        input.forceActiveFocus();
    }
}
