// Settings-like nav. Widget ProgressTreeView cannot round the current
// step (C++ delegate); this QML file is the branding escape hatch.
import QtQuick 2.15
import QtQuick.Layouts 1.15
import io.calamares.core 1.0
import io.calamares.ui 1.0

Rectangle {
    id: sideBar

    color: Branding.styleString(Branding.SidebarBackground)

    readonly property int pad: 12
    readonly property int gap: 4
    readonly property int pillH: 40
    readonly property int logoSize: 56
    readonly property int pillRadius: 999
    readonly property color hoverFill: Qt.rgba(1, 1, 1, 0.08)

    function openAbout() {
        if (typeof debug !== "undefined" && debug)
            debug.about();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: sideBar.pad
        spacing: sideBar.pad

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: sideBar.logoSize
            Layout.preferredHeight: sideBar.logoSize
            source: "logo.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: sideBar.gap
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            model: ViewManager

            delegate: Item {
                width: ListView.view.width
                height: sideBar.pillH

                readonly property bool current: index === ViewManager.currentStepIndex

                Rectangle {
                    anchors.fill: parent
                    radius: sideBar.pillRadius
                    color: current
                           ? Branding.styleString(Branding.SidebarBackgroundCurrent)
                           : "transparent"
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: sideBar.pad
                    anchors.rightMargin: sideBar.pad
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: current ? Font.Medium : Font.Normal
                    color: current
                           ? Branding.styleString(Branding.SidebarTextCurrent)
                           : Branding.styleString(Branding.SidebarText)
                    text: model.display
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: sideBar.pillH

            Rectangle {
                anchors.fill: parent
                radius: sideBar.pillRadius
                color: aboutHover.containsMouse ? sideBar.hoverFill : Qt.rgba(1, 1, 1, 0.06)
            }

            Text {
                anchors.centerIn: parent
                font.family: "Inter"
                font.pixelSize: 14
                color: Branding.styleString(Branding.SidebarText)
                text: qsTr("About")
            }

            MouseArea {
                id: aboutHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sideBar.openAbout()
            }
        }
    }
}
