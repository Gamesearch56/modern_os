import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MStatusCard {
    id: root

    iconName: "preferences-security-firewall"
    preferSymbolic: false
    iconColor: Colors.color.primary
    titleKey: "settings.firewall.engine"
    subtitleKey: {
        if (Firewall.status === "active")
            return "settings.firewall.active";
        if (Firewall.status === "inactive")
            return "settings.firewall.inactive";
        if (Firewall.status === "missing")
            return "settings.firewall.missing";
        return "";
    }

    trailing: Loader {
        active: Firewall.status === "missing"
        visible: active
        sourceComponent: Component {
            MButton {
                kind: "filled"
                key: "store.title"
                onClicked: Store.showQuery("ufw")
            }
        }
    }

    MHint {
        visible: Firewall.status === "active" || Firewall.status === "inactive"
            || Firewall.status === "missing"
        key: {
            if (Firewall.status === "active")
                return "settings.hints.firewallActive";
            if (Firewall.status === "inactive")
                return "settings.hints.firewallInactive";
            return "settings.hints.firewallMissing";
        }
        Layout.fillWidth: true
    }
}
