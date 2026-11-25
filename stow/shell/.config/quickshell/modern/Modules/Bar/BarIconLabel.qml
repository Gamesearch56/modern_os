// Icon plus optional label sharing one stadium hover/press layer.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property string iconName: ""
    property string key: ""
    property string label: ""
    property bool showLabel: false
    property bool checked: false
    property bool alert: false
    property int iconSize: Tokens.icon.md

    signal clicked()

    readonly property bool _named: root.showLabel && root.label.length > 0
    readonly property color _fg: root.checked
        ? Colors.color.onPrimaryContainer
        : (root.alert ? Colors.color.error : Colors.color.onSurface)
    readonly property real _layer: Chrome.stateLayer(ma.containsMouse && !root.checked, ma.pressed && !root.checked)

    implicitWidth: row.implicitWidth
    implicitHeight: BarLayout.height
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillWidth: false
    Accessible.role: Accessible.Button
    Accessible.name: root.key.length > 0 ? I18n.t(root.key) : root.label

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Chrome.tonal.bg
        visible: root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.primary
        visible: root._layer > 0
        opacity: root._layer
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root._named ? Tokens.spacing.xxs : 0
        height: BarLayout.height

        Item {
            // An icon-only neighbor is centered in the bar height. A labeled
            // icon is only iconSize wide, so match that inset on the leading edge.
            Layout.leftMargin: root._named ? (BarLayout.height - root.iconSize) / 2 : 0
            Layout.preferredWidth: root._named ? root.iconSize : BarLayout.height
            Layout.preferredHeight: BarLayout.height

            MIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: root.iconSize
                color: root._fg
            }
        }

        MText {
            visible: root._named
            value: root.label
            styleName: "labelSmall"
            color: root._fg
            elide: Text.ElideRight
            Layout.preferredWidth: visible ? Math.min(implicitWidth, Tokens.spacing.xxl * 8) : 0
            Layout.preferredHeight: visible ? implicitHeight : 0
            Layout.maximumWidth: Tokens.spacing.xxl * 8
            Layout.rightMargin: visible ? Tokens.spacing.sm : 0
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }
}
