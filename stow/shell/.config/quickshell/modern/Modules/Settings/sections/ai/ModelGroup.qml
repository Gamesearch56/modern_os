import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "."

ColumnLayout {
    id: root

    property string family: ""
    property string desc: ""
    property string use: "chat"
    property var also: []
    property var tags: []
    property var fit: ({})
    property bool expanded: false
    property string busyName: ""
    property bool canInstall: false

    signal toggled()
    signal install(string name)
    signal askRemove(string name)

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    function _disk(bytes): string {
        const n = Number(bytes || 0);
        if (!(n > 0))
            return "";
        const gb = n / (1024 * 1024 * 1024);
        if (gb >= 1) {
            const label = gb >= 10 ? String(Math.round(gb)) : String(Math.round(gb * 10) / 10);
            return I18n.t("units.gb", { n: label });
        }
        return I18n.t("units.mb", { n: String(Math.max(1, Math.round(n / (1024 * 1024)))) });
    }

    function _familyUse(): string {
        const kind = root.use || "chat";
        let text = I18n.t("settings.ollama.use.chat");
        if (kind === "code")
            text = I18n.t("settings.ollama.use.code");
        else if (kind === "vision")
            text = I18n.t("settings.ollama.use.vision");
        else if (kind === "reason")
            text = I18n.t("settings.ollama.use.reason");
        else if (kind === "embed")
            text = I18n.t("settings.ollama.use.embed");
        else if (kind === "ocr")
            text = I18n.t("settings.ollama.use.ocr");
        else if (kind === "translate")
            text = I18n.t("settings.ollama.use.translate");
        else if (kind === "open")
            text = I18n.t("settings.ollama.use.open");
        const extra = root.also || [];
        for (let i = 0; i < extra.length; i++) {
            if (extra[i] === "think")
                text += " " + I18n.t("settings.ollama.use.alsoThink");
            else if (extra[i] === "tools")
                text += " " + I18n.t("settings.ollama.use.alsoTools");
            else if (extra[i] === "vision")
                text += " " + I18n.t("settings.ollama.use.alsoVision");
        }
        return text;
    }

    readonly property bool hasModels: (root.tags || []).length > 0
    readonly property bool _anyInstalled: {
        const list = root.tags || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].installed)
                return true;
        }
        return false;
    }

    Item {
        id: head
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.family
        Accessible.onPressAction: root.toggled()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.toggled();
                event.accepted = true;
            }
        }

        RowLayout {
            id: header
            width: parent.width
            spacing: Tokens.spacing.lg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xxs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    MIcon {
                        visible: root.hasModels
                        name: root.expanded ? "go-down" : "go-next"
                        size: Tokens.icon.sm
                        color: Colors.color.onSurfaceVariant
                    }
                    MText {
                        value: root.family
                        styleName: "titleSmall"
                        color: Colors.color.onSurface
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                MText {
                    value: root._familyUse()
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 4
                    Layout.fillWidth: true
                    Layout.leftMargin: root.hasModels ? Tokens.icon.sm + Tokens.spacing.xs : 0
                }
            }

            Rectangle {
                visible: root._anyInstalled
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Tokens.spacing.md
                Layout.preferredHeight: Tokens.spacing.md
                radius: Tokens.radius.full
                color: Colors.fitGood
                Accessible.role: Accessible.StaticText
                Accessible.name: I18n.t("settings.ollama.hasSize")
            }
            Item {
                visible: root.hasModels
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                Layout.preferredWidth: Tokens.spacing.xxl

                MText {
                    anchors.fill: parent
                    value: String((root.tags || []).length)
                    styleName: "labelMedium"
                    color: Colors.color.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }

    Repeater {
        model: root.expanded && root.hasModels ? root.tags.length : 0
        delegate: RowLayout {
            required property int index
            readonly property var modelData: root.tags[index] || ({})
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.spacing.lg
            spacing: Tokens.spacing.xs

            FitMark {
                modelName: modelData.name
                info: root.fit[modelData.name] || ({})
                Layout.alignment: Qt.AlignVCenter
            }
            MText {
                value: modelData.label
                styleName: "bodyMedium"
                color: Colors.color.onSurface
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            MText {
                visible: root._disk(modelData.bytes).length > 0
                value: root._disk(modelData.bytes)
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                // Same box for the label and the button, so selecting a model does not shift the row.
                Layout.preferredWidth: Math.max(action.implicitWidth, useLabel.implicitWidth)
                Layout.preferredHeight: action.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                MButton {
                    id: action
                    opacity: modelData.inUse ? 0 : 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    kind: modelData.installed ? "text" : "filled"
                    key: modelData.installed ? "settings.ollama.deleteModel" : "settings.ollama.installModel"
                    busy: root.busyName === modelData.name
                    enabled: !modelData.inUse && !root.busyName.length && (modelData.installed || root.canInstall)
                    onClicked: {
                        if (modelData.installed)
                            root.askRemove(modelData.name);
                        else
                            root.install(modelData.name);
                    }
                }
                MText {
                    id: useLabel
                    opacity: modelData.inUse ? 1 : 0
                    anchors.fill: parent
                    key: "settings.ollama.inUse"
                    styleName: "labelMedium"
                    color: Colors.color.primary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
