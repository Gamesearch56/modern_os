import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property string policy: "allow"
    property string port: ""
    property string proto: ""
    property string direction: "in"
    property string from: ""
    property string comment: ""

    readonly property bool _valid: Firewall.portOk(root.port) && Firewall.fromOk(root.from) && Firewall.commentOk(root.comment)

    titleKey: root.policy === "deny" ? "settings.firewall.addDeny" : "settings.firewall.addAllow"
    bodyKey: "settings.firewall.addBody"
    confirmKey: "settings.firewall.add"
    cancelKey: "settings.cancel"
    confirmEnabled: root._valid && !Firewall.running
    onOpenChanged: {
        if (root.open)
            root._reset();
    }
    onConfirmed: {
        if (!root._valid)
            return;
        Firewall.add(root.policy, {
            port: root.port,
            proto: root.proto,
            direction: root.direction,
            from: root.from,
            comment: root.comment
        });
        root.open = false;
    }
    onCancelled: root.open = false

    function _reset() {
        root.port = "";
        root.proto = "";
        root.direction = "in";
        root.from = "";
        root.comment = "";
        if (portField)
            portField.editor.text = "";
        if (fromField)
            fromField.editor.text = "";
        if (commentField)
            commentField.editor.text = "";
    }

    MField {
        labelKey: "settings.firewall.port"
        MTextField {
            id: portField
            placeholderKey: "settings.firewall.portHint"
            onTextEdited: root.port = portField.text
        }
    }
    MField {
        labelKey: "settings.firewall.colProto"
        MSegmented {
            value: root.proto
            model: [
                { value: "", titleKey: "settings.firewall.protoAny" },
                { value: "tcp", titleKey: "settings.firewall.protoTcp" },
                { value: "udp", titleKey: "settings.firewall.protoUdp" }
            ]
            onSelected: (v) => root.proto = String(v)
        }
    }
    MField {
        labelKey: "settings.firewall.direction"
        MSegmented {
            value: root.direction
            model: [
                { value: "in", titleKey: "settings.firewall.dirIn" },
                { value: "out", titleKey: "settings.firewall.dirOut" }
            ]
            onSelected: (v) => root.direction = String(v)
        }
    }
    MField {
        labelKey: "settings.firewall.colFrom"
        MTextField {
            id: fromField
            placeholderKey: "settings.firewall.anywhere"
            onTextEdited: root.from = fromField.text
        }
    }
    MField {
        labelKey: "settings.firewall.comment"
        MTextField {
            id: commentField
            onTextEdited: root.comment = commentField.text
        }
    }
}
