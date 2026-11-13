// Settings hero: icon or avatar, title, subtitle, optional in-column
// detail (chips), trailing actions, and extra below the header row.
import QtQuick
import QtQuick.Layouts
import "../Commons"

MCard {
    id: root

    property string iconName: ""
    property url avatarSource: ""
    property int avatarSize: Tokens.spacing.xxl * 3
    property string titleKey: ""
    property var titleParams: ({})
    property string titleValue: ""
    property string subtitleKey: ""
    property string subtitleValue: ""
    property bool preferSymbolic: true
    property color iconColor: Colors.color.primary
    property bool iconTint: true

    default property alias extra: extraSlot.data
    property alias detail: detailSlot.data
    property alias trailing: trailingSlot.data
    // Child visible is not a binding dependency. A button that appears
    // after the first probe would stay clipped until the page is rebuilt.
    property int _slots: 0
    property var _watched: []

    Layout.fillWidth: true
    level: 0
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2
    Layout.preferredHeight: implicitHeight

    function _slotOpen(item: var): bool {
        if (!item)
            return false;
        const kids = item.children;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i].visible)
                return true;
        }
        return false;
    }

    function _bumpSlots() {
        root._slots++;
    }

    function _armSlot(item) {
        if (!item)
            return;
        const kids = item.children;
        let seen = root._watched;
        for (let i = 0; i < kids.length; i++) {
            const kid = kids[i];
            if (seen.indexOf(kid) !== -1)
                continue;
            seen = seen.concat([kid]);
            kid.visibleChanged.connect(root._bumpSlots);
        }
        root._watched = seen;
        root._bumpSlots();
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MAvatar {
                visible: String(root.avatarSource).length > 0
                size: root.avatarSize
                source: root.avatarSource
                Layout.alignment: Qt.AlignVCenter
            }
            MIcon {
                visible: String(root.avatarSource).length === 0 && root.iconName.length > 0
                name: root.iconName
                size: Tokens.spacing.xxl * 2
                color: root.iconColor
                tint: root.iconTint
                preferSymbolic: root.preferSymbolic
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.xs

                MText {
                    key: root.titleKey
                    params: root.titleParams
                    value: root.titleValue
                    styleName: "titleLarge"
                    Layout.fillWidth: true
                }
                MText {
                    visible: root.subtitleKey.length > 0 || root.subtitleValue.length > 0
                    key: root.subtitleKey
                    value: root.subtitleValue
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    id: detailSlot
                    visible: {
                        void root._slots;
                        return root._slotOpen(detailSlot);
                    }
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.sm
                    spacing: Tokens.spacing.xs
                    Component.onCompleted: root._armSlot(detailSlot)
                    onChildrenChanged: root._armSlot(detailSlot)
                }
            }

            ColumnLayout {
                id: trailingSlot
                visible: {
                    void root._slots;
                    return root._slotOpen(trailingSlot);
                }
                Layout.alignment: Qt.AlignVCenter
                Component.onCompleted: root._armSlot(trailingSlot)
                onChildrenChanged: root._armSlot(trailingSlot)
            }
        }

        ColumnLayout {
            id: extraSlot
            visible: {
                void root._slots;
                return root._slotOpen(extraSlot);
            }
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm
            Component.onCompleted: root._armSlot(extraSlot)
            onChildrenChanged: root._armSlot(extraSlot)
        }
    }
}
