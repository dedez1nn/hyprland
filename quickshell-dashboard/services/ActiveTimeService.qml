pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * Tempo de atividade NA SESSÃO — diferente do UptimeService (uptime do
 * sistema): conta só os segundos em que o usuário não estava ocioso, via
 * protocolo ext-idle-notify (IdleMonitor, nativo do Quickshell). Zera
 * quando o Quickshell reinicia, o que na prática coincide com o login já
 * que o dashboard sobe junto com o Hyprland via systemd.
 */
Singleton {
    id: root

    readonly property int idleTimeoutSeconds: 120
    property int activeSeconds: 0
    property string prettyText: "00h 00m"

    function format(totalSeconds) {
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        return `${String(hours).padStart(2, "0")}h ${String(minutes).padStart(2, "0")}m`;
    }

    onActiveSecondsChanged: root.prettyText = root.format(root.activeSeconds)

    IdleMonitor {
        id: idleMonitor
        enabled: true
        timeout: root.idleTimeoutSeconds
    }

    Timer {
        interval: 1000
        running: !idleMonitor.isIdle
        repeat: true
        onTriggered: root.activeSeconds += 1
    }
}
