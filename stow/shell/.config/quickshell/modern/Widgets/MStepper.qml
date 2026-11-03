// Numbered step track. Circles and a connector, not pills, so a wizard
// header does not read as another row of filter chips.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property int current: 0
    property var steps: []
    // Same length as steps. Null keeps every step up to `current` open.
    property var reachable: null

    signal activated(int index)

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: row.implicitHeight

    function canOpen(index) {
        const steps = root.steps || [];
        if (index < 0 || index >= steps.length)
            return false;
        const gate = root.reachable;
        if (gate && gate.length === steps.length)
            return !!gate[index];
        return index <= root.current;
    }

    function _done(index) {
        return index < root.current;
    }

    function _nodeColor(index) {
        if (index === root.current)
            return Colors.color.primary;
        if (root._done(index))
            return Colors.color.primaryContainer;
        return "transparent";
    }

    function _markColor(index) {
        if (index === root.current)
            return Colors.color.onPrimary;
        if (root._done(index))
            return Colors.color.onPrimaryContainer;
        return Colors.color.onSurfaceVariant;
    }

    function _labelColor(index) {
        if (index === root.current)
            return Colors.color.primary;
        if (root._done(index))
            return Colors.color.onSurface;
        return Colors.color.onSurfaceVariant;
    }

    function _trackColor(before) {
        return before < root.current ? Colors.color.primary : Colors.color.outlineVariant;
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Repeater {
            model: root.steps || []

            Item {
                id: cell
                required property int index
                required property string modelData

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                implicitHeight: column.implicitHeight
                activeFocusOnTab: root.canOpen(index)
                Accessible.role: root.canOpen(index) ? Accessible.Button : Accessible.StaticText
                Accessible.name: I18n.t(modelData)
                Accessible.onPressAction: {
                    if (root.canOpen(index))
                        root.activated(index);
                }

                Keys.onPressed: (event) => {
                    if (!root.canOpen(index))
                        return;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.activated(index);
                        event.accepted = true;
                    }
                }

                Rectangle {
                    visible: cell.index > 0
                    height: Tokens.stepper.track
                    color: root._trackColor(cell.index - 1)
                    anchors.verticalCenter: node.verticalCenter
                    anchors.left: parent.left
                    anchors.right: node.left
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.shortMs
                            easing.bezierCurve: Motion.easingStandard
                        }
                    }
                }

                Rectangle {
                    visible: cell.index < (root.steps || []).length - 1
                    height: Tokens.stepper.track
                    color: root._trackColor(cell.index)
                    anchors.verticalCenter: node.verticalCenter
                    anchors.left: node.right
                    anchors.right: parent.right
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.shortMs
                            easing.bezierCurve: Motion.easingStandard
                        }
                    }
                }

                ColumnLayout {
                    id: column
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Tokens.spacing.xxs
                    anchors.rightMargin: Tokens.spacing.xxs
                    spacing: Tokens.spacing.sm
                    z: 1

                    Item {
                        id: node
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Tokens.stepper.node
                        Layout.preferredHeight: Tokens.stepper.node

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius.full
                            color: root._nodeColor(cell.index)
                            border.color: cell.index > root.current ? Colors.color.outline : "transparent"
                            border.width: cell.index > root.current ? Tokens.stroke.hairline : 0
                            antialiasing: true

                            Behavior on color {
                                ColorAnimation {
                                    duration: Motion.shortMs
                                    easing.bezierCurve: Motion.easingStandard
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius.full
                            color: root._markColor(cell.index)
                            opacity: Chrome.stateLayer(ma.containsMouse, ma.pressed)
                        }

                        MIcon {
                            anchors.centerIn: parent
                            visible: root._done(cell.index)
                            name: "emblem-ok-symbolic"
                            size: Tokens.icon.xs
                            color: root._markColor(cell.index)
                        }

                        MText {
                            anchors.centerIn: parent
                            visible: !root._done(cell.index)
                            value: String(cell.index + 1)
                            styleName: "labelMedium"
                            color: root._markColor(cell.index)
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        key: cell.modelData
                        styleName: "labelMedium"
                        color: root._labelColor(cell.index)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canOpen(cell.index)
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: ring.markPointer()
                    onClicked: root.activated(cell.index)
                }

                MFocusRing {
                    id: ring
                    radius: Tokens.radius.small
                }
            }
        }
    }
}
