// Step 3: every collected file with its size; unticked files stay home.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.xl

    readonly property alias scroll: files

    function _size(n: real): string {
        if (n >= 1e6)
            return I18n.t("units.mb", { n: (n / 1e6).toFixed(1) });
        if (n >= 1e3)
            return I18n.t("units.kb", { n: String(Math.round(n / 1e3)) });
        return I18n.t("units.b", { n: String(n) });
    }

    function _icon(name: string): string {
        const id = String(name || "").replace(/\.(txt|json)$/, "");
        switch (id) {
        case "quickshell":
        case "quickshell-log":
        case "quickshell-journal":
            return "applications-system";
        case "system":
        case "device":
            return "computer";
        case "hyprland":
        case "hyprland-log":
            return "preferences-system-windows";
        case "audio":
            return "audio-volume-high";
        case "bluetooth":
            return "bluetooth";
        case "network":
            return "network-wireless";
        case "games":
            return "input-gaming";
        case "apps":
            return "applications-other";
        case "update":
        case "update-log":
        case "pacman-log":
        case "install-log":
            return "system-software-update";
        case "boot":
        case "journal-previous-boot":
            return "system-reboot";
        case "hardware":
            return "drive-harddisk";
        case "session":
            return "system-lock-screen";
        case "config":
            return "preferences-system";
        case "doctor":
            return "utilities-system-monitor";
        case "failed-units":
            return "dialog-warning";
        case "coredumps":
            return "dialog-error";
        default:
            return "text-x-generic";
        }
    }

    MHint {
        Layout.fillWidth: true
        key: "bugReport.reviewHint"
    }

    MLinearProgress {
        Layout.fillWidth: true
        visible: BugReport.collecting
        indeterminate: true
    }

    MHint {
        visible: BugReport.collecting
        key: "bugReport.collecting"
    }

    ListView {
        id: files
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: !BugReport.collecting
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: false
        model: BugReport.files
        spacing: Tokens.spacing.xxs

        delegate: MListItem {
            required property var modelData
            width: ListView.view.width
            iconName: root._icon(modelData.name)
            preferSymbolic: false
            titleKey: "bugReport.files." + String(modelData.name).replace(/\.(txt|json)$/, "")
            subtitleValue: root._size(modelData.size)
            onClicked: BugReport.toggleFile(modelData.name)

            MIconButton {
                iconName: "document-open"
                key: "bugReport.view"
                onClicked: BugReport.view(modelData.path)
            }

            MSwitch {
                nameKey: "bugReport.files." + String(modelData.name).replace(/\.(txt|json)$/, "")
                checked: (BugReport.fileIncluded || {})[String(modelData.name)] !== false
                onToggled: BugReport.toggleFile(modelData.name)
            }
        }
    }
}
