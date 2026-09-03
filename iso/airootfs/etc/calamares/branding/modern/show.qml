import QtQuick
import calamares.slideshow

Presentation {
    id: presentation
    textColor: "#E6E0E9"
    titleColor: "#E6E0E9"
    fontFamily: "Inter"

    function onActivate() {
    }

    function onLeave() {
    }

    Timer {
        interval: 8000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Image {
        anchors.fill: parent
        source: "wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        z: -1
    }

    Rectangle {
        anchors.fill: parent
        color: "#B3141218"
        z: -1
    }

    Slide {
        title: qsTr("Assistant")
        centeredText: qsTr("Super+A opens AI chat. Ask in your language. Replies come from a local model or Gemini.")
    }

    Slide {
        title: qsTr("Colors from your wallpaper")
        centeredText: qsTr("Pick a wallpaper with Super+W. Bars, apps, and login restyle from that image.")
    }

    Slide {
        title: qsTr("Keyboard helper")
        centeredText: qsTr("Forget a shortcut? Super+K lists every bind. Search, then press the combo.")
    }

    Slide {
        title: qsTr("App Store")
        centeredText: qsTr("Install programs from the official repositories. Search, confirm, done.")
    }

    Slide {
        title: qsTr("Launcher")
        centeredText: qsTr("Super+Space finds apps, runs commands, and does quick sums.")
    }

    Slide {
        title: qsTr("Settings")
        centeredText: qsTr("Super+I opens System Settings. One file holds every preference.")
    }

    Slide {
        title: qsTr("English and German")
        centeredText: qsTr("The desktop ships both. Switch language in Settings when you want.")
    }

    Slide {
        title: qsTr("Everyday shortcuts")
        centeredText: qsTr("Super+T terminal. Super+B browser. Super+E files. Print takes a screenshot.")
    }

    Slide {
        title: qsTr("Windows and workspaces")
        centeredText: qsTr("Super+arrows move focus. Super+Shift+arrows move the window. Super+Tab shows an overview.")
    }

    Slide {
        title: qsTr("After reboot")
        centeredText: qsTr("Sign in with the user you just created. Super+N is the control panel. Super+L locks.")
    }
}
