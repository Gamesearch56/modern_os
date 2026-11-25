import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    width: parent ? parent.width : Tokens.spacing.xxl * 14
    implicitWidth: Tokens.spacing.xxl * 14
    implicitHeight: chrome.implicitHeight
    property string range: "today"
    signal setupRequested()

    onRangeChanged: {
        if (root.hourly)
            root._scrollHourly();
        else
            flick.contentY = 0;
    }

    readonly property bool today: root.range === "today"
    readonly property bool hourly: root.range === "hourly"
    readonly property var days: {
        void Weather.daily;
        return (Weather.daily || []).slice(0, 7);
    }
    readonly property var hours: {
        void Weather.hourly;
        return Weather.hourly || [];
    }

    onHoursChanged: {
        if (root.hourly)
            root._scrollHourly();
    }
    readonly property string sunriseText: root._clock(Weather.sunrise)
    readonly property string sunsetText: root._clock(Weather.sunset)
    readonly property string precipText: {
        void Weather.precip;
        void Weather.imperial;
        const p = {};
        p.amount = Math.round(Weather.precip);
        return I18n.t(Weather.imperial ? "weather.precipIn" : "weather.precipMm", p);
    }
    readonly property string pressureText: {
        void Weather.pressure;
        const p = {};
        p.hpa = Math.round(Weather.pressure);
        return I18n.t("weather.pressureHpa", p);
    }

    function _clock(iso: string): string {
        if (!iso || iso.length < 16)
            return "";
        return DateTime.formatTime(new Date(iso), Config.language.timeFormat || "HH:mm", false);
    }

    function _dayLabel(iso: string): string {
        if (!iso || iso.length < 10)
            return "";
        const d = new Date(iso + "T12:00:00");
        return DateTime.weekday(d) + " " + DateTime.formatDate(d, Config.language.dateFormat || "DD.MM.YYYY");
    }

    function _hourPrefix(): string {
        const n = new Date();
        return n.getFullYear() + "-" + DateTime.pad(n.getMonth() + 1) + "-"
            + DateTime.pad(n.getDate()) + "T" + DateTime.pad(n.getHours());
    }

    function _hourIndex(): int {
        const list = root.hours || [];
        const prefix = root._hourPrefix();
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].iso || "").indexOf(prefix) === 0)
                return i;
        }
        return 0;
    }

    function _scrollHourly() {
        Qt.callLater(() => {
            Qt.callLater(() => {
                if (!root.hourly)
                    return;
                const row = hourRepeater.itemAt(root._hourIndex());
                if (!row || flick.height <= 0)
                    return;
                const y = row.mapToItem(flick.contentItem, 0, 0).y;
                const maxY = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.min(maxY, Math.max(0, y));
            });
        });
    }

    BarPanelChrome {
        id: chrome
        width: root.width
        titleKey: "weather.detailTitle"

        actions: MIconButton {
            iconName: "view-refresh-symbolic"
            key: "weather.refresh"
            busy: Weather.busy
            onClicked: Weather.refresh(true)
        }

        MSegmented {
            Layout.fillWidth: true
            value: root.range
            model: [
                { value: "today", titleKey: "weather.today" },
                { value: "hourly", titleKey: "weather.hourly" },
                { value: "7", titleKey: "weather.next7" }
            ]
            onSelected: (v) => root.range = String(v)
        }

        MPane {
            Layout.fillWidth: true
            color: "transparent"
            implicitHeight: {
                if (!Weather.available)
                    return Tokens.spacing.xxl * 10 + padding * 2;
                const inner = col.implicitHeight;
                if (root.hourly)
                    return Math.min(inner, Tokens.spacing.xxl * 12) + padding * 2;
                return inner + padding * 2;
            }

            Flickable {
                id: flick
                visible: Weather.available
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: col.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1

                ColumnLayout {
                    id: col
                    width: flick.width
                    spacing: Tokens.spacing.sm

                ColumnLayout {
                    visible: root.today && Weather.available
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.xs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.sm
                        MIcon {
                            name: Weather.iconName
                            size: Tokens.icon.lg
                            color: Colors.color.onSurface
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            MText { value: Weather.display; styleName: "headlineMedium" }
                            MText {
                                key: Weather.conditionKey
                                styleName: "bodyMedium"
                                color: Colors.color.onSurfaceVariant
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.md
                        spacing: Tokens.spacing.xs

                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.feelsLike"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: Math.round(Weather.feelsLike) + "°"; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.high"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: Math.round(Weather.tMax) + "° / " + Math.round(Weather.tMin) + "°"; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.humidity"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: Math.round(Weather.humidity) + "%"; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.wind"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: Weather.windText; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.precip"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: root.precipText; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.uv"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: String(Math.round(Weather.uv)); styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.pressure"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: root.pressureText; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.sunrise"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: root.sunriseText; styleName: "labelLarge" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            MText { key: "weather.sunset"; styleName: "bodyMedium"; Layout.fillWidth: true }
                            MText { value: root.sunsetText; styleName: "labelLarge" }
                        }
                    }
                }

                Repeater {
                    id: hourRepeater
                    model: root.hourly ? root.hours : (root.range === "7" ? root.days : [])
                    onCountChanged: {
                        if (root.hourly && count > 0)
                            root._scrollHourly();
                    }

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.sm

                        MIcon {
                            name: modelData.icon
                            size: Tokens.icon.md
                            color: Colors.color.onSurface
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            MText {
                                value: root.hourly ? root._clock(modelData.iso) : root._dayLabel(modelData.iso)
                                styleName: "labelLarge"
                                Layout.fillWidth: true
                            }
                            MText {
                                key: modelData.conditionKey
                                styleName: "bodySmall"
                                color: Colors.color.onSurfaceVariant
                                Layout.fillWidth: true
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            MText {
                                value: root.hourly
                                    ? (Math.round(modelData.temp) + "°")
                                    : (Math.round(modelData.tMax) + "° / " + Math.round(modelData.tMin) + "°")
                                styleName: "labelLarge"
                            }
                            MText {
                                value: Math.round(modelData.precip) + "% · " + Weather.formatWind(modelData.wind)
                                styleName: "labelSmall"
                                color: Colors.color.onSurfaceVariant
                            }
                        }
                    }
                }

                }
            }

            MEmptyState {
                visible: !Weather.available
                anchors.fill: parent
                iconName: "weather-none"
                titleKey: "weather.unavailableTitle"
                hintKey: "weather.unavailableHint"
                actionKey: "weather.setup"
                onActionClicked: root.setupRequested()
            }
        }
    }
}
