import QtQuick
import "../common"
import "../services"

/**
 * Conexões de rede ativas da sessão (`ss -tunp`, ver
 * NetworkConnectionsService): protocolo, endereço remoto e estado de cada
 * socket TCP/UDP aberto. Ordenado por relevância (ESTAB primeiro, depois
 * estados de transição, LISTEN/UNCONN por último) — quem quer ver é
 * conexão de verdade acontecendo, não a lista inteira de portas escutando.
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

        StyledText {
            anchors.top: header.bottom
            anchors.topMargin: 10
            visible: !NetworkConnectionsService.ready
            text: "Carregando..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: header.bottom
            anchors.topMargin: 10
            visible: NetworkConnectionsService.ready && root.sortedConnections.length === 0
            text: "Nenhuma conexão de rede aberta"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        ListView {
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: NetworkConnectionsService.ready && root.sortedConnections.length > 0
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
    }
}
