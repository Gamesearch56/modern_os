import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MStatusCard {
    id: root

    iconName: "document-save"
    preferSymbolic: false
    iconColor: Colors.color.primary
    titleKey: "settings.backup.engine"
    subtitleKey: {
        if (Snapshots.status === "ready")
            return "settings.backup.ready";
        if (Snapshots.status === "unconfigured")
            return "settings.backup.unconfigured";
        return "settings.backup.missing";
    }

    MHint {
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
