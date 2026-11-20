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
                id: scroll
                anchors.fill: parent
                visible: FilePreview.kind === "text" || FilePreview.kind === "folder"
                clip: true
                contentWidth: width
                contentHeight: folderCol.visible ? folderCol.implicitHeight : body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: folderCol
                    width: scroll.width
                    visible: FilePreview.kind === "folder" && (FilePreview.rows || []).length > 0
                    spacing: Tokens.spacing.xs

                    Repeater {
                        model: FilePreview.rows
                        delegate: Row {
                            required property var modelData
                            width: folderCol.width
                            height: Tokens.spacing.xl
                            spacing: Tokens.spacing.sm

                            MIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.more !== true
                                name: modelData.dir ? "folder" : "text-x-generic"
                                size: Tokens.icon.sm
                                color: modelData.dir ? Colors.color.primary : Colors.color.onSurfaceVariant
                            }
                            MText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - Tokens.icon.sm - parent.spacing)
                                value: modelData.name || ""
                                styleName: "bodyMedium"
                                elide: Text.ElideRight
                                color: modelData.dir ? Colors.color.onSurface : Colors.color.onSurfaceVariant
                            }
                        }
                    }
                }

                MText {
                    id: body
                    width: scroll.width
                    visible: !folderCol.visible
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
