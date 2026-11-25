import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property alias flick: pane
    readonly property bool empty: !Store.loading && Store.sections.length === 0
    readonly property var popularSection: {
        void Store.sections;
        const s = Store.sections || [];
        for (let i = 0; i < s.length; i++) {
            if (String(s[i] && s[i].id || "") === "popular")
                return s[i];
        }
        return ({});
    }
    readonly property var featuredPkgs: {
        const pkgs = root.popularSection.packages || [];
        return pkgs.length > 3 ? pkgs.slice(0, 3) : pkgs;
    }
    readonly property var popularPkgs: {
        const pkgs = root.popularSection.packages || [];
        return pkgs.length > 3 ? pkgs.slice(3) : [];
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MLinearProgress {
            visible: Store.loading
            Layout.fillWidth: true
            indeterminate: true
        }

        Flickable {
            id: pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.empty
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Tokens.store.sectionGap

                Featured {
                    packages: root.featuredPkgs
                }

                CatChips {}

                ColumnLayout {
                    visible: root.popularPkgs.length > 0
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.sm

                    MSectionHeader {
                        key: "store.popular"
                        styleName: "titleMedium"
                        topMargin: 0
                        Layout.fillWidth: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Tokens.spacing.sm
                        rowSpacing: Tokens.spacing.xs

                        Repeater {
                            model: root.popularPkgs.length

                            PkgRow {
                                required property int index
                                Layout.fillWidth: true
                                pkg: root.popularPkgs[index] || ({})
                                removable: !Store.isSystem(String(pkg && pkg.name || ""))
                            }
                        }
                    }
                }

                Repeater {
                    model: Store.sections.length

                    PkgShelf {
                        required property int index
                        readonly property var sec: Store.sections[index] || ({})
                        visible: String(sec.id || "") !== "popular"
                        Layout.fillWidth: true
                        section: sec
                    }
                }
            }
        }

        MEmptyState {
            visible: root.empty
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "system-software-install-symbolic"
            titleKey: "store.empty"
            hintKey: "store.emptyHint"
        }
    }
}
