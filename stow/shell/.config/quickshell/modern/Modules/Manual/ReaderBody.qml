import QtQuick
import "../../Commons"

// One chapter. The reader throws this away on every page change: a
// TextEdit that has already been scrolled keeps that clip in its scene
// graph, and the next chapter paints only the old strip until the wheel
// moves again.
TextEdit {
    id: body

    property real textScale: 1

    signal activate()

    readonly property var _style: Typography.style("bodyLarge")

    textFormat: TextEdit.RichText
    readOnly: true
    selectByMouse: true
    activeFocusOnPress: false
    wrapMode: TextEdit.Wrap
    color: Colors.color.onSurface
    // Table cells read the palette, not this color. Left alone they
    // stay black on the dark page while the grid stays visible.
    palette.text: Colors.color.onSurface
    palette.windowText: Colors.color.onSurface
    selectionColor: Colors.color.primaryContainer
    selectedTextColor: Colors.color.onPrimaryContainer
    font.family: Typography.family.document
    font.pixelSize: Math.round(body._style.pixelSize * body.textScale)
    font.letterSpacing: body._style.letterSpacing
    palette.link: Colors.color.primary

    HoverHandler {
        cursorShape: body.hoveredLink.length ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
    TapHandler {
        onTapped: body.activate()
    }
}
