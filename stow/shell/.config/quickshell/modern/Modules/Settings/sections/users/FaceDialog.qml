import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property string _draft: ""
    property bool _saving: false

    readonly property string _name: {
        const slash = root._draft.lastIndexOf("/");
        return slash >= 0 ? root._draft.slice(slash + 1) : root._draft;
    }

    wide: true
    titleKey: "settings.users.chooseFace"
    confirmKey: "settings.users.faceSave"
    confirmEnabled: root._draft.length > 0 && crop.ready && !User.faceBusy
    destructiveKey: User.hasFace ? "settings.users.clearFace" : ""

    onOpenChanged: {
        if (!root.open)
            return;
        root._draft = "";
        root._saving = false;
        crop.reset();
    }
    onConfirmed: {
        const spec = crop.box();
        if (!spec.length)
            return;
        root._saving = true;
        User.applyFace(root._draft, String(crop.turn * 90), spec);
    }
    onCancelled: {
        if (root._saving)
            return;
        root.open = false;
    }
    onDestructiveClicked: {
        User.clearFace();
        root.open = false;
    }

    Connections {
        target: FilesChoose
        function onChosen(path, who) {
            if (who !== "face" || !root.open)
                return;
            root._draft = String(path || "");
            crop.reset();
            crop.source = root._url(root._draft);
        }
    }

    Connections {
        target: User
        function onFaceBusyChanged() {
            if (User.faceBusy || !root._saving)
                return;
            root._saving = false;
            if (User.faceError.length === 0 && User.hasFace)
                root.open = false;
        }
    }

    function _url(path: string): string {
        const text = String(path || "");
        return text.length ? ("file://" + encodeURI(text)) : "";
    }

    ColumnLayout {
        spacing: Tokens.spacing.md
        Layout.fillWidth: true

        Item {
            id: field
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: root._name.length ? root._name : I18n.t("settings.users.facePick")
            Accessible.onPressAction: FilesChoose.ask(XdgDirs.pictures, "image", "face")
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    FilesChoose.ask(XdgDirs.pictures, "image", "face");
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.full
                color: Colors.color.surfaceContainerHighest
                border.color: field.activeFocus ? Colors.color.primary : Colors.color.outline
                border.width: field.activeFocus ? Tokens.stroke.focus : Tokens.stroke.hairline
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing.md
                anchors.rightMargin: Tokens.spacing.md
                spacing: Tokens.spacing.sm

                MIcon {
                    name: "insert-image-symbolic"
                    size: Tokens.icon.sm
                    color: Colors.color.onSurfaceVariant
                    tint: true
                }
                MText {
                    Layout.fillWidth: true
                    key: root._name.length === 0 ? "settings.users.facePick" : ""
                    value: root._name
                    color: root._name.length === 0 ? Colors.color.onSurfaceVariant : Colors.color.onSurface
                    elide: Text.ElideMiddle
                }
                MIcon {
                    name: "go-down"
                    size: Tokens.icon.sm
                    color: Colors.color.onSurfaceVariant
                    tint: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: FilesChoose.ask(XdgDirs.pictures, "image", "face")
            }
        }

        FaceCrop {
            id: crop
            visible: root._draft.length > 0
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            visible: root._draft.length > 0
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.sm

            MIconButton {
                iconName: "object-rotate-left-symbolic"
                key: "settings.users.faceRotateLeft"
                tip: true
                onClicked: { crop.turn = (crop.turn + 3) % 4; crop.panX = 0; crop.panY = 0; }
            }
            MIconButton {
                iconName: "object-rotate-right-symbolic"
                key: "settings.users.faceRotateRight"
                tip: true
                onClicked: { crop.turn = (crop.turn + 1) % 4; crop.panX = 0; crop.panY = 0; }
            }
        }

        MText {
            visible: root._draft.length > 0
            key: "settings.users.faceResize"
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MSlider {
            visible: root._draft.length > 0
            Layout.fillWidth: true
            from: 1
            to: 3
            value: crop.zoom
            onMoved: (next) => { crop.zoom = next; }
        }
        MHint {
            visible: root._draft.length > 0
            key: "settings.users.faceHint"
            Layout.fillWidth: true
        }
        MLinearProgress {
            visible: root._saving
            Layout.fillWidth: true
            indeterminate: true
        }
        MText {
            visible: root._saving
            key: "settings.users.faceSaving"
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            visible: User.faceError.length > 0 && !root._saving
            key: User.faceError.length > 0 ? User.faceError : "settings.users.faceFailed"
            styleName: "bodySmall"
            color: Colors.color.error
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
