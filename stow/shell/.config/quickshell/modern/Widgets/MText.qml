// Token-driven text. Pass `key` for an I18n lookup, or `value` for
// already-resolved / dynamic strings (clocks, percentages). Never a
// hardcoded family or size — always Typography + Colors.
import QtQuick
import "../Commons"

Text {
    id: root

    property string key: ""
    property var params: ({})
    property string value: ""
    property string styleName: "bodyMedium"
    property string familyRole: "ui"

    readonly property var _style: Typography.style(root.styleName)

    text: root.key !== "" ? I18n.t(root.key, root.params) : root.value
    color: Colors.color.onSurface
    font.family: Typography.family[root.familyRole] ?? Typography.family.ui
    font.pixelSize: root._style.pixelSize
    font.weight: root._style.weight
    font.letterSpacing: root._style.letterSpacing
    lineHeight: root._style.lineHeight
    lineHeightMode: Text.FixedHeight
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
    antialiasing: true
    font.hintingPreference: Font.PreferNoHinting
}
