pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Streak de dias seguidos com pelo menos um commit em qualquer repositório
 * de ~/repos/* (todos os branches, sem filtro de autor — são repositórios
 * pessoais). Conta a partir de hoje; se ainda não commitou hoje, conta a
 * partir de ontem (streak "vivo" até virar o dia).
 */
Singleton {
    id: root

    property int streak: 0
    property bool ready: false

    function refresh() {
        proc.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: ["bash", "-c", `
            dates=$(for repo in "$HOME"/repos/*/; do
                git -C "$repo" log --all --format=%cd --date=format:%Y-%m-%d 2>/dev/null
            done | sort -u)

            has_date() { printf '%s\n' "$dates" | grep -qx "$1"; }

            cursor=$(date +%Y-%m-%d)
            if ! has_date "$cursor"; then
                cursor=$(date -d "$cursor -1 day" +%Y-%m-%d)
            fi

            streak=0
            while has_date "$cursor"; do
                streak=$((streak+1))
                cursor=$(date -d "$cursor -1 day" +%Y-%m-%d)
            done

            echo "$streak"
        `]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                const value = parseInt(collector.text.trim(), 10);
                root.streak = Number.isNaN(value) ? 0 : value;
                root.ready = true;
            }
        }
    }
}
