import QtQuick
import "../common"
import "../services"

/**
 * Quanto tempo o systemd levou pra subir tudo no boot (systemd-analyze),
 * com o detalhamento por fase (firmware/loader/kernel/initrd/userspace).
 * Só um dos 4 widgets de diagnóstico de boot; ver BootSessionService pra
 * quando eles aparecem/somem.
 */
Card {
    id: root
    positionKey: "systemdBootTime"
    resizable: true
    closable: true
    baseWidth: 300
    baseHeight: 170
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    onClosed: BootSessionService.dismiss(root.positionKey)

    // Avaliação baseada só no que o systemd controla de fato (kernel +
    // initrd + userspace) — ver comentário de bootRatingLevels no
    // serviço pro porquê de excluir firmware/loader (BIOS/GRUB) da
    // conta.
    readonly property var rating: BootDiagnosticsService.bootRatingFor(BootDiagnosticsService.bootOsSeconds)
    readonly property var severityColors: [Appearance.colors.accent, Appearance.colors.success, Appearance.colors.danger, Appearance.colors.danger]
    readonly property color ratingColor: root.severityColors[root.rating.severity]

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        StyledText {
            text: "TEMPO DE BOOT"
            font.bold: true
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        StyledText {
            text: "Aguardando o boot terminar..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
            visible: !BootDiagnosticsService.bootTimeReady
        }

        Row {
            spacing: 12
            visible: BootDiagnosticsService.bootTimeReady

            StyledText {
                text: BootDiagnosticsService.bootTimeTotal
                font.family: Appearance.font.familyMono
                font.pixelSize: Appearance.font.sizeLarge + 6
                color: Appearance.colors.accent
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: root.rating.label.toUpperCase()
                font.bold: true
                font.pixelSize: Appearance.font.sizeSmall
                color: root.ratingColor
            }
        }

        StyledText {
            visible: BootDiagnosticsService.bootTimeReady
            text: "avaliação com base no tempo de systemd (kernel+initrd+userspace): " + BootDiagnosticsService.bootOsSeconds.toFixed(1) + "s"
            font.pixelSize: Appearance.font.sizeSmall - 2
            color: Appearance.colors.textFaint
            wrapMode: Text.WordWrap
            width: parent.width
        }

        StyledText {
            visible: BootDiagnosticsService.bootTimeReady
            width: parent.width
            text: BootDiagnosticsService.bootTimeParts.join(" · ")
            font.pixelSize: Appearance.font.sizeSmall - 1
            color: Appearance.colors.text
            wrapMode: Text.WordWrap
        }
    }
}
