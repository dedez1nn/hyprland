pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Liga/desliga a suspensão automática por inatividade (listener "Suspend
 * after 20 min idle" do hypridle.conf), sem mexer no resto do hypridle:
 * aviso de ociosidade e bloqueio de tela continuam funcionando normal.
 *
 * Desativar aqui sobe um `systemd-inhibit --what=sleep`, que bloqueia
 * qualquer `systemctl suspend` (inclusive o do próprio hypridle) enquanto
 * o processo estiver vivo. `systemd-inhibit` troca de imagem (execve) pro
 * comando dado mantendo o mesmo PID, então matar esse processo (running
 * = false) já libera o inhibitor sozinho, sem precisar de nenhum pkill à
 * parte.
 *
 * Estado persistido em config/idle-suspend.json, mesmo espírito do
 * WidgetVisibilityService, então o toggle sobrevive a reinícios do
 * dashboard. Widget em modules/IdleSuspendWidget.qml.
 */
Singleton {
    id: root

    property bool suspendEnabled: true

    function setSuspendEnabled(value) {
        root.suspendEnabled = value;
        file.setText(JSON.stringify({ suspendEnabled: value }, null, 2));
    }

    Process {
        id: inhibitor
        running: !root.suspendEnabled
        command: [
            "systemd-inhibit", "--what=sleep", "--mode=block",
            "--who=quickshell-dashboard",
            "--why=Suspensão automática desativada pelo usuário",
            "sleep", "infinity"
        ]
    }

    FileView {
        id: file
        path: Qt.resolvedUrl("../config/idle-suspend.json")
        onLoadedChanged: {
            try {
                const data = JSON.parse(file.text());
                root.suspendEnabled = data.suspendEnabled ?? true;
            } catch (e) {
                root.suspendEnabled = true;
            }
        }
        onLoadFailed: (error) => {
            root.suspendEnabled = true;
        }
    }
}
