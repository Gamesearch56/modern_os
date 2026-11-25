import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property date date: new Date()

    readonly property var _c: root.chrome
    readonly property string _time: root._c ? root._c.formatTime(root.date) : ""
    readonly property string _date: root._c ? root._c.formatDateLine(root.date) : ""
    readonly property string _spoken: {
        const parts = [];
        if (root._date.length)
            parts.push(root._date);
        if (root._time.length)
            parts.push(root._time);
        return parts.join(" ");
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: root._spoken

    ColumnLayout {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root._c ? root._c.spaceXs : 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._time
            color: root._c ? root._c.color.onSurface : "#E6E0E9"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("displayLarge") : 57
            font.weight: root._c ? root._c.typeWeight("displayLarge") : 400
            Accessible.ignored: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._date
            color: root._c ? root._c.color.onSurfaceVariant : "#CAC4D0"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("titleMedium") : 16
            font.weight: root._c ? root._c.typeWeight("titleMedium") : 500
            Accessible.ignored: true
        }
    }
}
