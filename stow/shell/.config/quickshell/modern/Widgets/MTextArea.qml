// Multiline filled field. Window-rules editor and similar.
import QtQuick
import "../Commons"

Item {
    id: root

    property alias text: input.text
    property string placeholderKey: ""
    property bool expanded: false

    signal textEdited()

    implicitHeight: root.expanded ? Tokens.spacing.xxl * 8 : Tokens.spacing.xxl * 4
    implicitWidth: Tokens.spacing.xxl * 12

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
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

    TextEdit {
        id: input
        anchors.fill: parent
        anchors.margins: Tokens.spacing.sm
        wrapMode: TextEdit.Wrap
        color: Colors.color.onSurface
        selectionColor: Colors.color.primary
        selectedTextColor: Colors.color.onPrimary
        font.family: Typography.family.ui
        font.pixelSize: Typography.style("bodyMedium").pixelSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: TextEdit.QtRendering
        clip: true
        onTextChanged: root.textEdited()
    }

    MText {
        visible: input.text.length === 0 && !input.activeFocus
        anchors.fill: input
        key: root.placeholderKey
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
    }
}
