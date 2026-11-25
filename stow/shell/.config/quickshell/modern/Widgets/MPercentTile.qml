// Compact percent tile: headline + value, optional wallpaper-primary track.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Rectangle {
    id: root

    property string titleKey: ""
    property string valueText: ""
    // A name that does not fit beside the label. It wraps on its own line.
    property string detailText: ""
    property real percent: 0
    property bool showTrack: true

    implicitHeight: col.implicitHeight + Tokens.spacing.md * 2
    implicitWidth: Tokens.spacing.xxl * 6
    radius: Tokens.radius.small
    color: Colors.color.surfaceContainer

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Tokens.spacing.md
        spacing: Tokens.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            MText {
                key: root.titleKey
                styleName: "titleSmall"
                Layout.fillWidth: true
            }
            MText {
                value: root.valueText
                styleName: "labelLarge"
                familyRole: "monospace"
            }
        }

        MText {
            visible: root.detailText.length > 0
            Layout.fillWidth: true
            value: root.detailText
            styleName: "bodyMedium"
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Rectangle {
            visible: root.showTrack
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.xs
            radius: Tokens.radius.full
            color: Colors.color.outlineVariant

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.percent / 100))
                height: parent.height
                radius: parent.radius
                color: Colors.color.primary
            }
        }
    }
}
