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
            iconName: "text-x-generic"
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
