// Exclusive segmented control. `model` is [{ value, titleKey?, titleValue? }].
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property var model: []
    property var value: ""
    property bool enabled: true

    signal selected(var value)

    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    implicitWidth: row.implicitWidth + Tokens.spacing.xs * 2
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Grouping

    Keys.onPressed: (event) => {
        if (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right)
            return;
        const list = root.model || [];
        let i = 0;
        for (; i < list.length; i++) {
            if (String(list[i].value) === String(root.value))
                break;
        }
        if (i >= list.length)
            i = 0;
        const n = event.key === Qt.Key_Left ? Math.max(0, i - 1) : Math.min(list.length - 1, i + 1);
        if (list[n])
            root.selected(list[n].value);
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Tokens.spacing.xxs
        spacing: Tokens.spacing.xxs

        Repeater {
            model: (root.model || []).length

            Item {
                required property int index
                readonly property var opt: (root.model || [])[index] || ({})
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: Tokens.spacing.xxl * 3

                readonly property bool on: String(opt.value) === String(root.value)

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: parent.on ? Chrome.filled.bg : "transparent"
                }

                MText {
                    anchors.centerIn: parent
                    key: opt.titleKey || ""
                    value: opt.titleValue || ""
                    styleName: "labelLarge"
                    color: parent.on ? Chrome.filled.fg : Colors.color.onSurface
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    cursorShape: Qt.PointingHandCursor
                    onPressed: ring.markPointer()
                    onClicked: root.selected(opt.value)
                }
            }
        }
    }

    MFocusRing {
        id: ring
        radius: Tokens.radius.full
    }
}
