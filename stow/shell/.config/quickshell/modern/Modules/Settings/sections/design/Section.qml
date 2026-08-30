import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    readonly property var motionChoices: [
        { value: "0", titleKey: "settings.motionOff" },
        { value: "1", titleKey: "settings.motionDefault" },
        { value: "1.5", titleKey: "settings.motionSlow" }
    ]

    MSectionHeader {
        key: "settings.fields.currentWallpaper"
        topMargin: 0
    }
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("Gallery.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => width);
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
        key: "settings.fields.activeProfile"
        hintKey: "settings.hints.activeProfile"
        topMargin: Tokens.spacing.xxl
    }
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("ThemePicker.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => width);
        }
    }

    MSectionHeader {
        key: "settings.fields.typeScale"
        topMargin: Tokens.spacing.xxl
    }
    MSlider {
        Layout.fillWidth: true
        from: 0.8
        to: 1.4
        value: Config.typography.scale
        showValue: true
        onMoved: (v) => ConfigWrite.set("typography.scale", Math.round(v * 100) / 100)
    }

    MSectionHeader {
        key: "settings.fields.animations"
        hintKey: "settings.hints.animations"
        topMargin: Tokens.spacing.xxl
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.animations"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.motionChoices
            value: String(Config.motion.scale)
            onSelected: (v) => ConfigWrite.set("motion.scale", Number(v))
        }
    }

    MSectionHeader {
        key: "settings.fields.cursor"
        topMargin: Tokens.spacing.xxl
    }
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("Cursor.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => width);
        }
    }

    MSectionHeader {
        id: windowsHeader
        key: "settings.fields.windowsChrome"
        topMargin: Tokens.spacing.xxl
    }
    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        source: Qt.resolvedUrl("Windows.qml")
        onLoaded: {
            if (item)
                item.width = Qt.binding(() => width);
        }
    }

    function _flickable() {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    function _scrollToWindows() {
        if (Settings.subsectionId !== "windows")
            return;
        if (windowsHeader.height <= 0)
            return;
        const flick = root._flickable();
        if (!flick)
            return;
        const pos = windowsHeader.mapToItem(flick.contentItem, 0, 0);
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.min(maxY, Math.max(0, pos.y - Tokens.spacing.md));
        Settings.subsectionId = "";
    }

    Connections {
        target: Settings
        function onSubsectionIdChanged() { Qt.callLater(root._scrollToWindows); }
    }

    onImplicitHeightChanged: Qt.callLater(root._scrollToWindows)
}
