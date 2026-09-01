import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MStatusCard {
    id: root

    signal setupRequested()

    iconName: "document-save"
    preferSymbolic: false
    iconColor: Colors.color.primary
    titleKey: "settings.backup.engine"
    subtitleKey: {
        if (Snapshots.status === "ready")
            return "settings.backup.ready";
        if (Snapshots.status === "unconfigured")
            return "settings.backup.unconfigured";
        if (Snapshots.status === "missing")
            return "settings.backup.missing";
        return "";
    }

    trailing: Loader {
        active: Snapshots.status === "missing" || Snapshots.status === "unconfigured"
        visible: active
        sourceComponent: Component {
            MButton {
                kind: "filled"
                key: Snapshots.status === "missing" ? "store.title" : "settings.backup.setup"
                enabled: !Snapshots.running
                onClicked: {
                    if (Snapshots.status === "missing")
                        Store.showQuery("snapper");
                    else
                        root.setupRequested();
                }
            }
        }
    }

    MHint {
        visible: Snapshots.status === "ready" || Snapshots.status === "unconfigured"
            || Snapshots.status === "missing"
        key: {
            if (Snapshots.status === "ready")
                return "settings.hints.snapperReady";
            if (Snapshots.status === "unconfigured")
                return "settings.hints.snapperUnconfigured";
            return "settings.hints.snapperMissing";
        }
        Layout.fillWidth: true
    }
}
