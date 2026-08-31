import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MOverlay {
    id: root

    titleKey: "filePreview.title"
    cardWidth: Tokens.window.overlayWidth
    cardHeight: Tokens.window.overlayHeight

    readonly property string _imageUrl: FilePreview.kind === "image" && FilePreview.path.length > 0
        ? ("file://" + encodeURI(FilePreview.path)) : ""

    ColumnLayout {
        spacing: Tokens.spacing.md

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
