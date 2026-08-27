pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Tempo de atividade do sistema, pro WelcomeCard.
 * Lê /proc/uptime direto (não depende do locale do sistema, ao contrário de
 * `uptime -p`, que sai em inglês se o locale não for pt_BR).
 */
Singleton {
    id: root

    property string prettyText: "..."

    function format(totalSeconds) {
        const days = Math.floor(totalSeconds / 86400);
        const hours = Math.floor((totalSeconds % 86400) / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);

        const parts = [];
        if (days > 0) parts.push(`${days} ${days === 1 ? "dia" : "dias"}`);
        if (hours > 0) parts.push(`${hours} ${hours === 1 ? "hora" : "horas"}`);
        if (minutes > 0 || parts.length === 0)
            parts.push(`${minutes} ${minutes === 1 ? "minuto" : "minutos"}`);

        if (parts.length === 1) return parts[0];
        return parts.slice(0, -1).join(", ") + " e " + parts[parts.length - 1];
    }

    function refresh() {
        uptimeProc.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            id: uptimeCollector
            onStreamFinished: {
                const seconds = parseFloat(uptimeCollector.text.trim().split(" ")[0]);
                root.prettyText = root.format(seconds);
            }
        }
    }
}
