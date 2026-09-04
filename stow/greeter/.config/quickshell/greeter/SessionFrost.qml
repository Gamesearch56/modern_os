// Frosted login backdrop. Desktop MFrost cannot be imported here.
import Quickshell
import QtQuick

Item {
    id: root

    property var chrome: null
    property string source: "file:///var/lib/modern/session/wallpaper-blur.jpg"

    Rectangle {
        anchors.fill: parent
        color: (root.chrome && root.chrome.color && root.chrome.color.surface)
            ? root.chrome.color.surface : "#141218"
    }

    Image {
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        Accessible.ignored: true
        onStatusChanged: {
            if (status !== Image.Error)
                return;
            if (root.source.indexOf("wallpaper-blur.jpg") >= 0)
                root.source = "file:///var/lib/modern/session/wallpaper.jpg";
            else if (root.source.indexOf("default.jpg") < 0)
                root.source = "file://" + Quickshell.env("HOME") + "/.config/modern/wallpapers/default.jpg";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: (root.chrome && root.chrome.color && root.chrome.color.surface)
            ? root.chrome.color.surface : "#141218"
        opacity: root.chrome ? root.chrome.transparency : 0.85
        Accessible.ignored: true
    }

    Rectangle {
        anchors.fill: parent
        color: (root.chrome && root.chrome.color && root.chrome.color.scrim)
            ? root.chrome.color.scrim : "#000000"
        opacity: root.chrome ? root.chrome.overlayLock : 0.32
        Accessible.ignored: true
    }
}
