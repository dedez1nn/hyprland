pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Conexões de rede ativas (`ss -tunHp`, sem cabeçalho): protocolo, estado,
 * endereço/porta local e remota, e o processo dono do socket. Widget em
 * modules/NetworkConnectionsWidget.qml.
 *
 * `-p` só resolve o nome do processo pros sockets do próprio usuário —
 * sem sudo, sockets de outros usuários/serviços do sistema ficam com
 * `process` vazio. Aceitável: o widget é sobre o que a própria sessão do
 * usuário está conectando, não uma auditoria de sistema completa.
 */
Singleton {
    id: root

    property var connections: []
    property bool ready: false

    // "192.168.1.217:52400" -> { address: "192.168.1.217", port: "52400" }
    // Corta no último ":" (não no primeiro) porque endereços IPv6 têm
    // vários ":" no meio — só o trecho depois do último é a porta.
    function splitAddrPort(text) {
        const idx = text.lastIndexOf(":");
        if (idx === -1) return { address: text, port: "" };
        return { address: text.slice(0, idx), port: text.slice(idx + 1) };
    }

    // Coluna de processo vem como `users:(("firefox",pid=2792,fd=89))`
    // (ou vazia, sem permissão) — só o nome interessa aqui.
    function parseProcess(text) {
        const match = text.match(/users:\(\("([^"]+)"/);
        return match ? match[1] : "";
    }

    // ss alinha as colunas com espaços, mas nenhum campo individual (netid,
    // state, os dois endereço:porta) tem espaço dentro — dá pra separar
    // só com split(/\s+/), sobrando o resto (processo) pra juntar de volta.
    function parseLine(line) {
        const cols = line.trim().split(/\s+/);
        if (cols.length < 6) return null;
        const [netid, state, , , local, peer, ...rest] = cols;
        const localParts = root.splitAddrPort(local);
        const peerParts = root.splitAddrPort(peer);
        return {
            protocol: netid.toUpperCase(),
            state,
            localAddress: localParts.address,
            localPort: localParts.port,
            remoteAddress: peerParts.address,
            remotePort: peerParts.port,
            process: root.parseProcess(rest.join(" "))
        };
    }

    Component.onCompleted: proc.running = true

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }

    Process {
        id: proc
        command: ["ss", "-tunHp"]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                root.connections = collector.text.split("\n")
                    .map(l => root.parseLine(l))
                    .filter(c => c !== null);
                root.ready = true;
            }
        }
    }
}
