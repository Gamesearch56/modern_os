import QtQuick

Item {
    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: "default.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
