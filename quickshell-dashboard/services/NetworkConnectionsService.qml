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
 *
 * Também mantém um histórico de hosts remotos (`history`, chave
 * process+endereço+porta) pra identificar conexões recorrentes: algo que
 * reconecta com frequência ao longo do tempo, não só o que está aberto
 * agora. Persistido em config/network-history.json, específico da
 * máquina, no mesmo espírito do sizes.json (fora do controle de versão).
 */
Singleton {
    id: root

    property var connections: []
    property bool ready: false

    // Lista de processos confiáveis pro widget marcar o resto como fora
    // da allowlist (ver network-allowlist.example.json). Arquivo real é
    // opcional e pessoal, por isso fica de fora do controle de versão
    // (ver .gitignore); sem ele, esse critério de suspeita fica desligado
    // em vez de marcar tudo como suspeito por falta de configuração.
    property var allowlist: []
    readonly property bool allowlistConfigured: root.allowlist.length > 0

    property var history: ({})
    property bool historyDirty: false
    readonly property var historyEntries: Object.keys(root.history).map(k => root.history[k])
    // Acima disso, uma entrada some do histórico. Evita crescer pra
    // sempre com hosts que só apareceram uma vez há meses.
    readonly property int maxHistoryAgeMs: 14 * 24 * 60 * 60 * 1000

    function historyKey(conn) {
        return (conn.process || "?") + "|" + conn.remoteAddress + "|" + conn.remotePort;
    }

    // Endereços "coringa" (LISTEN/UNCONN não têm host remoto de verdade)
    // não interessam pro histórico de conexões recorrentes.
    function isRealRemote(address) {
        return address.length > 0 && address !== "*" && address !== "0.0.0.0" && address !== "::";
    }

    function updateHistory(conns) {
        const now = Date.now();
        const next = Object.assign({}, root.history);
        for (const c of conns) {
            if (!root.isRealRemote(c.remoteAddress)) continue;
            const key = root.historyKey(c);
            const prev = next[key];
            if (prev) {
                next[key] = Object.assign({}, prev, { lastSeen: now, seenCount: prev.seenCount + 1 });
            } else {
                next[key] = {
                    process: c.process, remoteAddress: c.remoteAddress, remotePort: c.remotePort,
                    firstSeen: now, lastSeen: now, seenCount: 1
                };
            }
        }
        for (const key of Object.keys(next)) {
            if (now - next[key].lastSeen > root.maxHistoryAgeMs) delete next[key];
        }
        root.history = next;
        root.historyDirty = true;
    }

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
                root.updateHistory(root.connections);
            }
        }
    }

    FileView {
        id: allowlistFile
        path: Qt.resolvedUrl("../config/network-allowlist.json")
        onLoadedChanged: {
            try {
                const data = JSON.parse(allowlistFile.text());
                root.allowlist = (data.processes || []).map(p => p.toLowerCase());
            } catch (e) {
                root.allowlist = [];
            }
        }
        onLoadFailed: (error) => { root.allowlist = []; }
    }

    FileView {
        id: historyFile
        path: Qt.resolvedUrl("../config/network-history.json")
        onLoadedChanged: {
            try {
                root.history = JSON.parse(historyFile.text());
            } catch (e) {
                root.history = {};
            }
        }
        onLoadFailed: (error) => { root.history = {}; }
    }

    // Throttle: grava a cada 30s se algo mudou, não a cada poll de 5s.
    // O histórico não precisa estar em disco com precisão de segundos.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (!root.historyDirty) return;
            historyFile.setText(JSON.stringify(root.history, null, 2));
            root.historyDirty = false;
        }
    }
}
