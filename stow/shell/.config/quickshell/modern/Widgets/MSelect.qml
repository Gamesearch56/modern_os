// Pill field that opens a menu of MListItems. Not a native combo —
// tokens and motion stay on the kit. `model` is [{ value, titleKey?, titleValue? }].
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property var model: []
    property var value: ""
    property string placeholderKey: ""
    property bool enabled: true

    signal selected(var value)

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38

    readonly property string _label: {
        const rows = root.model || [];
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === String(root.value)) {
                if (rows[i].titleKey)
                    return I18n.t(rows[i].titleKey, rows[i].params || ({}));
                return rows[i].titleValue || String(rows[i].value);
            }
        }
        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
        border.color: menu.open ? Colors.color.primary : Colors.color.outline
        border.width: menu.open ? 2 : 1

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.short()
                easing.bezierCurve: Motion.easingStandard
            }
        }
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
            name: "go-down"
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
                selected: String(modelData.value) === String(root.value)
                onClicked: {
                    root.selected(modelData.value);
                    menu.open = false;
                }
            }
        }
    }
}
