pragma Singleton

import QtQuick
import Quickshell

/**
 * Relógio único compartilhado por todos os widgets que precisam de hora/data
 * (ClockCalendar agora, WelcomeCard pra saudação por horário, e futuramente
 * o calendário na parte 3).
 */
Singleton {
    id: root

    property date now: new Date()
    readonly property var locale: Qt.locale("pt_BR")

    readonly property string timeText: now.toLocaleTimeString(locale, "HH:mm")
    readonly property string dateText: {
        const raw = now.toLocaleDateString(locale, "dddd, d 'de' MMMM");
        return raw.charAt(0).toUpperCase() + raw.slice(1);
    }

    // 0-5h madrugada, 6-11h manhã, 12-17h tarde, 18-23h noite
    readonly property string greetingPeriod: {
        const h = now.getHours();
        if (h < 6) return "madrugada";
        if (h < 12) return "manhã";
        if (h < 18) return "tarde";
        return "noite";
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
