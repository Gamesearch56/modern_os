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
        title: qsTr("The Super key")
        centeredText: qsTr("Super is the key with the Windows logo, between Ctrl and Alt. Most shortcuts on this desktop start while you hold it.")
    }

    Slide {
        title: qsTr("Open an app")
        centeredText: qsTr("Super+Space opens the launcher. Type a few letters of the app name and press Enter.")
    }

    Slide {
        title: qsTr("The bar and the dock")
        centeredText: qsTr("The bar along the top shows the clock, sound, and network. The dock along the bottom holds the apps you open often. Click one to start it.")
    }

    Slide {
        title: qsTr("Close a window")
        centeredText: qsTr("Super+Q closes the window in front of you. Super+F fills the screen with it. Press Super+F again to bring it back to its old size.")
    }

    Slide {
        title: qsTr("Move between windows")
        centeredText: qsTr("Hold Super and press an arrow key to jump to the window in that direction. Add Shift to slide the window itself. Super+Tab shows every window.")
    }

    Slide {
        title: qsTr("More than one desk")
        centeredText: qsTr("Super and a number key from 1 to 0 switches workspace, like another desk. Super+Shift and that number takes the current window with you. Use the number row, not the number pad.")
    }

    Slide {
        title: qsTr("Save a picture of the screen")
        centeredText: qsTr("Print lets you drag around an area. Shift+Print captures the window. Super+Print captures the whole screen. The pictures are saved in Pictures.")
    }

    Slide {
        title: qsTr("Sound, light, and Wi-Fi")
        centeredText: qsTr("The volume and brightness keys on the keyboard work as usual. Super+N opens a panel for Wi-Fi, Bluetooth, sound, and brightness.")
    }

    Slide {
        title: qsTr("Lock and shut down")
        centeredText: qsTr("Super+L locks the screen. Super+M opens the menu for sleep, restart, and shut down.")
    }

    Slide {
        title: qsTr("A new wallpaper")
        centeredText: qsTr("Super+W picks a wallpaper. The bar, the apps, and the login screen take their colors from that picture.")
    }

    Slide {
        title: qsTr("Every shortcut, listed")
        centeredText: qsTr("Super+K opens the list of shortcuts. Type what you want to do, then press the keys it shows.")
    }

    Slide {
        title: qsTr("Change a setting")
        centeredText: qsTr("Super+I opens Settings. Language, keyboard, displays, the dock, and updates are all in there.")
    }

    Slide {
        title: qsTr("Files and the browser")
        centeredText: qsTr("Super+E opens your files. Super+B opens the browser. In Files, Delete moves something to the Trash, and you can restore it from there.")
    }

    Slide {
        title: qsTr("Install an app")
        centeredText: qsTr("Open the App Store from the dock or the launcher. Search for a program, open it, and confirm. It is installed when the button changes.")
    }

    Slide {
        title: qsTr("Your language")
        centeredText: qsTr("The desktop starts in the language and keyboard layout you chose here. You can change both later in Settings.")
    }

    Slide {
        title: qsTr("After the restart")
        centeredText: qsTr("Remove the USB stick while the computer restarts. Sign in with the name and password you just created.")
    }

    Slide {
        title: qsTr("If something looks wrong")
        centeredText: qsTr("Super+# opens a short form to report a problem. Super+Y opens the Manual, which explains the desktop in plain language.")
    }
}
