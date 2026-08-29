import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property var model: []
    property int currentIndex: 0

    signal queryEdited(string text)
    signal picked(int index)
    signal activated(int index)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        MSearchField {
            id: search
            Layout.fillWidth: true
            placeholderKey: "launcher.placeholder"
            onTextEdited: root.queryEdited(text)
            onAccepted: {
                if (root.model.length > 0)
                    root.activated(root.currentIndex);
            }
            onDownPressed: {
                if (root.model.length > 0)
                    root.picked(Math.min(root.model.length - 1, root.currentIndex + 1));
            }
            onUpPressed: {
                if (root.model.length > 0)
                    root.picked(Math.max(0, root.currentIndex - 1));
            }
            Component.onCompleted: forceActiveFocus()
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.spacing.xxs

                Repeater {
                    model: root.model
                    delegate: MListItem {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        variant: "nav"
                        iconName: modelData.icon || "application-x-executable"
                        tintIcon: modelData.kind === "settings" || modelData.kind === "power"
                        titleValue: modelData.name
                        selected: root.currentIndex === index
                        onClicked: root.picked(index)
                        onActivated: root.activated(index)
                    }
                }
            }
        }
    }
}
