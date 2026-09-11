import QtQuick
import "../common"
import "../services"

/**
 * Status geral do boot (systemctl is-system-running) + unidades que
 * falharam, se degraded. Só um dos 4 widgets de diagnóstico de boot; ver
 * BootSessionService pra quando eles aparecem/somem.
 */
Card {
    id: root
    positionKey: "bootStatus"
    resizable: true
    closable: true
    baseWidth: 300
    baseHeight: 170
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    onClosed: BootSessionService.dismiss(root.positionKey)

    readonly property bool healthy: BootDiagnosticsService.systemState === "running"
    readonly property color stateColor: root.healthy ? Appearance.colors.success : Appearance.colors.danger

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        StyledText {
            text: "STATUS DO BOOT"
            font.bold: true
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        StyledText {
            text: "Carregando..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
            visible: !BootDiagnosticsService.bootStatusReady
        }

        Row {
            spacing: 10
            visible: BootDiagnosticsService.bootStatusReady

            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: root.stateColor
            }

            StyledText {
                text: BootDiagnosticsService.systemState.toUpperCase()
                font.bold: true
                font.family: Appearance.font.familyMono
                font.pixelSize: Appearance.font.sizeLarge
                color: root.stateColor
            }
        }

        StyledText {
            visible: BootDiagnosticsService.bootStatusReady && root.healthy
            text: "Todos os serviços do systemd subiram sem falhas."
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            width: parent.width
            spacing: 6
            visible: BootDiagnosticsService.bootStatusReady && !root.healthy && BootDiagnosticsService.failedUnits.length > 0

            StyledText {
                text: BootDiagnosticsService.failedUnits.length + " serviço(s) falharam:"
                font.pixelSize: Appearance.font.sizeSmall
                color: Appearance.colors.textMuted
            }

            Repeater {
                model: BootDiagnosticsService.failedUnits

                delegate: StyledText {
                    width: parent.width
                    text: "· " + modelData
                    font.family: Appearance.font.familyMono
                    font.pixelSize: Appearance.font.sizeSmall - 1
                    color: Appearance.colors.danger
                    elide: Text.ElideRight
                }
            }
        }
    }
}
