// Step 2: one tile per monitor; a ticked tile is sent.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    spacing: Tokens.spacing.xl

    readonly property alias scroll: shotScroll

    MHint {
        Layout.fillWidth: true
        key: "bugReport.shotsHint"
    }

    MEmptyState {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: BugReport.shots.length === 0
        iconName: "camera-photo"
        titleKey: "bugReport.noShots"
    }

    Flickable {
        id: shotScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: BugReport.shots.length > 0
        clip: true
        contentWidth: width
        contentHeight: grid.implicitHeight

        GridLayout {
            id: grid
            width: parent.width
            columns: BugReport.shots.length > 1 ? 2 : 1
            columnSpacing: Tokens.spacing.md
            rowSpacing: Tokens.spacing.md

            Repeater {
                model: BugReport.shots

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    MImageTile {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 9 / 16
                        source: "file://" + modelData.path
                        selected: modelData.include
                        dimRest: false
                        tabFocus: true
                        activateSelected: true
                        onClicked: BugReport.toggleShot(modelData.name)
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        MText {
                            Layout.fillWidth: true
                            value: String(modelData.name).replace(/-\d+\.jpg$/, "")
                        }

                        MSwitch {
                            nameKey: "bugReport.stepShots"
                            checked: modelData.include
                            onToggled: BugReport.toggleShot(modelData.name)
                        }
                    }
                }
            }
        }
    }

    MButton {
        kind: "tonal"
        iconName: "view-refresh"
        key: "bugReport.retake"
        busy: BugReport.capturing
        onClicked: BugReport.retake()
    }
}
