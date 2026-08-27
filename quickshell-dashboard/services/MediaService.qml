pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Mini player via MPRIS/playerctl, mas só fica "ativo" quando o player que
 * está tocando é o YouTube Music (xesam:url contendo music.youtube.com).
 * Qualquer outro player/aba (YouTube normal, Spotify, etc) é ignorado —
 * "somente YouTube Music", como pedido.
 *
 * O Firefox expõe MPRIS por aba com a URL real tocando, então isso funciona
 * sem precisar de um app dedicado do YouTube Music.
 */
Singleton {
    id: root

    readonly property string sep: "@@F@@"

    property string playerName: ""
    property string status: ""
    property string url: ""
    property string title: ""
    property string artist: ""
    property string artUrl: ""

    readonly property bool active: url.indexOf("music.youtube.com") !== -1
    readonly property bool playing: status === "Playing"

    function refresh() {
        pollProc.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    function playPause() { runControl("play-pause") }
    function next() { runControl("next") }
    function previous() { runControl("previous") }

    function runControl(action) {
        if (!root.playerName) return;
        controlProc.command = ["playerctl", "-p", root.playerName, action];
        controlProc.running = true;
    }

    Process {
        id: controlProc
        command: ["true"]
    }

    Process {
        id: pollProc
        command: ["bash", "-c",
            `playerctl -a metadata --format '{{playerName}}${root.sep}{{status}}${root.sep}{{xesam:url}}${root.sep}{{title}}${root.sep}{{artist}}${root.sep}{{mpris:artUrl}}' 2>/dev/null`
        ]
        stdout: StdioCollector {
            id: pollCollector
            onStreamFinished: {
                const lines = pollCollector.text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                let picked = null;

                for (const line of lines) {
                    const parts = line.split(root.sep);
                    if (parts.length < 6) continue;
                    const entry = {
                        playerName: parts[0], status: parts[1], url: parts[2],
                        title: parts[3], artist: parts[4], artUrl: parts[5]
                    };
                    if (entry.url.indexOf("music.youtube.com") === -1) continue;
                    if (!picked) picked = entry;
                    if (entry.status === "Playing") { picked = entry; break; }
                }

                root.playerName = picked ? picked.playerName : "";
                root.status = picked ? picked.status : "";
                root.url = picked ? picked.url : "";
                root.title = picked ? picked.title : "";
                root.artist = picked ? picked.artist : "";
                root.artUrl = picked ? picked.artUrl : "";
            }
        }
    }
}
