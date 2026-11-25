// Settings form brick: label, default-slot control, optional hint.
import QtQuick
import QtQuick.Layouts
import "../Commons"

ColumnLayout {
    id: root

    property string labelKey: ""
    property string hintKey: ""
    property string hintValue: ""
    property alias labelExtra: labelSlot.data
    property alias headerExtra: headerSlot.data
    property int _labelExtras: 0

    default property alias extra: controlSlot.data

    spacing: Tokens.spacing.xs
    Layout.fillWidth: true
    clip: false

    RowLayout {
        visible: root.labelKey.length > 0 || root._labelExtras > 0 || headerSlot.children.length > 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MText {
            visible: root.labelKey.length > 0
            key: root.labelKey
            styleName: "titleSmall"
            Layout.fillWidth: root._labelExtras === 0
        }

        // Sits against the label. headerExtra stays at the far end.
        Row {
            id: labelSlot
            spacing: Tokens.spacing.xs
            Layout.alignment: Qt.AlignVCenter
            visible: root._labelExtras > 0
            onChildrenChanged: root._labelExtras = children.length
            Component.onCompleted: root._labelExtras = children.length
        }

        Item {
            Layout.fillWidth: root._labelExtras > 0
            visible: root._labelExtras > 0
        }

        Row {
            id: headerSlot
            spacing: Tokens.spacing.xs
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
    }

    Item {
        id: controlSlot
        Layout.fillWidth: true
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        implicitWidth: Tokens.spacing.xxl * 8

        onChildrenChanged: {
            if (children.length > 0) {
                children[0].anchors.left = controlSlot.left;
                children[0].anchors.right = controlSlot.right;
            }
        }
    }

    MHint {
        visible: root.hintKey.length > 0 || root.hintValue.length > 0
        key: root.hintKey
        value: root.hintValue
        Layout.fillWidth: true
    }
}
