import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.lg

    MAvatar {
        Layout.alignment: Qt.AlignHCenter
        size: Tokens.spacing.xxl * 3
        source: User.faceUrl
    }

    MText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        value: User.displayName
        styleName: "titleLarge"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
