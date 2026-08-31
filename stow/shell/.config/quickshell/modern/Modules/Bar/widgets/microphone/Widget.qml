import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs

    MIcon {
        name: Audio.sourceMuted ? "microphone-sensitivity-muted" : "audio-input-microphone"
        size: Tokens.spacing.lg
    }

    MText {
        visible: !BarLayout.vertical
        value: Audio.sourceMuted ? "—" : (Audio.sourceVolume + "%")
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                Audio.toggleSourceMute();
            else
                Settings.openAt("audio", "input");
        }
        onWheel: (w) => Audio.setSourceVolume(Audio.sourceVolume + (w.angleDelta.y > 0 ? 5 : -5))
    }
}
