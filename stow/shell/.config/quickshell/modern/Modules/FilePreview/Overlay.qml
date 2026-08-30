import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    signal closed()

    property bool _entered: false
    readonly property bool _shown: root._entered
    readonly property string _imageUrl: FilePreview.kind === "image" && FilePreview.path.length > 0
        ? ("file://" + encodeURI(FilePreview.path)) : ""

    Component.onCompleted: root._entered = true

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root._shown ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Item {
        id: wrap
        width: card.width
        height: card.height
        anchors.centerIn: parent
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown)
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            id: card
            width: Math.min(root.width - Tokens.spacing.xl * 2, Tokens.spacing.xxl * 24)
            height: Math.min(root.height - Tokens.spacing.xl * 2, Tokens.spacing.xxl * 20)
            color: Colors.color.surface
            radius: Tokens.radius.medium
            border.color: Colors.color.outlineVariant
            border.width: Tokens.stroke.hairline
            clip: true
            opacity: Config.design.transparency ?? 0.85

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.lg
                spacing: Tokens.spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.sm

                    MText {
                        Layout.fillWidth: true
                        key: "filePreview.title"
                        styleName: "titleMedium"
                    }

                    MIconButton {
                        close: true
                        iconName: "window-close"
                        key: "bar.close"
                        onClicked: root.closed()
                    }
                }

                MText {
                    Layout.fillWidth: true
                    value: FilePreview.fileName
                    styleName: "bodyMedium"
                    elide: Text.ElideMiddle
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Image {
                        id: preview
                        anchors.fill: parent
                        visible: FilePreview.kind === "image" && !FilePreview.imageFailed
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        source: root._imageUrl
                        onStatusChanged: {
                            if (status === Image.Error)
                                FilePreview.markImageFailed();
                        }
                    }

                    Flickable {
                        anchors.fill: parent
                        visible: FilePreview.kind === "text"
                        clip: true
                        contentWidth: width
                        contentHeight: body.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        MText {
                            id: body
                            width: parent.width
                            value: FilePreview.textContent
                            styleName: "bodyMedium"
                            familyRole: "monospace"
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            verticalAlignment: Text.AlignTop
                        }
                    }
                }

                MHint {
                    Layout.fillWidth: true
                    key: "filePreview.hint"
                }
            }
        }
    }
}
