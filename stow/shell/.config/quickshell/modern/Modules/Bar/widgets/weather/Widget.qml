import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: BarLayout.vertical ? Config.bar.height : (row.implicitWidth + Tokens.spacing.md * 2)
    implicitHeight: Config.bar.height
    Component.onCompleted: Weather.watching = true
    Component.onDestruction: Weather.watching = false

    readonly property color _fg: popup.open ? Colors.color.onPrimaryContainer : Colors.color.onSurface

    BarIslandHit {
        checked: popup.open
        onClicked: popup.open = !popup.open
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        z: 1
        spacing: Tokens.spacing.xs

        MIcon {
            name: Weather.iconName
            size: Tokens.icon.md
            color: root._fg
        }

        MText {
            visible: !BarLayout.vertical
            key: Weather.available ? "" : "weather.unavailable"
            value: Weather.display
            styleName: "labelLarge"
            color: root._fg
        }
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 14
        implicitHeight: (panelLoader.item ? panelLoader.item.implicitHeight : Tokens.spacing.xxl * 10) + Tokens.spacing.md * 2
        hAlign: Qt.AlignRight
        onImplicitHeightChanged: {
            if (popup.open)
                popup.anchor.updateAnchor();
        }

        Loader {
            id: panelLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: item ? item.implicitHeight : parent.height
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                if (item)
                    item.width = Qt.binding(() => panelLoader.width);
            }
        }
    }
}
