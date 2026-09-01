import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property alias flick: pane
    readonly property bool empty: !Store.loading && Store.sections.length === 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MLinearProgress {
            visible: Store.loading
            Layout.fillWidth: true
            indeterminate: true
        }

        Flickable {
            id: pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.empty
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.spacing.lg

                Repeater {
                    model: Store.sections.length

                    PkgShelf {
                        required property int index
                        Layout.fillWidth: true
                        section: Store.sections[index] || ({})
                    }
                }
            }
        }

        MEmptyState {
            visible: root.empty
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "system-software-install-symbolic"
            titleKey: "store.empty"
            hintKey: "store.emptyHint"
        }
    }
}
