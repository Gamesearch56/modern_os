import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property var rule: null
    property string comment: ""

    readonly property bool _valid: Firewall.commentOk(root.comment)

    titleKey: "settings.firewall.editTitle"
    confirmKey: "settings.save"
    cancelKey: "settings.cancel"
    confirmEnabled: root._valid && !Firewall.running
    onOpenChanged: {
        if (!root.open)
            return;
        root.comment = String(root.rule && root.rule.comment || "");
        if (commentField)
            commentField.editor.text = root.comment;
    }

    MField {
        labelKey: "settings.firewall.comment"
        MTextField {
            id: commentField
            maximumLength: 40
            onTextEdited: root.comment = commentField.text
        }
    }
}
