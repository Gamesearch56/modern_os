import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property bool setupBusy: setup.setupBusy

    readonly property int focusStep: {
        if (!Ai.installed)
            return 0;
        if (!Ai.running)
            return 1;
        if ((Ai.models || []).length === 0)
            return 2;
        return 3;
    }

    readonly property var steps: [
        { titleKey: "settings.ollama.step1Title", bodyKey: "settings.ollama.step1", cmdKey: "settings.ollama.step1Cmd" },
        { titleKey: "settings.ollama.step2Title", bodyKey: "settings.ollama.step2", cmdKey: "settings.ollama.step2Cmd" },
        { titleKey: "settings.ollama.step3Title", bodyKey: "settings.ollama.step3", cmdKey: "settings.ollama.step3Cmd" },
        { titleKey: "settings.ollama.step4Title", bodyKey: "settings.ollama.step4", cmdKey: "" }
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
                    MText {
                        visible: (step.modelData.cmdKey || "").length > 0
                        key: step.modelData.cmdKey
                        styleName: "bodySmall"
                        familyRole: "monospace"
                        color: Colors.color.onSurfaceVariant
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        Layout.fillWidth: true
                    }
                    MButton {
                        visible: step.index === 0 && !Ai.installed
                        kind: "filled"
                        key: "settings.ollama.openStore"
                        onClicked: Store.showPackage("ollama")
                    }
                    MButton {
                        visible: step.index === 1 && Ai.installed
                        kind: "filled"
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
}
