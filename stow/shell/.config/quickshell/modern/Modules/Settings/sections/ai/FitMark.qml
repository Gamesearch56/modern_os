import QtQuick
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"

Item {
    id: root

    property string modelName: ""
    property var info: ({})

    implicitWidth: Tokens.icon.sm
    implicitHeight: Tokens.icon.sm

    readonly property string _level: String(root.info.level || "unknown")
    readonly property string _why: String(root.info.why || "unknown")
    readonly property color _color: {
        if (root._level === "good")
            return Colors.fitGood;
        if (root._level === "poor")
            return Colors.fitPoor;
        return Colors.fitMaybe;
    }
    readonly property string _key: {
        if (root._why === "gpu")
            return "settings.ollama.fitGoodGpu";
        if (root._why === "ram")
            return "settings.ollama.fitGoodRam";
        if (root._why === "spill")
            return "settings.ollama.fitSpill";
        if (root._why === "poor")
            return "settings.ollama.fitPoor";
        if (root._why === "tight")
            return "settings.ollama.fitTight";
        return "settings.ollama.fitUnknown";
    }
    readonly property var _params: ({
        need: root._gb(root.info.need),
        ram: root._gb(root.info.ram),
        vram: root._gb(root.info.vram)
    })

    function _gb(n): string {
        const v = Number(n) || 0;
        const label = v >= 10 ? String(Math.round(v)) : String(Math.round(v * 10) / 10);
        return I18n.t("units.gb", { n: label });
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: I18n.t(root._key, root._params)

    Rectangle {
        anchors.centerIn: parent
        width: Tokens.icon.sm
        height: width
        radius: width / 2
        color: root._color
        opacity: hover.containsMouse ? 0.22 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: Tokens.spacing.sm
        height: width
        radius: width / 2
        color: root._color
        opacity: hover.containsMouse ? 1 : 0.55
        scale: hover.containsMouse ? 1.2 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.WhatsThisCursor
        onContainsMouseChanged: tip.open = hover.containsMouse
    }

    Item {
        id: tipHost
        width: 0
        height: 0
        visible: false
    }

    Item {
        id: tip
        property bool open: false
        parent: tip.open && Window.window ? Window.window.contentItem : tipHost
        visible: tip.open
        z: 240
        width: Tokens.spacing.xxl * 9
        height: tipCard.implicitHeight
        x: {
            if (!tip.open || !Window.window)
                return 0;
            const host = Window.window.contentItem;
            const origin = root.mapToItem(host, 0, 0);
            const max = host.width - tip.width - Tokens.spacing.md;
            return Math.max(Tokens.spacing.md, Math.min(origin.x, max));
        }
        y: {
            if (!tip.open || !Window.window)
                return 0;
            const host = Window.window.contentItem;
            const origin = root.mapToItem(host, 0, 0);
            let raw = origin.y - tip.height - Tokens.spacing.xs;
            if (raw < Tokens.spacing.md)
                raw = origin.y + root.height + Tokens.spacing.xs;
            return raw;
        }

        Rectangle {
            id: tipCard
            width: parent.width
            implicitHeight: tipText.implicitHeight + Tokens.spacing.sm * 2
            radius: Tokens.radius.medium
            color: Colors.color.surfaceContainerHighest
            border.color: Colors.color.outlineVariant
            border.width: Tokens.stroke.hairline

            MText {
                id: tipText
                x: Tokens.spacing.sm
                y: Tokens.spacing.sm
                width: parent.width - Tokens.spacing.sm * 2
                key: root._key
                params: root._params
                styleName: "bodySmall"
                color: Colors.color.onSurface
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }
}
