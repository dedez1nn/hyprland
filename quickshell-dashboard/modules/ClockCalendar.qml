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
    // Altura segue o conteúdo (Column mais embaixo) em vez de um valor
    // fixo — a grade de mês tem mais linhas que a tira de semana, e o
    // Card cresce sozinho porque o Column só conta os filhos visíveis.
    implicitHeight: content.implicitHeight + 40

    // true = grade de mês navegável (como um calendário de verdade) em
    // vez da tira da semana corrente + próximos eventos.
    property bool expanded: false
    property int viewYear: ClockService.now.getFullYear()
    property int viewMonth: ClockService.now.getMonth() // 0-11

    function goToPrevMonth() {
        if (root.viewMonth === 0) {
            root.viewMonth = 11;
            root.viewYear -= 1;
        } else {
            root.viewMonth -= 1;
        }
    }

    function goToNextMonth() {
        if (root.viewMonth === 11) {
            root.viewMonth = 0;
            root.viewYear += 1;
        } else {
            root.viewMonth += 1;
        }
    }

    function toggleExpanded() {
        if (!root.expanded) {
            root.viewYear = ClockService.now.getFullYear();
            root.viewMonth = ClockService.now.getMonth();
        }
        root.expanded = !root.expanded;
        root.hoveredDay = null;
    }

    // Dia sob o mouse na grade de mês (null = nenhum) — alimenta a prévia
    // de eventos abaixo da grade.
    property var hoveredDay: null
    readonly property var hoveredDayEvents: root.hoveredDay ? CalendarService.allEvents.filter(e => root.isSameDay(e.start, root.hoveredDay)) : []

    // Segunda a domingo antes do dia 1, mais dias suficientes pra fechar
    // 6 semanas — cobre qualquer mês (o que começa numa segunda a mais
    // curto, o que começa num domingo é o mais longo).
    readonly property var monthGridDays: {
        const first = new Date(root.viewYear, root.viewMonth, 1);
        const mondayOffset = (first.getDay() + 6) % 7;
        const gridStart = new Date(root.viewYear, root.viewMonth, 1 - mondayOffset);
        const days = [];
        for (let i = 0; i < 42; i++) {
            const day = new Date(gridStart);
            day.setDate(gridStart.getDate() + i);
            days.push(day);
        }
        return days;
    }

    readonly property string monthLabel: {
        const raw = new Date(root.viewYear, root.viewMonth, 1).toLocaleDateString(ClockService.locale, "MMMM yyyy");
        return raw.charAt(0).toUpperCase() + raw.slice(1);
    }

    // Canto superior direito: alterna mês/semana, mais o badge com o
    // total de eventos da semana (só faz sentido fora do modo mês).
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 8
        z: 10

        StyledText {
            text: root.expanded ? "✕" : "📅"
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.accent
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleExpanded()
            }
        }

        Rectangle {
            visible: !root.expanded && root.weekEventCount > 0
            width: Math.max(20, badgeText.implicitWidth + 8)
            height: 20
            color: "transparent"
            border.width: 1
            border.color: Appearance.colors.accentAlt

            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: root.weekEventCount
                font.family: Appearance.font.familyMono
                font.pixelSize: Appearance.font.sizeSmall
                color: Appearance.colors.accent
            }
        }
    }

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
        return CalendarService.allEvents.filter(e => root.isSameDay(e.start, day)).length;
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
            font.family: Appearance.font.familyMono
            font.pixelSize: Appearance.font.sizeHuge
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockService.dateText.toUpperCase()
            font.pixelSize: Appearance.font.sizeSmall
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        Item { width: 1; height: 14 }

        // Tira da semana corrente + próximos eventos — some no modo mês.
        Column {
            visible: !root.expanded
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

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
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        color: Appearance.colors.textFaint
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22
                        height: 22
                        radius: Appearance.radiusSmall
                        color: isToday ? Appearance.colors.accent : "transparent"
                        border.width: isToday ? 0 : 1
                        border.color: Appearance.colors.cardBorder

                        StyledText {
                            anchors.centerIn: parent
                            text: day.getDate()
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall
                            color: isToday ? Appearance.colors.background : Appearance.colors.text
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 3
                        height: 3
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
                    font.family: Appearance.font.familyMono
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
        } // fim da Column da tira de semana

        // Grade de mês navegável — "‹ mês ›" percorre mês a mês, virando
        // o ano sozinho ao cruzar dezembro/janeiro (sem seletor de ano
        // específico, só sequencial mesmo).
        Column {
            visible: root.expanded
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.clock.width - 40
                spacing: 0

                StyledText {
                    text: "‹"
                    width: 30
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Appearance.font.sizeLarge
                    color: Appearance.colors.accent
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToPrevMonth()
                    }
                }

                StyledText {
                    text: root.monthLabel
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.pixelSize: Appearance.font.sizeNormal
                }

                StyledText {
                    text: "›"
                    width: 30
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Appearance.font.sizeLarge
                    color: Appearance.colors.accent
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToNextMonth()
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.clock.width - 40
                spacing: 0

                Repeater {
                    model: root.weekDayLabels

                    delegate: StyledText {
                        required property string modelData
                        text: modelData
                        width: (Config.clock.width - 40) / 7
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        color: Appearance.colors.textFaint
                    }
                }
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 7
                rowSpacing: 4
                columnSpacing: 0

                Repeater {
                    model: root.expanded ? root.monthGridDays : []

                    delegate: Column {
                        required property var modelData
                        readonly property date day: modelData
                        readonly property bool inMonth: day.getMonth() === root.viewMonth
                        readonly property bool isToday: root.isSameDay(day, ClockService.now)
                        readonly property int eventCount: root.eventCountOnDay(day)
                        readonly property bool isHovered: root.hoveredDay !== null && root.isSameDay(day, root.hoveredDay)

                        width: (Config.clock.width - 40) / 7
                        spacing: 2

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 22
                            height: 22
                            radius: Appearance.radiusSmall
                            color: isToday ? Appearance.colors.accent : (isHovered ? Appearance.colors.surface : "transparent")
                            border.width: isToday ? 0 : (isHovered ? 1 : (inMonth ? 1 : 0))
                            border.color: isHovered ? Appearance.colors.accent : Appearance.colors.cardBorder

                            StyledText {
                                anchors.centerIn: parent
                                text: day.getDate()
                                font.family: Appearance.font.familyMono
                                font.pixelSize: Appearance.font.sizeSmall
                                color: isToday ? Appearance.colors.background : (inMonth ? Appearance.colors.text : Appearance.colors.textFaint)
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.hoveredDay = day
                                onExited: if (root.hoveredDay === day) root.hoveredDay = null
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3
                            height: 3
                            color: eventCount > 0 ? Appearance.colors.accent : "transparent"
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            // Prévia dos eventos do dia sob o mouse — altura reservada
            // mesmo sem hover (placeholder), pra não ficar redimensionando
            // o card toda hora ao passar o mouse pelos dias.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.clock.width - 40
                spacing: 4

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.bold: root.hoveredDay !== null
                    font.pixelSize: Appearance.font.sizeSmall
                    color: root.hoveredDay !== null ? Appearance.colors.accent : Appearance.colors.textMuted
                    text: root.hoveredDay
                        ? root.hoveredDay.toLocaleDateString(ClockService.locale, "dddd, d 'de' MMMM").replace(/^./, c => c.toUpperCase())
                        : "Passe o mouse sobre um dia"
                }

                StyledText {
                    visible: root.hoveredDay !== null && root.hoveredDayEvents.length === 0
                    text: "Sem eventos nesse dia"
                    font.pixelSize: Appearance.font.sizeSmall
                    color: Appearance.colors.textMuted
                }

                Repeater {
                    model: root.hoveredDayEvents

                    delegate: Row {
                        width: parent.width
                        spacing: 8

                        StyledText {
                            text: root.eventTimeLabel(modelData)
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall
                            color: Appearance.colors.accent
                            width: 60
                        }

                        StyledText {
                            text: modelData.summary
                            font.pixelSize: Appearance.font.sizeSmall
                            elide: Text.ElideRight
                            width: parent.width - 68
                        }
                    }
                }
            }
        }
    }
}
