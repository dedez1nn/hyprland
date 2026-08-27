pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * Tempo de atividade NA SESSÃO — diferente do UptimeService (uptime do
 * sistema): conta só os segundos em que o usuário não estava ocioso, via
 * protocolo ext-idle-notify (IdleMonitor, nativo do Quickshell). Zera
 * quando o boot muda (login novo). Persistido em config/active-time.json
 * a cada poucos segundos pra sobreviver a um restart do processo qs
 * (ex: crash no resume de suspend) sem perder a contagem da sessão —
 * o arquivo guarda o boot_id junto pra distinguir "mesmo boot, processo
 * reiniciou" de "boot novo, sessão nova".
 */
Singleton {
    id: root

    readonly property int idleTimeoutSeconds: 120
    readonly property int saveIntervalSeconds: 10
    property int activeSeconds: 0
    property string prettyText: "00h 00m"
    property string bootId: ""
    property bool restored: false

    function format(totalSeconds) {
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        return `${String(hours).padStart(2, "0")}h ${String(minutes).padStart(2, "0")}m`;
    }

    function save() {
        if (!root.bootId) return;
        stateFile.setText(JSON.stringify({ bootId: root.bootId, activeSeconds: root.activeSeconds }));
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

    Timer {
        interval: root.saveIntervalSeconds * 1000
        running: !idleMonitor.isIdle
        repeat: true
        onTriggered: root.save()
    }

    // Quando fica ocioso, o timer de save acima para — salva o resto na
    // hora pra não perder até saveIntervalSeconds de contagem.
    Connections {
        target: idleMonitor
        function onIsIdleChanged() {
            if (idleMonitor.isIdle) root.save();
        }
    }

    Process {
        id: bootIdProc
        command: ["cat", "/proc/sys/kernel/random/boot_id"]
        stdout: StdioCollector {
            id: bootIdCollector
            onStreamFinished: {
                root.bootId = bootIdCollector.text.trim();
                stateFile.reload();
            }
        }
        Component.onCompleted: running = true
    }

    FileView {
        id: stateFile
        path: Qt.resolvedUrl("../config/active-time.json")
        onLoadedChanged: {
            if (root.restored || !root.bootId) return;
            try {
                const data = JSON.parse(stateFile.text());
                if (data.bootId === root.bootId) root.activeSeconds = data.activeSeconds || 0;
            } catch (e) {
                // arquivo ausente/corrompido — começa do zero
            }
            root.restored = true;
        }
        onLoadFailed: (error) => { root.restored = true; }
    }
}
