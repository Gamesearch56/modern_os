import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../../../Commons"
import "../../../../Services"

Row {
    spacing: Tokens.spacing.xs

    Repeater {
        model: SystemTray.items

        Item {
            required property var modelData
            width: Tokens.spacing.lg
            height: Tokens.spacing.lg

            IconImage {
                anchors.fill: parent
                source: modelData.icon
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        Tray.activate(modelData);
                    else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate();
                    else
                        modelData.display(parent, 0, parent.height);
                }
            }
        }
    }
}
