import QtQuick
import "../common"
import "../services"

/**
 * Conexões de rede ativas da sessão (`ss -tunp`, ver
 * NetworkConnectionsService): protocolo, endereço remoto e estado de cada
 * socket TCP/UDP aberto. Ordenado por relevância (ESTAB primeiro, depois
 * estados de transição, LISTEN/UNCONN por último) — quem quer ver é
 * conexão de verdade acontecendo, não a lista inteira de portas escutando.
 *
 * Aba "RECORRENTES": hosts que reconectam com frequência ao longo do
 * tempo (histórico em NetworkConnectionsService.history), não só o
 * snapshot do momento. O ponto verde marca quem está ativo agora.
 */
Card {
    id: root
    positionKey: "networkConnections"
    resizable: true
    baseWidth: 380
    baseHeight: 280
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    readonly property var statePriority: ({
        "ESTAB": 0,
        "SYN-SENT": 1, "SYN-RECV": 1,
        "FIN-WAIT-1": 2, "FIN-WAIT-2": 2, "CLOSE-WAIT": 2, "CLOSING": 2, "LAST-ACK": 2,
        "TIME-WAIT": 3,
        "LISTEN": 4, "UNCONN": 4
    })

    function stateColor(state) {
        if (state === "ESTAB") return Appearance.colors.success;
        if (state === "LISTEN" || state === "UNCONN") return Appearance.colors.accentAlt;
        return Appearance.colors.textMuted;
    }

    readonly property var sortedConnections: [...NetworkConnectionsService.connections].sort((a, b) =>
        (root.statePriority[a.state] ?? 5) - (root.statePriority[b.state] ?? 5)
    )

    readonly property int establishedCount: NetworkConnectionsService.connections.filter(c => c.state === "ESTAB").length

    property string viewMode: "now" // "now" | "recurring"

    // "Recorrente" exige as duas coisas: aparecer em vários polls (não só
    // uma vez de passagem) E ao longo de uma janela real de tempo. Só o
    // contador de polls sozinho marcaria como recorrente uma conexão só
    // que ficou aberta e contínua por alguns minutos, o que não é o
    // padrão de reconexão habitual que esse painel quer destacar.
    readonly property int minRecurringSeen: 5
    readonly property int minRecurringSpanMs: 60 * 60 * 1000

    readonly property var recurringList: NetworkConnectionsService.historyEntries
        .filter(e => e.seenCount >= root.minRecurringSeen && (e.lastSeen - e.firstSeen) >= root.minRecurringSpanMs)
        .sort((a, b) => b.seenCount - a.seenCount)

    function isActiveNow(entry) {
        return NetworkConnectionsService.connections.some(c =>
            (c.process || "?") === entry.process && c.remoteAddress === entry.remoteAddress && c.remotePort === entry.remotePort
        );
    }

    function daysAgo(timestamp) {
        const days = Math.floor((Date.now() - timestamp) / 86400000);
        if (days <= 0) return "hoje";
        return "há " + days + (days === 1 ? " dia" : " dias");
    }

    // Portas de serviço bem conhecidas — sem isso, todo processo do
    // sistema sem nome resolvido (comum sem sudo, ver NetworkConnectionsService)
    // apareceria como suspeito só por existir.
    readonly property var commonPorts: ({
        "80": true, "443": true, "53": true, "22": true, "21": true, "25": true,
        "465": true, "587": true, "993": true, "995": true, "143": true, "110": true,
        "123": true, "3478": true
    })

    readonly property int volumeThreshold: 8
    readonly property int recentWindowMs: 5 * 60 * 1000
    readonly property int recentNewThreshold: 10

    // Destinos DISTINTOS por processo agora, não total de sockets: um
    // processo pode ter várias dezenas de conexões ESTAB abertas pro
    // mesmo servidor (streams paralelos, HTTP/1.1 sem multiplexação,
    // etc.) sem que isso seja fan-out nenhum. O sinal de scanning é
    // quantos hosts diferentes, não quantos sockets.
    readonly property var activeCountByProcess: {
        const seenDest = {};
        const counts = {};
        for (const c of NetworkConnectionsService.connections) {
            if (c.state !== "ESTAB") continue;
            const key = c.process || "?";
            const destKey = key + "|" + c.remoteAddress + "|" + c.remotePort;
            if (seenDest[destKey]) continue;
            seenDest[destKey] = true;
            counts[key] = (counts[key] || 0) + 1;
        }
        return counts;
    }

    // Quantos hosts novos (primeira vez vista) cada processo abriu nos
    // últimos 5 minutos: martelar hosts novos o tempo todo também é sinal
    // de scanning, mesmo sem muitas conexões simultâneas agora.
    readonly property var recentNewCountByProcess: {
        const now = Date.now();
        const counts = {};
        for (const e of NetworkConnectionsService.historyEntries) {
            if (now - e.firstSeen > root.recentWindowMs) continue;
            const key = e.process || "?";
            counts[key] = (counts[key] || 0) + 1;
        }
        return counts;
    }

    // LISTEN/UNCONN ficam de fora: são sockets escutando, não conexões
    // saindo pra um host, então "porta incomum"/"allowlist" não fazem
    // sentido pra eles do jeito que estão definidos aqui.
    function suspicionReasons(conn) {
        if (conn.state === "LISTEN" || conn.state === "UNCONN") return [];

        const reasons = [];
        const processKey = conn.process || "?";
        const hasProcess = conn.process.length > 0;

        if (!hasProcess && !root.commonPorts[conn.remotePort]) {
            reasons.push("processo não identificado + porta incomum");
        }
        if (hasProcess && NetworkConnectionsService.allowlistConfigured &&
            !NetworkConnectionsService.allowlist.includes(conn.process.toLowerCase())) {
            reasons.push("fora da allowlist");
        }
        const activeCount = root.activeCountByProcess[processKey] || 0;
        if (activeCount >= root.volumeThreshold) {
            reasons.push(activeCount + " destinos distintos agora");
        }
        const recentCount = root.recentNewCountByProcess[processKey] || 0;
        if (recentCount >= root.recentNewThreshold) {
            reasons.push(recentCount + " hosts novos em 5min");
        }
        return reasons;
    }

    readonly property var suspiciousConnections: root.sortedConnections
        .map(c => ({ conn: c, reasons: root.suspicionReasons(c) }))
        .filter(x => x.reasons.length > 0)

    // Item (não Column) pelo mesmo motivo do QuickNotes: a lista precisa
    // preencher exatamente o espaço que sobra abaixo do cabeçalho, sem uma
    // altura fixa "chutada" que vaza pra fora do card quando o card é
    // redimensionado.
    Item {
        anchors.fill: parent
        anchors.margins: 16
        clip: true

        Row {
            id: header
            anchors.top: parent.top
            width: parent.width

            StyledText {
                width: parent.width - countBadge.width
                text: "CONEXÕES DE REDE"
                font.bold: true
                font.letterSpacing: 1
                color: Appearance.colors.textMuted
            }

            Rectangle {
                id: countBadge
                width: Math.max(20, countLabel.implicitWidth + 8)
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.accentAlt
                visible: NetworkConnectionsService.ready

                StyledText {
                    id: countLabel
                    anchors.centerIn: parent
                    text: root.establishedCount + " ativa" + (root.establishedCount === 1 ? "" : "s")
                    font.family: Appearance.font.familyMono
                    font.pixelSize: Appearance.font.sizeSmall - 2
                    color: Appearance.colors.accent
                }
            }
        }

        Row {
            id: tabsRow
            anchors.top: header.bottom
            anchors.topMargin: 8
            spacing: 14

            StyledText {
                text: "AGORA"
                font.bold: root.viewMode === "now"
                font.letterSpacing: 1
                font.pixelSize: Appearance.font.sizeSmall - 1
                color: root.viewMode === "now" ? Appearance.colors.accent : Appearance.colors.textFaint

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMode = "now"
                }
            }

            StyledText {
                text: "RECORRENTES"
                font.bold: root.viewMode === "recurring"
                font.letterSpacing: 1
                font.pixelSize: Appearance.font.sizeSmall - 1
                color: root.viewMode === "recurring" ? Appearance.colors.accent : Appearance.colors.textFaint

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMode = "recurring"
                }
            }

            StyledText {
                text: "SUSPEITAS" + (root.suspiciousConnections.length > 0 ? " (" + root.suspiciousConnections.length + ")" : "")
                font.bold: root.viewMode === "suspicious"
                font.letterSpacing: 1
                font.pixelSize: Appearance.font.sizeSmall - 1
                // Fica em vermelho sempre que houver algo pra ver, mesmo em
                // outra aba — é o tipo de coisa que vale chamar atenção.
                color: root.viewMode === "suspicious" ? Appearance.colors.accent
                    : (root.suspiciousConnections.length > 0 ? Appearance.colors.danger : Appearance.colors.textFaint)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewMode = "suspicious"
                }
            }
        }

        StyledText {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            visible: !NetworkConnectionsService.ready
            text: "Carregando..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            visible: NetworkConnectionsService.ready && root.viewMode === "now" && root.sortedConnections.length === 0
            text: "Nenhuma conexão de rede aberta"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            width: parent.width
            wrapMode: Text.WordWrap
            visible: NetworkConnectionsService.ready && root.viewMode === "recurring" && root.recurringList.length === 0
            text: "Nenhuma conexão recorrente identificada ainda (precisa reconectar por mais de 1h de histórico)"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            visible: NetworkConnectionsService.ready && root.viewMode === "suspicious" && root.suspiciousConnections.length === 0
            text: "Nada suspeito por aqui"
            color: Appearance.colors.success
            font.pixelSize: Appearance.font.sizeSmall
        }

        ListView {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: NetworkConnectionsService.ready && root.viewMode === "now" && root.sortedConnections.length > 0
            clip: true
            spacing: 3
            model: root.sortedConnections

            delegate: Item {
                width: ListView.view.width
                height: 32

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 1

                    Row {
                        width: parent.width
                        spacing: 8

                        StyledText {
                            width: 34
                            text: modelData.protocol
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            color: Appearance.colors.textFaint
                        }

                        StyledText {
                            width: parent.width - 34 - 70 - 16
                            text: modelData.remoteAddress + (modelData.remotePort.length > 0 && modelData.remotePort !== "*" ? ":" + modelData.remotePort : "")
                            elide: Text.ElideRight
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall
                            color: Appearance.colors.text
                        }

                        StyledText {
                            width: 70
                            horizontalAlignment: Text.AlignRight
                            text: modelData.state
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            color: root.stateColor(modelData.state)
                        }
                    }

                    StyledText {
                        visible: modelData.process.length > 0
                        text: modelData.process
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        color: Appearance.colors.textFaint
                    }
                }
            }
        }

        ListView {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: NetworkConnectionsService.ready && root.viewMode === "recurring" && root.recurringList.length > 0
            clip: true
            spacing: 3
            model: root.recurringList

            delegate: Item {
                width: ListView.view.width
                height: 32

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 1

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isActiveNow(modelData) ? Appearance.colors.success : Appearance.colors.textFaint
                        }

                        StyledText {
                            width: parent.width - 6 - 8 - 40 - 8
                            text: modelData.remoteAddress + (modelData.remotePort.length > 0 && modelData.remotePort !== "*" ? ":" + modelData.remotePort : "")
                            elide: Text.ElideRight
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall
                            color: Appearance.colors.text
                        }

                        StyledText {
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: modelData.seenCount + "x"
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            color: Appearance.colors.accent
                        }
                    }

                    StyledText {
                        text: (modelData.process.length > 0 ? modelData.process : "processo desconhecido") + " · " + root.daysAgo(modelData.firstSeen)
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        color: Appearance.colors.textFaint
                    }
                }
            }
        }

        ListView {
            anchors.top: tabsRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: NetworkConnectionsService.ready && root.viewMode === "suspicious" && root.suspiciousConnections.length > 0
            clip: true
            spacing: 3
            model: root.suspiciousConnections

            delegate: Item {
                width: ListView.view.width
                height: 32

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 1

                    Row {
                        width: parent.width
                        spacing: 8

                        StyledText {
                            width: 34
                            text: modelData.conn.protocol
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            color: Appearance.colors.textFaint
                        }

                        StyledText {
                            width: parent.width - 34 - 70 - 16
                            text: modelData.conn.remoteAddress + (modelData.conn.remotePort.length > 0 && modelData.conn.remotePort !== "*" ? ":" + modelData.conn.remotePort : "")
                            elide: Text.ElideRight
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall
                            color: Appearance.colors.text
                        }

                        StyledText {
                            width: 70
                            horizontalAlignment: Text.AlignRight
                            text: modelData.conn.state
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            color: root.stateColor(modelData.conn.state)
                        }
                    }

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (modelData.conn.process.length > 0 ? modelData.conn.process + " · " : "") + modelData.reasons.join(", ")
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        color: Appearance.colors.danger
                    }
                }
            }
        }
    }
}
