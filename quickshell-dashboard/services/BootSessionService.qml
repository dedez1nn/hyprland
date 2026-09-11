pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Sabe se a tela já travou ou o sistema já suspendeu desde o boot atual
 * — os widgets de diagnóstico de boot (Entropy/KernelTaint/BootStatus/
 * SystemdBootTime) só fazem sentido logo depois de ligar o PC; depois do
 * primeiro lock ou suspensão eles somem até o próximo boot de verdade.
 *
 * Detecção via um marker file em $XDG_RUNTIME_DIR (tmpfs por sessão de
 * login, recriado do zero pelo systemd num boot real, mas que sobrevive
 * a um resume de suspensão mesmo que o quickshell-dashboard.service seja
 * reiniciado nesse meio tempo — ver after_sleep_cmd do hypridle.conf):
 * "o marker existe" já significa "já travou/suspendeu desde que a
 * máquina ligou", boot real e resume distinguidos de graça, sem precisar
 * comparar boot id nem nada parecido.
 *
 * O marker em si é criado pelo `lock_cmd` do hypridle.conf — roda em
 * todo lock manual (Super+L, idle timeout) E antes de toda suspensão, já
 * que o before_sleep_cmd de lá sempre chama `loginctl lock-session`
 * primeiro. watchChanges:true faz o FileView notar a criação do arquivo
 * em tempo real, sem precisar reiniciar o processo pra reagir a um lock
 * que aconteceu com o dashboard já rodando.
 *
 * `dismiss(key)` cobre o "x" de fechar um widget individual (ver
 * EntropyWidget/KernelTaintWidget/BootStatusWidget/SystemdBootTimeWidget):
 * mesma ideia do marker acima, mas por widget — uma lista em outro
 * arquivo no mesmo $XDG_RUNTIME_DIR, então "fechado" também some sozinho
 * só no próximo boot de verdade, nunca antes disso.
 */
Singleton {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string markerPath: root.runtimeDir + "/quickshell-dashboard-boot-widgets-locked"
    property bool locked: false
    readonly property bool showBootWidgets: !root.locked

    property var dismissedWidgets: []

    function isDismissed(key) {
        return root.dismissedWidgets.includes(key);
    }

    function dismiss(key) {
        if (root.dismissedWidgets.includes(key)) return;
        const next = root.dismissedWidgets.concat([key]);
        root.dismissedWidgets = next;
        dismissedFile.setText(JSON.stringify(next));
    }

    FileView {
        id: marker
        path: root.markerPath
        watchChanges: true
        onLoaded: root.locked = true
        onLoadFailed: (error) => { root.locked = false }
        onFileChanged: reload()
    }

    FileView {
        id: dismissedFile
        path: root.runtimeDir + "/quickshell-dashboard-dismissed-widgets.json"
        watchChanges: true
        onLoaded: {
            try {
                root.dismissedWidgets = JSON.parse(dismissedFile.text());
            } catch (e) {
                root.dismissedWidgets = [];
            }
        }
        onLoadFailed: (error) => { root.dismissedWidgets = []; }
        onFileChanged: reload()
    }
}
