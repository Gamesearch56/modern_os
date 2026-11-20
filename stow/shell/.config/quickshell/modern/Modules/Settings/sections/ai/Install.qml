import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property bool setupBusy: setup.setupBusy

    readonly property int focusStep: Ai.installed ? 1 : 0

    readonly property var steps: [
        { titleKey: "settings.ollama.step1Title", bodyKey: "settings.ollama.step1" },
        { titleKey: "settings.ollama.step2Title", bodyKey: "settings.ollama.step2" }
    ]

    AiStatus {
        id: setup
        visible: false
        ai: Ai
        onSetupFinished: (ok, model) => {
            if (ok && String(model || "").length)
                ConfigWrite.set("accounts.ai.ollamaModel", model);
        }
    }

    MSectionHeader {
        key: "settings.ollama.install"
        topMargin: Tokens.spacing.sm
    }

    MText {
        visible: !Ai.running || root.setupBusy
        key: {
            if (root.setupBusy)
                return "settings.ollama.setupWorking";
            return Ai.installed ? "settings.ollama.statusStopped" : "settings.ollama.statusMissing";
        }
        styleName: "titleSmall"
        color: Colors.color.primary
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }

    Repeater {
        model: root.steps
        Item {
            id: step
            required property var modelData
            required property int index
            readonly property bool hot: index === root.focusStep
            Layout.fillWidth: true
            implicitHeight: inner.implicitHeight + (step.hot ? Tokens.spacing.md * 2 : 0)

            Rectangle {
                visible: step.hot
                anchors.fill: parent
                radius: Tokens.radius.medium
                color: Colors.color.primaryContainer
                border.color: Colors.color.primary
                border.width: Tokens.stroke.focus
            }

            RowLayout {
                id: inner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: step.hot ? Tokens.spacing.sm : 0
                spacing: Tokens.spacing.md

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Tokens.icon.lg
                    Layout.preferredHeight: Tokens.icon.lg
                    radius: Tokens.radius.full
                    color: step.hot ? Colors.color.primary : Colors.color.primaryContainer

                    MText {
                        anchors.centerIn: parent
                        value: String(step.index + 1)
                        styleName: "labelLarge"
                        color: step.hot ? Colors.color.onPrimary : Colors.color.onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xxs

                    MText {
                        key: step.modelData.titleKey
                        styleName: "titleSmall"
                        color: step.hot ? Colors.color.onPrimaryContainer : Colors.color.onSurface
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                    MHint {
                        key: step.modelData.bodyKey
                        Layout.fillWidth: true
                    }
                    MButton {
                        visible: step.index === 0 && !Ai.installed
                        kind: "filled"
                        key: "settings.ollama.installPackage"
                        Layout.topMargin: Tokens.spacing.sm
                        onClicked: Store.showPackage("ollama")
                    }
                    MButton {
                        visible: step.index === 1 && Ai.installed
                        kind: "filled"
                        Layout.topMargin: Tokens.spacing.sm
                        busy: root.setupBusy
                        key: "settings.ollama.setup"
                        onClicked: setup.startSetup()
                    }
                    MHint {
                        visible: step.index === 1 && setup.setupFailed && !root.setupBusy
                        key: "settings.ollama.setupFailed"
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    JobOverlay {
        parent: Window.window ? Window.window.contentItem : root
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        action: setup.jobAction
        name: setup.jobName
        log: setup.jobLog
        state: setup.jobState
        onDismiss: setup.dismissJob()
    }
}
