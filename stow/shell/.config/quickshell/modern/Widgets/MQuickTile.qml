// Android-style quick-settings tile: icon + label, tonal fill when on.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string titleKey: ""
    property string subtitleValue: ""
    property bool checked: false
    property bool enabled: true
    property bool centerAlign: false
    property bool stacked: false
    property bool tintIcon: true

    signal clicked()

    implicitHeight: root.stacked
        ? Tokens.spacing.xxl * 3 + Tokens.spacing.sm
        : Tokens.spacing.xxl * 2 + Tokens.spacing.xs
    implicitWidth: Tokens.spacing.xxl * 6
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.titleKey.length > 0 ? I18n.t(root.titleKey) : root.iconName
    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onPressed: (event) => {
        if (!root.enabled)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    readonly property color _fg: root.checked ? Chrome.tonal.fg : Colors.color.onSurface
    readonly property color _icon: Colors.color.primary
    readonly property int _textAlign: root.centerAlign ? Text.AlignHCenter : Text.AlignLeft

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: root.checked ? Chrome.tonal.bg : Colors.color.surfaceContainer
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.primary
        opacity: Chrome.stateLayer(ma.containsMouse, ma.pressed)
    }

    ColumnLayout {
        visible: root.stacked
        anchors.fill: parent
        anchors.margins: Tokens.spacing.md
        spacing: Tokens.spacing.xs

        Item {
            Layout.fillHeight: true
        }

        MIcon {
            Layout.alignment: Qt.AlignHCenter
            name: root.iconName
            size: Tokens.icon.lg
            color: root._icon
            tint: root.tintIcon
            preferSymbolic: true
        }

        MText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            key: root.titleKey
            styleName: "labelLarge"
            color: root._fg
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        MText {
            visible: root.subtitleValue.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            value: root.subtitleValue
            styleName: "labelSmall"
            color: root.checked ? Chrome.tonal.fg : Colors.color.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.fillHeight: true
        }
    }

    RowLayout {
        visible: !root.stacked
        anchors.fill: parent
        anchors.margins: Tokens.spacing.sm
        spacing: Tokens.spacing.sm

        Item {
            visible: root.centerAlign
            Layout.fillWidth: true
        }

        MIcon {
            name: root.iconName
            size: Tokens.icon.md
            color: root._icon
            tint: root.tintIcon
            preferSymbolic: true
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: !root.centerAlign
            Layout.alignment: Qt.AlignVCenter

            MText {
                key: root.titleKey
                styleName: "labelLarge"
                color: root._fg
                horizontalAlignment: root._textAlign
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                Layout.fillWidth: !root.centerAlign
            }
            MText {
                visible: root.subtitleValue.length > 0
                value: root.subtitleValue
                styleName: "labelSmall"
                color: root.checked ? Chrome.tonal.fg : Colors.color.onSurfaceVariant
                horizontalAlignment: root._textAlign
                Layout.fillWidth: !root.centerAlign
            }
        }

        Item {
            visible: root.centerAlign
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
