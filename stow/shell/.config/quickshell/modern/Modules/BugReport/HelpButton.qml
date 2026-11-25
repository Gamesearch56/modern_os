// Question mark beside a field label. The note opens under the icon.
import QtQuick
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property string nameKey: ""
    property string bodyKey: ""

    signal opened()

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    function close() {
        pop.open = false;
    }

    MIconButton {
        id: btn
        iconName: "dialog-question"
        size: Tokens.icon.md
        iconSize: Tokens.icon.sm
        key: root.nameKey
        onClicked: {
            const next = !pop.open;
            pop.open = next;
            if (next)
                root.opened();
        }
    }

    MPopup {
        id: pop
        implicitWidth: Tokens.spacing.xxl * 10
        implicitHeight: tip.implicitHeight + Tokens.spacing.md * 2

        MText {
            id: tip
            width: parent.width
            key: root.bodyKey
            styleName: "bodyMedium"
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
}
