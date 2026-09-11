pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * Tempo de atividade DO DIA — diferente do UptimeService (uptime do
 * sistema): conta só os segundos em que o usuário não estava ocioso, via
 * protocolo ext-idle-notify (IdleMonitor, nativo do Quickshell). Acumula
 * o dia civil inteiro e só zera na virada do dia — sobrevive a
 * desligamentos, suspensões e restarts do processo qs (ex: crash no
 * resume de suspend), no mesmo espírito do UptimeToday.sh
 * (~/.config/hypr/scripts), que usa o mesmo critério de "data salva vs.
 * data atual" em vez de boot_id (boot_id muda a cada desligamento e
 * zerava o contador à toa). Persistido em config/active-time.json a cada
 * poucos segundos.
 */
Singleton {
    id: root

    readonly property int idleTimeoutSeconds: 120
    readonly property int saveIntervalSeconds: 10
    property int activeSeconds: 0
    property string prettyText: "00h 00m"
    property string today: root.currentDate()
    property bool restored: false

    function format(totalSeconds) {
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        return `${String(hours).padStart(2, "0")}h ${String(minutes).padStart(2, "0")}m`;
    }

    function currentDate() {
        const d = new Date();
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    function save() {
        stateFile.setText(JSON.stringify({ date: root.today, activeSeconds: root.activeSeconds }));
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
        onTriggered: {
            const day = root.currentDate();
            if (day !== root.today) {
                root.today = day;
                root.activeSeconds = 0;
            }
            root.activeSeconds += 1;
        }
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

    FileView {
        id: stateFile
        path: Qt.resolvedUrl("../config/active-time.json")
        onLoadedChanged: {
            if (root.restored) return;
            try {
                const data = JSON.parse(stateFile.text());
                if (data.date === root.today) root.activeSeconds = data.activeSeconds || 0;
            } catch (e) {
                // arquivo ausente/corrompido — começa do zero
            }
            root.restored = true;
        }
        onLoadFailed: (error) => { root.restored = true; }
    }
}
