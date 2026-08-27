pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Detecta se o workspace focado no momento está vazio (sem janelas), pra
 * mostrar o dashboard só quando não tem nada "atrapalhando" — como uma
 * área de trabalho, não uma sobreposição por cima do que você tá usando.
 */
Singleton {
    id: root

    property int windowCount: 0
    readonly property bool isEmpty: windowCount === 0

    function refresh() {
        proc.running = true
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.refresh()
        }
    }

    Process {
        id: proc
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                try {
                    const data = JSON.parse(collector.text);
                    root.windowCount = data.windows || 0;
                } catch (e) {
                    console.error("[HyprlandWorkspaceService] Falha ao consultar workspace:", e);
                }
            }
        }
    }
}
