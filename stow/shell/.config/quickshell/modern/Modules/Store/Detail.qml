import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property var info: Store.detail || ({})
    readonly property string pkgName: Store.detailName
    readonly property Flickable flick: pane

    Flickable {
        id: pane
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Tokens.spacing.lg

            DetailHero {
                Layout.fillWidth: true
                info: root.info
            }

            DetailShots {
                Layout.fillWidth: true
                shots: Store.shots
            }

            MText {
                key: "store.description"
                styleName: "titleSmall"
                Layout.fillWidth: true
            }
            MText {
                value: Store.descFor(root.pkgName, String(root.info.desc || ""))
                styleName: "bodyMedium"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            DetailInfo {
                Layout.fillWidth: true
                info: root.info
            }
        }
    }
}
