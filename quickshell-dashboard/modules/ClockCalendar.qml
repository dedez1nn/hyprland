import QtQuick
import "../common"
import "../services"

/**
 * Relógio + data + próximos eventos do Proton Calendar (link .ics público,
 * ver services/CalendarService.qml pras limitações conhecidas: sem
 * recorrência de RRULE por enquanto).
 */
Card {
    id: root
    positionKey: "clockCalendar"
    implicitWidth: Config.clock.width
    implicitHeight: content.implicitHeight + 40

    function eventTimeLabel(event) {
        if (event.allDay) return "Dia todo";
        return event.start.toLocaleTimeString(ClockService.locale, "HH:mm");
    }

    function eventDayLabel(event) {
        const now = ClockService.now;
        const sameDay = event.start.getFullYear() === now.getFullYear()
            && event.start.getMonth() === now.getMonth()
            && event.start.getDate() === now.getDate();
        return sameDay ? "Hoje" : event.start.toLocaleDateString(ClockService.locale, "ddd, d/M");
    }

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    // Segunda a domingo, semana corrente.
    readonly property var weekDays: {
        const now = ClockService.now;
        const mondayOffset = (now.getDay() + 6) % 7;
        const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - mondayOffset);
        const days = [];
        for (let i = 0; i < 7; i++) {
            const day = new Date(monday);
            day.setDate(monday.getDate() + i);
            days.push(day);
        }
        return days;
    }

    readonly property var weekDayLabels: ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]

    function eventCountOnDay(day) {
        return CalendarService.events.filter(e => root.isSameDay(e.start, day)).length;
    }

    readonly property int weekEventCount: {
        let total = 0;
        for (const day of root.weekDays) total += root.eventCountOnDay(day);
        return total;
    }

    function weekSummaryText() {
        if (root.weekEventCount === 0) return "Nenhum evento essa semana";
        if (root.weekEventCount === 1) return "1 evento essa semana";
        return `${root.weekEventCount} eventos essa semana`;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        spacing: 4

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockService.timeText
            font.pixelSize: Appearance.font.sizeHuge
            font.bold: true
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockService.dateText
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
        }

        Item { width: 1; height: 14 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Config.clock.width - 40
            spacing: 0

            Repeater {
                model: 7

                Column {
                    required property int index
                    readonly property var day: root.weekDays[index]
                    readonly property bool isToday: root.isSameDay(day, ClockService.now)
                    readonly property int eventCount: root.eventCountOnDay(day)

                    width: (Config.clock.width - 40) / 7
                    spacing: 4

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.weekDayLabels[index]
                        font.pixelSize: Appearance.font.sizeSmall
                        color: Appearance.colors.textMuted
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22
                        height: 22
                        radius: 11
                        color: isToday ? Appearance.colors.accent : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: day.getDate()
                            font.pixelSize: Appearance.font.sizeSmall
                            font.bold: isToday
                            color: isToday ? Appearance.colors.background : Appearance.colors.text
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: eventCount > 0 ? Appearance.colors.accent : "transparent"
                    }
                }
            }
        }

        Item { width: 1; height: 4 }

        StyledText {
            visible: CalendarService.configured && CalendarService.ready && !CalendarService.error
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.weekSummaryText()
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
        }

        Item { width: 1; height: 8 }

        StyledText {
            visible: !CalendarService.configured
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Calendário não configurado (config/secrets.json)"
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
        }

        StyledText {
            visible: CalendarService.configured && !CalendarService.ready && !CalendarService.error
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Carregando eventos..."
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
        }

        StyledText {
            visible: CalendarService.configured && CalendarService.error
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Erro ao carregar calendário"
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.danger
        }

        StyledText {
            visible: CalendarService.configured && CalendarService.ready && !CalendarService.error && CalendarService.events.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sem eventos próximos"
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
        }

        Repeater {
            model: CalendarService.configured ? CalendarService.events.slice(0, 4) : []
            delegate: Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                width: Config.clock.width - 40

                StyledText {
                    text: root.eventDayLabel(modelData) + " " + root.eventTimeLabel(modelData)
                    font.pixelSize: Appearance.font.sizeSmall
                    color: Appearance.colors.accent
                    width: 110
                }

                StyledText {
                    text: modelData.summary
                    font.pixelSize: Appearance.font.sizeSmall
                    elide: Text.ElideRight
                    width: parent.width - 118
                }
            }
        }
    }
}
