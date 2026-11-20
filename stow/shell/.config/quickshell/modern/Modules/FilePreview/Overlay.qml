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

            Flickable {
                anchors.fill: parent
                visible: FilePreview.kind === "text" || FilePreview.kind === "folder"
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                MText {
                    id: body
                    width: parent.width
                    value: FilePreview.kind === "folder" ? FilePreview.listing : FilePreview.textContent
                    styleName: "bodyMedium"
                    familyRole: "monospace"
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    verticalAlignment: Text.AlignTop
                }
            }
        }

        MText {
            Layout.fillWidth: true
            visible: FilePreview.kind === "file" && FilePreview.imagePath.length === 0
            value: FilePreview.mime
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
        }

        MHint {
            Layout.fillWidth: true
            key: "filePreview.hint"
        }
    }
}
