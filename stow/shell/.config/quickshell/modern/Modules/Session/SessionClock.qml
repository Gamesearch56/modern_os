import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property date date: new Date()

    readonly property string _time: DateTime.formatTime(root.date, Config.language.timeFormat || "HH:mm", true)
    readonly property string _date: DateTime.weekday(root.date) + "  " + DateTime.formatDate(root.date, Config.language.dateFormat || "DD.MM.YYYY")
    readonly property string _spoken: root._date + " " + root._time

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: root._spoken

    ColumnLayout {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.xs

        MText {
            Layout.alignment: Qt.AlignHCenter
            value: root._time
            styleName: "displayLarge"
            Accessible.ignored: true
        }

        MText {
            Layout.alignment: Qt.AlignHCenter
            value: root._date
            styleName: "titleMedium"
            color: Colors.color.onSurfaceVariant
            Accessible.ignored: true
        }
    }
}
