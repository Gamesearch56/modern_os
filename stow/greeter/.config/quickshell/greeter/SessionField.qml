// Accessible filled field. Mirrors Widgets/MTextField without importing
// the desktop package (greeter user has no view of that stow prefix).
import QtQuick

Item {
    id: root

    property var chrome: null
    property alias text: input.text
    property string placeholder: ""
    property int echoMode: TextInput.Normal
    property bool enabled: true
    property bool tabFocus: true
    property bool capsOn: false

    signal accepted()
    signal textEdited()

    readonly property bool _focused: input.activeFocus
    readonly property var _c: root.chrome

    implicitHeight: root._c ? root._c.fieldHeight : 36
    implicitWidth: root._c ? root._c.formWidth : 384
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled && root.tabFocus
    Accessible.role: root.echoMode === TextInput.Password
        ? Accessible.PasswordEdit
        : Accessible.EditableText
    Accessible.name: root.placeholder
    Accessible.editable: true
    Accessible.onPressAction: {
        if (root.enabled)
            input.forceActiveFocus();
    }

    function forceActiveFocus() {
        input.forceActiveFocus();
    }

    function selectAll() {
        input.selectAll();
    }

    function _noteCaps(event: var) {
        if (event.key === Qt.Key_CapsLock) {
            root.capsOn = !root.capsOn;
            return;
        }
        const t = event.text || "";
        if (t.length !== 1)
            return;
        const lower = t.toLowerCase();
        const upper = t.toUpperCase();
        if (lower === upper)
            return;
        const shift = !!(event.modifiers & Qt.ShiftModifier);
        root.capsOn = (t === upper) !== shift;
    }

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.IBeamCursor
    }

    onActiveFocusChanged: {
        if (root.activeFocus && !input.activeFocus)
            input.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        radius: root._c ? root._c.radiusFull : 9999
        color: root._c ? root._c.color.surfaceContainerHighest : "#36343B"
        border.color: root._focused
            ? (root._c ? root._c.color.primary : "#D0BCFF")
            : (root._c ? root._c.color.outline : "#938F99")
        border.width: root._focused
            ? (root._c ? root._c.strokeFocus : 2)
            : (root._c ? root._c.strokeHairline : 1)
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root._c ? root._c.spaceMd : 12
        anchors.rightMargin: root._c ? root._c.spaceMd : 12
        verticalAlignment: TextInput.AlignVCenter
        color: root._c ? root._c.color.onSurface : "#E6E0E9"
        selectionColor: root._c ? root._c.color.primary : "#D0BCFF"
        selectedTextColor: root._c ? root._c.color.onPrimary : "#381E72"
        font.family: root._c ? root._c.fontFamily : "sans-serif"
        font.pixelSize: root._c ? root._c.typePx("bodyLarge") : 16
        echoMode: root.echoMode
        enabled: root.enabled
        activeFocusOnTab: false
        selectByMouse: true
        activeFocusOnPress: root.enabled
        clip: true
        onAccepted: root.accepted()
        onTextChanged: root.textEdited()
        Keys.onPressed: (event) => root._noteCaps(event)
    }

    Text {
        visible: input.text.length === 0 && !input.activeFocus
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        text: root.placeholder
        color: root._c ? root._c.color.onSurfaceVariant : "#CAC4D0"
        font.family: root._c ? root._c.fontFamily : "sans-serif"
        font.pixelSize: root._c ? root._c.typePx("bodyLarge") : 16
        Accessible.ignored: true
    }
}
