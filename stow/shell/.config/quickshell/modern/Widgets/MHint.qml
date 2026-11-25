// Secondary helper copy under a field or section. Replaces ad-hoc
// onSurfaceVariant bodySmall blocks (and the old settings.cliNote).
import QtQuick
import "../Commons"

MText {
    styleName: "bodySmall"
    color: Colors.color.onSurfaceVariant
    wrapMode: Text.WordWrap
    elide: Text.ElideNone
}
