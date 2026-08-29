import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.sm

    readonly property int cols: 7
    readonly property int weekStart: Number(Config.language.firstDayOfWeek ?? 1)
    readonly property var cells: root._cells()

    function _cells() {
        void Calendar.eventDays;
        const year = Calendar.viewYear;
        const month = Calendar.viewMonth;
        const first = new Date(year, month, 1);
        const pad = (first.getDay() - root.weekStart + 7) % 7;
        const dim = new Date(year, month + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < pad; i++)
            out.push({ day: 0, ymd: "", today: false, marked: false });
        for (let d = 1; d <= dim; d++) {
            const ymd = DateTime.formatDate(new Date(year, month, d), "YYYY-MM-DD");
            out.push({
                day: d,
                ymd: ymd,
                today: ymd === Calendar.todayYmd,
                marked: Calendar.hasEventsOn(ymd)
            });
        }
        return out;
    }

    RowLayout {
        Layout.fillWidth: true
        MIconButton {
            iconName: "go-previous-symbolic"
            key: "calendar.prevMonth"
            onClicked: Calendar.shiftMonth(-1)
        }
        MText {
            value: DateTime.monthTitle(Calendar.viewYear, Calendar.viewMonth)
            styleName: "titleMedium"
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        MIconButton {
            iconName: "go-next-symbolic"
            key: "calendar.nextMonth"
            onClicked: Calendar.shiftMonth(1)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.cols
        columnSpacing: Tokens.spacing.xxs
        rowSpacing: Tokens.spacing.xxs

        Repeater {
            model: root.cols
            MText {
                required property int index
                value: DateTime.weekdayIndex((root.weekStart + index) % 7)
                styleName: "labelSmall"
                color: Colors.color.onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: root.cells
            Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.spacing.xl + Tokens.spacing.xs

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.full
                    color: modelData.today ? Colors.color.primaryContainer : "transparent"
                    visible: modelData.day > 0
                }

                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.spacing.xxs
                    value: modelData.day > 0 ? String(modelData.day) : ""
                    styleName: "labelLarge"
                    color: modelData.today ? Colors.color.onPrimaryContainer : Colors.color.onSurface
                }

                Rectangle {
                    visible: modelData.marked
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.spacing.xxs
                    width: Tokens.spacing.xs
                    height: Tokens.spacing.xs
                    radius: Tokens.radius.full
                    color: modelData.today ? Colors.color.onPrimaryContainer : Colors.color.primary
                }
            }
        }
    }

    MHint {
        visible: Calendar.icsUrl.length === 0
        key: "calendar.icsHint"
        Layout.fillWidth: true
    }
}
