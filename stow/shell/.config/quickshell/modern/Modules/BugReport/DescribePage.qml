// Step 1: what happened, in the user's words, plus a few quick choices.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Flickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: root.width
        spacing: Tokens.spacing.xl

        MField {
            spacing: Tokens.spacing.sm
            labelKey: "bugReport.summary"
            labelExtra: HelpButton {
                id: summaryHelp
                nameKey: "bugReport.summaryHelp"
                bodyKey: "bugReport.summaryHelpBody"
                onOpened: stepsHelp.close()
            }

            MTextField {
                id: summary
                maximumLength: 120
                text: BugReport.title
                onTextEdited: BugReport.title = summary.text
                Component.onCompleted: summary.editor.forceActiveFocus()
            }
        }

        MField {
            spacing: Tokens.spacing.sm
            labelKey: "bugReport.steps"
            labelExtra: HelpButton {
                id: stepsHelp
                nameKey: "bugReport.stepsHelp"
                bodyKey: "bugReport.stepsHelpBody"
                onOpened: summaryHelp.close()
            }

            MTextArea {
                text: BugReport.description
                onTextEdited: BugReport.description = text
            }
        }

        ChoiceRow {
            Layout.fillWidth: true
            labelKey: "bugReport.area"
            keyPrefix: "bugReport.areas."
            options: BugReport.areas
            selected: BugReport.categories
            onPicked: id => BugReport.toggleCategory(id)
        }

        ChoiceRow {
            Layout.fillWidth: true
            labelKey: "bugReport.when"
            keyPrefix: "bugReport.whenOptions."
            options: ["now", "today", "earlier"]
            selected: [BugReport.when]
            onPicked: id => BugReport.when = id
        }

        ChoiceRow {
            Layout.fillWidth: true
            labelKey: "bugReport.repeat"
            keyPrefix: "bugReport.repeatOptions."
            options: ["always", "sometimes", "once"]
            selected: [BugReport.repeat]
            onPicked: id => BugReport.repeat = BugReport.repeat === id ? "" : id
        }
    }
}
