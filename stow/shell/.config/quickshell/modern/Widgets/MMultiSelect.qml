// Multi-select pill. Trailing icon differs from MSelect (single).
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property var model: []
    property var values: []
    property string placeholderKey: ""
    property bool enabled: true

    signal selected(var values)

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38

    readonly property string _label: {
        const picked = root.values || [];
        if (picked.length === 0)
            return "";
        const rows = root.model || [];
        const names = [];
        for (let i = 0; i < rows.length; i++) {
            if (picked.indexOf(rows[i].value) === -1)
                continue;
            if (rows[i].titleKey)
                names.push(I18n.t(rows[i].titleKey, rows[i].params || ({})));
            else
                names.push(rows[i].titleValue || String(rows[i].value));
        }
        return names.join(", ");
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
        border.color: menu.open ? Colors.color.primary : Colors.color.outline
        border.width: menu.open ? 2 : 1
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        spacing: Tokens.spacing.sm

        MText {
            Layout.fillWidth: true
            key: root._label.length === 0 ? root.placeholderKey : ""
            value: root._label
            styleName: "bodyLarge"
            color: root._label.length === 0 ? Colors.color.onSurfaceVariant : Colors.color.onSurface
        }

        MIcon {
            name: "view-list-symbolic"
            size: Tokens.icon.sm
            color: Colors.color.onSurfaceVariant
            tint: true
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.open = !menu.open
    }

    MPopup {
        id: menu
        open: false
        width: root.width
        implicitHeight: Math.min(list.contentHeight + Tokens.spacing.md * 2, Tokens.spacing.xxl * 10)
        y: root.height + Tokens.spacing.xs
        z: 80

        ListView {
            id: list
            anchors.fill: parent
            clip: true
            model: root.model
            delegate: MListItem {
                required property var modelData
                width: list.width
                titleKey: modelData.titleKey || ""
                titleValue: modelData.titleValue || ""
                selected: (root.values || []).indexOf(modelData.value) !== -1
                onClicked: {
                    const next = (root.values || []).slice();
                    const idx = next.indexOf(modelData.value);
                    if (idx === -1)
                        next.push(modelData.value);
                    else
                        next.splice(idx, 1);
                    root.selected(next);
                }
            }
        }
    }
}
