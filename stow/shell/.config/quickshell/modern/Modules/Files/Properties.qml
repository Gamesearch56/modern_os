import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    anchors.fill: parent
    open: Files.propertiesOpen
    titleKey: "files.properties.title"
    confirmKey: "files.properties.save"
    cancelKey: "files.cancel"
    confirmEnabled: (FilesAccess.info.canChmod === true) || root._owner.length > 0 || root._renamed || root._groupChanged
    onCancelled: Files.propertiesOpen = false
    onConfirmed: root._save()

    Flickable {
        id: formScroll
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(form.implicitHeight, root._room)
        contentWidth: width
        contentHeight: form.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: form
            width: formScroll.width
            spacing: Tokens.spacing.sm
        MText { key: "files.details.name" }
        MTextField {
            id: nameField
            Layout.fillWidth: true
            onTextEdited: root._name = nameField.text
            onActiveFocusChanged: Files.typing = focused
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.preferredWidth: Tokens.spacing.xxl * 3; Layout.preferredHeight: Tokens.spacing.md }
            MText { key: "files.properties.read"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; styleName: "bodySmall"; color: Colors.color.onSurfaceVariant }
            MText { key: "files.properties.write"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; styleName: "bodySmall"; color: Colors.color.onSurfaceVariant }
            MText { key: "files.properties.execute"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; styleName: "bodySmall"; color: Colors.color.onSurfaceVariant }
        }

        Repeater {
            model: [
                { key: "files.properties.user", at: 0 },
                { key: "files.properties.group", at: 3 },
                { key: "files.properties.others", at: 6 }
            ]
            delegate: RowLayout {
                id: band
                required property var modelData
                Layout.fillWidth: true
                MText { key: band.modelData.key; Layout.preferredWidth: Tokens.spacing.xxl * 3 }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: readBit.implicitHeight
                    MSwitch { id: readBit; anchors.horizontalCenter: parent.horizontalCenter; compact: true; checked: root._bit(band.modelData.at); enabled: FilesAccess.info.canChmod === true; onToggled: (v) => root._setBit(band.modelData.at, v) }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: writeBit.implicitHeight
                    MSwitch { id: writeBit; anchors.horizontalCenter: parent.horizontalCenter; compact: true; checked: root._bit(band.modelData.at + 1); enabled: FilesAccess.info.canChmod === true; onToggled: (v) => root._setBit(band.modelData.at + 1, v) }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: execBit.implicitHeight
                    MSwitch { id: execBit; anchors.horizontalCenter: parent.horizontalCenter; compact: true; checked: root._bit(band.modelData.at + 2); enabled: FilesAccess.info.canChmod === true; onToggled: (v) => root._setBit(band.modelData.at + 2, v) }
                }
            }
        }

        MText { key: "files.properties.setuid"; visible: FilesAccess.info.setuid === true }
        MText { key: "files.properties.setgid"; visible: FilesAccess.info.setgid === true }
        MText { key: "files.properties.sticky"; visible: FilesAccess.info.sticky === true }

        MText { key: "files.properties.group" }
        MSelect {
            Layout.fillWidth: true
            enabled: FilesAccess.info.canChgrp === true
            model: root._groups
            value: root._group
            onSelected: (chosen) => { root._group = String(chosen || ""); }
        }

        MText { key: "files.properties.changeOwner"; visible: FilesAccess.info.canChown === true }
        MTextField {
            id: owner
            visible: FilesAccess.info.canChown === true
            Layout.fillWidth: true
            placeholderKey: "files.properties.owner"
            text: FilesAccess.info.owner || ""
            onTextEdited: root._owner = owner.text
            onActiveFocusChanged: Files.typing = focused
        }
        }
    }

    // Leave room for the title and the actions so they stay on screen.
    readonly property real _room: Math.max(Tokens.spacing.xxl * 6, root.height - Tokens.spacing.xxl * 6)
    property string _bits: "000000000"
    property string _owner: ""
    property string _name: ""
    property string _group: ""
    readonly property bool _renamed: root._name.length > 0 && root._name !== String(FilesAccess.info.name || "")
    readonly property bool _groupChanged: root._group.length > 0 && root._group !== String(FilesAccess.info.group || "")
    readonly property var _groups: {
        const info = FilesAccess.info || {};
        const rows = info.groups || [];
        const out = [];
        const seen = {};
        const current = String(info.group || "");
        if (current.length) {
            out.push({ value: current, titleValue: current });
            seen[current] = true;
        }
        for (let i = 0; i < rows.length; i++) {
            const name = String(rows[i] || "");
            if (!name.length || seen[name])
                continue;
            seen[name] = true;
            out.push({ value: name, titleValue: name });
        }
        return out;
    }

    function _bit(index: int): bool {
        return root._bits.charAt(index) === "1";
    }

    function _setBit(index: int, on: bool) {
        const chars = root._bits.split("");
        chars[index] = on ? "1" : "0";
        root._bits = chars.join("");
    }

    function _save() {
        const info = FilesAccess.info || {};
        const name = root._renamed ? root._name : "";
        const bits = info.canChmod === true ? root._bits : "";
        const owner = (root._owner.length && info.canChown === true && root._owner !== info.owner) ? root._owner : "";
        const group = root._groupChanged && info.canChgrp === true ? root._group : "";
        if (group.length && info.path)
            FilesAccess.saveGroup(String(info.path), group);
        if ((name.length || bits.length || owner.length) && info.path)
            FilesAccess.save(String(info.path), name, bits, owner);
        Files.propertiesOpen = false;
    }

    Connections {
        target: FilesAccess
        function onInfoChanged() {
            root._bits = String(FilesAccess.info.bits || "000000000");
            root._owner = "";
            root._name = String(FilesAccess.info.name || "");
            root._group = String(FilesAccess.info.group || "");
            nameField.text = root._name;
        }
        function onSaved() { Files.refresh(); }
        function onFailed(reason) {
            Files.failed(reason);
        }
    }
}
