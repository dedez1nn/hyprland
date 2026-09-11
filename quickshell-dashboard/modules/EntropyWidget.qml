import QtQuick
import "../common"
import "../services"

/**
 * Entropia disponível no kernel (/proc/sys/kernel/random/entropy_avail)
 * — quanta aleatoriedade o pool do kernel tem de reserva pra geração de
 * números aleatórios criptográficos. Só um dos 4 widgets de diagnóstico
 * de boot; ver BootSessionService pra quando eles aparecem/somem.
 */
Card {
    id: root
    positionKey: "entropy"
    resizable: true
    closable: true
    baseWidth: 300
    baseHeight: 170
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    onClosed: BootSessionService.dismiss(root.positionKey)

    // Faixas de avaliação (Ótima/Boa/Adequada/Baixa/Crítica) centralizadas
    // em BootDiagnosticsService.entropyLevels — ver o comentário lá pro
    // porquê dos limiares.
    readonly property var level: BootDiagnosticsService.entropyLevelFor(BootDiagnosticsService.entropy)
    readonly property real fillRatio: Math.min(1, BootDiagnosticsService.entropy / 256)
    readonly property var severityColors: [Appearance.colors.accent, Appearance.colors.success, Appearance.colors.success, Appearance.colors.danger, Appearance.colors.danger]
    readonly property color statusColor: root.severityColors[root.level.severity]

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        StyledText {
            text: "ENTROPIA DO SISTEMA"
            font.bold: true
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        Row {
            spacing: 12

            StyledText {
                text: BootDiagnosticsService.entropyReady ? BootDiagnosticsService.entropy : "…"
                font.family: Appearance.font.familyMono
                font.pixelSize: Appearance.font.sizeLarge + 6
                color: root.statusColor
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: root.level.label.toUpperCase()
                font.bold: true
                font.pixelSize: Appearance.font.sizeSmall
                color: root.statusColor
                visible: BootDiagnosticsService.entropyReady
            }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 3
            color: Appearance.colors.surface
            border.width: 1
            border.color: Appearance.colors.cardBorder

            Rectangle {
                height: parent.height
                width: parent.width * root.fillRatio
                radius: 3
                color: root.statusColor
            }
        }

        // Escala completa (pior → melhor) com o nível atual destacado —
        // ajuda a comparar visualmente onde o valor de agora cai.
        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: [...BootDiagnosticsService.entropyLevels].reverse()

                delegate: StyledText {
                    readonly property bool current: modelData.label === root.level.label
                    text: modelData.label
                    font.pixelSize: Appearance.font.sizeSmall - 2
                    font.bold: current
                    color: current ? root.statusColor : Appearance.colors.textFaint
                }
            }
        }
    }
}
