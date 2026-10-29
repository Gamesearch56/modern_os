import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property string role: ""
    property bool allowEmpty: false

    signal picked(string role, string id)

    readonly property var choices: Apps.entriesFor(root.role)
    readonly property string current: String((Config.apps.defaults && Config.apps.defaults[root.role]) || "")

    titleKey: root.role.length > 0 ? ("settings.fields." + root.role) : ""
    confirmKey: "settings.done"
    cancelKey: "settings.cancel"
    onCancelled: root.open = false
    onConfirmed: root.open = false

    function openRole(role: string, empty: bool) {
        root.role = role;
        root.allowEmpty = !!empty;
        root.open = true;
    }

    function _pick(id: string) {
        root.picked(root.role, id);
        root.open = false;
    }

    MListItem {
        visible: root.allowEmpty
        Layout.fillWidth: true
        iconName: "edit-clear-symbolic"
        titleKey: "settings.selectNone"
        selected: root.current.length === 0
        onClicked: root._pick("")
    }

    Repeater {
        model: root.choices
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            tintIcon: false
            preferSymbolic: false
            iconName: modelData.iconName || Apps.iconForId(modelData.value || "")
            titleValue: modelData.titleValue || ""
            selected: String(modelData.value || "") === root.current
            onClicked: root._pick(String(modelData.value || ""))
        }
    }
}
