import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property bool createOpen: themeLoader.item ? themeLoader.item.createOpen : false

    MSectionHeader { key: "settings.fields.activeProfile" }
    Loader {
        id: themeLoader
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("ThemePicker.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => themeLoader.width);
        }
    }

    MSectionHeader { key: "settings.fields.currentWallpaper" }
    MImageTile {
        Layout.preferredWidth: Tokens.spacing.xxl * 8
        Layout.preferredHeight: Tokens.spacing.xxl * 5
        source: Wallpaper.currentPath.length > 0 ? ("file://" + Wallpaper.currentPath) : ""
        selected: true
        onClicked: Wallpaper.pick()
    }
    MButton {
        kind: "tonal"
        key: "wallpaper.add"
        onClicked: Wallpaper.pick()
    }

    MSectionHeader { key: "settings.fields.typeScale" }
    MSlider {
        Layout.fillWidth: true
        from: 0.8
        to: 1.4
        value: Config.typography.scale
        showValue: true
        onMoved: (v) => ConfigWrite.set("typography.scale", Math.round(v * 100) / 100)
    }

    MSectionHeader { key: "settings.fields.chrome" }
    MField {
        labelKey: "settings.fields.transparency"
        MSlider {
            from: 0.4
            to: 1
            value: Config.design.transparency
            onMoved: (v) => ConfigWrite.set("design.transparency", Math.round(v * 100) / 100)
        }
    }
    MField {
        labelKey: "settings.fields.cornerRounding"
        MSlider {
            from: 0.5
            to: 1.5
            value: Config.design.cornerRounding
            onMoved: (v) => ConfigWrite.set("design.cornerRounding", Math.round(v * 100) / 100)
        }
    }
    MField {
        labelKey: "settings.fields.cursorTheme"
        MTextField {
            text: Config.design.cursorTheme ?? ""
            onAccepted: ConfigWrite.set("design.cursorTheme", text)
        }
    }
    MField {
        labelKey: "settings.fields.cursorSize"
        MSlider {
            from: 16
            to: 48
            value: Config.design.cursorSize ?? 24
            showValue: true
            onMoved: (v) => ConfigWrite.set("design.cursorSize", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.wallpaperColor"
        hintKey: "settings.hints.surfaceTint"
        MSlider {
            from: 0.5
            to: 2
            value: Config.design.surfaceTint ?? 1
            onMoved: (v) => ConfigWrite.set("design.surfaceTint", Math.round(v * 10) / 10)
        }
    }

    MSectionHeader {
        key: "settings.fields.animations"
        hintKey: "settings.hints.animations"
    }
    MSegmented {
        Layout.fillWidth: true
        value: String(Config.motion.scale)
        model: [
            { value: "0", titleKey: "settings.motionOff" },
            { value: "1", titleKey: "settings.motionDefault" },
            { value: "1.5", titleKey: "settings.motionSlow" }
        ]
        onSelected: (v) => ConfigWrite.set("motion.scale", Number(v))
    }

    MSectionHeader { key: "settings.fields.windowsChrome" }
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("Windows.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => width);
        }
    }
}
