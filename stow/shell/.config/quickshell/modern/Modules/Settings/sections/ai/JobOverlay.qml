// Install and remove log. Stays up when finished so the result can be read.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"

Item {
    id: root

    property string action: ""
    property string name: ""
    property string log: ""
    property string state: ""

    readonly property bool open: root.state === "run" || root.state === "ok" || root.state === "fail"
    readonly property bool running: root.state === "run"
    readonly property bool showLog: root.action !== "remove" && root.log.trim().length > 0
    readonly property string titleKey: {
        if (root.state === "fail")
            return "settings.ollama.jobFailed";
        if (root.state === "ok")
            return root.action === "remove" ? "settings.ollama.removed" : "settings.ollama.installed";
        return root.action === "remove" ? "settings.ollama.removing" : "settings.ollama.installing";
    }

    signal dismiss()

    visible: root.open || scrim.opacity > 0
    enabled: root.open
    z: 120

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root.open ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.running
            onClicked: root.dismiss()
        }
    }

    MText {
        id: titleMeasure
        key: root.titleKey
        params: ({ name: root.name })
        styleName: "headlineSmall"
        visible: false
    }

    MCard {
        level: 0
        color: Colors.color.surface
        borderWidth: Tokens.stroke.hairline
        borderColor: Colors.color.outlineVariant
        width: {
            const cap = parent.width - Tokens.spacing.xxl;
            if (root.showLog)
                return Math.min(cap, Tokens.spacing.xxl * 14);
            const need = titleMeasure.implicitWidth + Tokens.spacing.lg * 2;
            return Math.min(cap, Math.max(Tokens.spacing.xxl * 11, Math.min(need, Tokens.spacing.xxl * 16)));
        }
        implicitHeight: col.implicitHeight + padding * 2
        anchors.centerIn: parent
        scale: Motion.overlayScale(root.open)
        opacity: Motion.overlayOpacity(root.open)

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root.open ? Motion.easingEmphasizedDecelerate : Motion.easingEmphasizedAccelerate
            }
        }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Tokens.spacing.md

            MText {
                key: root.titleKey
                params: ({ name: root.name })
                styleName: "headlineSmall"
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                Layout.fillWidth: true
            }

            MLinearProgress {
                visible: root.running
                Layout.fillWidth: true
                indeterminate: true
            }

            MLogView {
                visible: root.showLog
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.spacing.xxl * 8
                text: root.log.trim()
                textColor: root.state === "fail" ? Colors.color.error : Colors.color.onSurfaceVariant
            }

            RowLayout {
                visible: root.showLog || !root.running
                Layout.alignment: Qt.AlignRight
                spacing: Tokens.spacing.sm

                MButton {
                    visible: root.showLog
                    kind: "outlined"
                    key: "store.copyLog"
                    onClicked: Quickshell.clipboardText = root.log.trim()
                }

                MButton {
                    visible: !root.running
                    kind: "filled"
                    key: "bar.close"
                    onClicked: root.dismiss()
                }
            }
        }
    }
}
