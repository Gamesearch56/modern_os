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
    property bool markdown: false

    readonly property var _style: {
        void Typography.scale;
        return Typography.style(root.styleName);
    }

    text: root.key !== "" ? I18n.t(root.key, root.params) : root.value
    textFormat: root.markdown ? Text.MarkdownText : Text.PlainText
    color: Colors.color.onSurface
    font.family: Typography.family[root.familyRole] ?? Typography.family.ui
    font.pixelSize: root._style.pixelSize
    font.weight: root._style.weight
    font.letterSpacing: root._style.letterSpacing
    lineHeight: {
        if (!root.markdown)
            return root._style.lineHeight;
        const px = root._style.pixelSize;
        return px > 0 ? root._style.lineHeight / px : 1;
    }
    lineHeightMode: root.markdown ? Text.ProportionalHeight : Text.FixedHeight
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
    verticalAlignment: root.markdown ? Text.AlignTop : Text.AlignVCenter
    renderType: Text.QtRendering
    antialiasing: true
    font.hintingPreference: Font.PreferNoHinting
}
