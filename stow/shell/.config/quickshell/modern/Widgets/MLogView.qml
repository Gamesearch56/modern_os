// Read-only log that stays on the newest line. A direct contentY
// write in onContentHeightChanged is undone in the same turn, so the
// tail binding is delayed until the view has its new height.
import QtQuick
import "../Commons"

Flickable {
    id: root

    property string text: ""
    property color textColor: Colors.color.onSurfaceVariant

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    contentWidth: width
    contentHeight: body.contentHeight

    Binding on contentY {
        value: Math.max(0, root.contentHeight - root.height)
        delayed: true
    }

    TextEdit {
        id: body

        width: root.width
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        persistentSelection: true
        wrapMode: TextEdit.WrapAnywhere
        textFormat: TextEdit.PlainText
        text: root.text
        color: root.textColor
        selectionColor: Colors.color.primary
        selectedTextColor: Colors.color.onPrimary
        font.family: Typography.family.monospace
        font.pixelSize: Typography.style("bodySmall").pixelSize
        font.weight: Typography.style("bodySmall").weight
        font.letterSpacing: Typography.style("bodySmall").letterSpacing
        font.hintingPreference: Font.PreferNoHinting
        renderType: TextEdit.QtRendering
        cursorVisible: false
    }
}
