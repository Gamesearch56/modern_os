// Settings page chrome: group cap + section title, Restore on the
// right when Catalog lists restore paths for this page.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property var catalog
    property bool restoreOpen: false
    property bool _awaiting: false

    readonly property var _paths: {
        const c = root.catalog;
        if (!c || typeof c.restorePaths !== "function")
            return [];
        return c.restorePaths(Settings.sectionId) || [];
    }
    readonly property string _name: I18n.t("settings.sections." + Settings.sectionId)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.fillWidth: true

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Tokens.spacing.md

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xxs

        MText {
            key: "settings.nav." + ((root.catalog && root.catalog.group(Settings.sectionId)) || "general")
            styleName: "labelSmall"
            color: Colors.color.onSurfaceVariant
            font.capitalization: Font.AllUppercase
        }

        MText {
            key: "settings.sections." + Settings.sectionId
            styleName: "headlineSmall"
            Layout.fillWidth: true
        }
    }

    MButton {
        visible: Settings.sectionId === "storage"
        kind: "tonal"
        key: "settings.storage.clean"
        enabled: !StorageClean.running
        Layout.alignment: Qt.AlignVCenter
        onClicked: StorageClean.ask()
    }

    MButton {
        visible: root._paths.length > 0
        kind: "outlined"
        key: "settings.restore"
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.restoreOpen = true
    }

    MButton {
        visible: Settings.sectionId === "overview"
        kind: "outlined"
        key: "settings.overview.kofi"
        iconSource: Qt.resolvedUrl("kofi.svg")
        iconTint: false
        Layout.alignment: Qt.AlignVCenter
        onClicked: {
            Support.openKoFi();
            Settings.close();
        }
    }
    }

    Item {
        id: dialogHost
        visible: false
        width: 0
        height: 0
    }

    MDialog {
        id: restoreDialog
        // Window.window on a Binding is not an Item, so the old parent
        // binding never ran and the card stayed in the header row.
        parent: Window.window ? Window.window.contentItem : dialogHost
        anchors.fill: parent
        open: root.restoreOpen
        titleKey: "settings.restoreTitle"
        titleParams: ({ name: root._name })
        bodyKey: "settings.restoreBody"
        confirmKey: "settings.restore"
        onConfirmed: {
            root.restoreOpen = false;
            root._awaiting = true;
            ConfigWrite.restore(root._paths);
        }
        onCancelled: root.restoreOpen = false
    }

    Connections {
        target: ConfigWrite
        function onFinished(ok) {
            if (!root._awaiting)
                return;
            root._awaiting = false;
            if (!ok) {
                Notifications.toast(I18n.t("settings.restoreFailed", ({ name: root._name })), "");
                return;
            }
            if (Settings.sectionId === "privacy")
                Notifications.dnd = false;
            Notifications.toast(I18n.t("settings.restoreDone", ({ name: root._name })), "");
            if (Settings.sectionId === "design")
                Theme.apply("", "");
        }
    }
}
