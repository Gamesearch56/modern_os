import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property var cursorChoices: root._cursorChoices()

    Component.onCompleted: Hypr.refreshCursorThemes()

    function _cursorChoices() {
        void Hypr.cursorThemes;
        const names = Hypr.cursorThemes || [];
        const cur = String(Config.design.cursorTheme ?? "");
        const out = [];
        const seen = {};
        if (cur.length > 0) {
            out.push({ value: cur, titleValue: cur });
            seen[cur] = true;
        }
        for (let i = 0; i < names.length; i++) {
            const n = String(names[i] || "");
            if (!n.length || seen[n])
                continue;
            seen[n] = true;
            out.push({ value: n, titleValue: n });
        }
        return out;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.cursorTheme"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.cursorChoices
            value: Config.design.cursorTheme ?? ""
            onSelected: (v) => {
                ConfigWrite.set("design.cursorTheme", v);
                Hypr.setCursor(v, Config.design.cursorSize ?? 24);
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.cursorSize"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSlider {
            Layout.fillWidth: true
            from: 16
            to: 48
            value: Config.design.cursorSize ?? 24
            showValue: true
            onMoved: (v) => Hypr.setCursor(Config.design.cursorTheme ?? "", Math.round(v))
            onCommitted: (v) => ConfigWrite.set("design.cursorSize", Math.round(v))
        }
    }
}
