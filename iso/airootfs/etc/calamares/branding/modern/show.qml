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
        interval: 9000
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
        title: "Copying the live system"
        centeredText: "The installer is writing the image to disk. In a virtual machine this step can take a while, and the bar may sit still until the copy reports progress."
    }

    Slide {
        title: "Kernel and base packages"
        centeredText: "linux-zen is already on the live image, so this step should be a quick check rather than a long download."
    }

    Slide {
        title: "Setting up the desktop"
        centeredText: "Next the installer clones the pinned release, runs the desktop install, and enables login and networking. Each of those jobs moves the bar."
    }

    Slide {
        title: "After reboot"
        centeredText: "First boot is the login screen. Sign in with the user and password you just created."
    }
}
