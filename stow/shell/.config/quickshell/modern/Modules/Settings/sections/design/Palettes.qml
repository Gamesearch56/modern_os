import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

GridLayout {
    id: root

    property string variant: "tonal-spot"
    property string mode: "dark"
    property string contrast: "standard"

    columns: 3
    rowSpacing: Tokens.spacing.sm
    columnSpacing: Tokens.spacing.sm
    Layout.fillWidth: true
    opacity: (Theme.busy || ThemePalettes.loading || ThemePalettes.key !== root.previewKey) ? 0.38 : 1
    enabled: !Theme.busy && !ThemePalettes.loading && ThemePalettes.key === root.previewKey

    readonly property var shown: ThemePalettes.palettes
    readonly property int rows: Math.ceil(root.shown.length / Math.max(1, columns))
    implicitHeight: root.rows > 0
        ? root.rows * (Tokens.spacing.xxl * 3 + Tokens.spacing.sm) + (root.rows - 1) * rowSpacing
        : 0

    readonly property string previewKey: String(Wallpaper.currentPath || "") + "|" + root.mode

    readonly property var titleKeys: ({
        "tonal-spot": "settings.themes.tonalSpot",
        "expressive": "settings.themes.expressive",
        "vibrant": "settings.themes.vibrant",
        "fidelity": "settings.themes.fidelity",
        "content": "settings.themes.content",
        "fruit-salad": "settings.themes.fruitSalad",
        "rainbow": "settings.themes.rainbow",
        "neutral": "settings.themes.neutral",
        "monochrome": "settings.themes.monochrome"
    })

    function _titleKey(v) {
        return root.titleKeys[String(v || "")] || "settings.themes.tonalSpot";
    }

    function _active(pal) {
        return String(pal.variant || "") === String(root.variant || "tonal-spot");
    }

    function _pick(pal) {
        const hex = String(pal && pal.seed || "");
        if (hex.length)
            Theme.pendingSeed = hex;
        Theme.selectSpec({
            variant: String(pal.variant || "tonal-spot"),
            mode: root.mode,
            contrast: root.contrast,
            sourceMode: "wallpaper"
        });
    }

    function _refresh() {
        ThemePalettes.refresh(Wallpaper.currentPath, root.mode);
    }

    onPreviewKeyChanged: root._refresh()
    Component.onCompleted: root._refresh()

    Repeater {
        model: root.shown

        Rectangle {
            id: card

            required property var modelData

            readonly property bool active: root._active(modelData)

            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.spacing.xxl * 3 + Tokens.spacing.sm
            radius: Tokens.radius.medium
            color: String(modelData.surface || Colors.color.surfaceContainer)
            border.width: card.active ? Tokens.stroke.focus : Tokens.stroke.hairline
            border.color: card.active ? Colors.color.primary : Colors.color.outlineVariant
            activeFocusOnTab: root.enabled
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t(root._titleKey(modelData.variant))
            Accessible.checkable: true
            Accessible.checked: card.active
            Accessible.onPressAction: root._pick(modelData)

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root._pick(modelData);
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.sm
                spacing: Tokens.spacing.xs

                MText {
                    key: root._titleKey(modelData.variant)
                    styleName: "labelLarge"
                    color: String(modelData.onSurface || Colors.color.onSurface)
                    Layout.fillWidth: true
                }

                MSwatchStrip {
                    Layout.fillWidth: true
                    colors: [modelData.primary, modelData.secondary, modelData.tertiary]
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                onPressed: ring.markPointer()
                onClicked: root._pick(modelData)
            }

            MFocusRing {
                id: ring
                radius: card.radius
            }
        }
    }
}
