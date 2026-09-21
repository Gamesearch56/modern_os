import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property bool sink: true
    property string draft: ""

    titleKey: root.sink ? "audio.fallbackOutputTitle" : "audio.fallbackInputTitle"
    bodyKey: root.sink ? "audio.fallbackOutputBody" : "audio.fallbackInputBody"
    confirmKey: "settings.save"
    cancelKey: "settings.cancel"
    onOpenChanged: {
        if (!root.open)
            return;
        root.draft = String(root.sink
            ? (Config.audio.fallbackSink || "")
            : (Config.audio.fallbackSource || ""));
    }
    onConfirmed: {
        ConfigWrite.set(root.sink ? "audio.fallbackSink" : "audio.fallbackSource", root.draft);
        root.open = false;
    }
    onCancelled: root.open = false

    function _model(): var {
        const out = [];
        const list = root.sink ? Audio.sinks : Audio.sources;
        for (let i = 0; i < list.length; i++) {
            if (Audio.isBluetoothNode(list[i]))
                continue;
            const key = Audio.nodeKey(list[i]);
            if (!key.length)
                continue;
            out.push({ value: key, titleValue: Audio.nodeLabel(list[i]) });
        }
        return out;
    }

    MSelect {
        Layout.fillWidth: true
        allowEmpty: true
        emptyValue: ""
        emptyKey: "settings.selectNone"
        value: root.draft
        model: {
            void Audio.sinks.length;
            void Audio.sources.length;
            return root._model();
        }
        placeholderKey: root.sink ? "audio.noOutputs" : "audio.noInputs"
        onSelected: (v) => root.draft = String(v ?? "")
    }
}
