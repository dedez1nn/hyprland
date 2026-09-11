import QtQuick
import "../common"
import "../services"

/**
 * Kernel taint (/proc/sys/kernel/tainted) — sinaliza módulos fora do
 * comum, panics anteriores, firmware remendado etc. (ver o mapeamento de
 * bits em BootDiagnosticsService.taintFlags). Só um dos 4 widgets de
 * diagnóstico de boot; ver BootSessionService pra quando eles
 * aparecem/somem.
 */
Card {
    id: root
    positionKey: "kernelTaint"
    resizable: true
    closable: true
    baseWidth: 300
    baseHeight: 170
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    onClosed: BootSessionService.dismiss(root.positionKey)

    readonly property bool clean: BootDiagnosticsService.taintValue === 0

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        StyledText {
            text: "SAÚDE DO KERNEL"
            font.bold: true
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        Row {
            spacing: 10
            visible: BootDiagnosticsService.taintReady

            StyledText {
                text: root.clean ? "✓" : "⚠"
                font.pixelSize: Appearance.font.sizeLarge
                color: root.clean ? Appearance.colors.success : Appearance.colors.danger
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.clean ? "Kernel limpo" : ("Tainted (" + BootDiagnosticsService.taintValue + ")")
                font.bold: true
                color: root.clean ? Appearance.colors.success : Appearance.colors.danger
            }
        }

        StyledText {
            text: "Carregando..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
            visible: !BootDiagnosticsService.taintReady
        }

        Column {
            width: parent.width
            spacing: 6
            visible: BootDiagnosticsService.taintReady && !root.clean

            Repeater {
                model: BootDiagnosticsService.activeTaintFlags

                delegate: Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: 22
                        height: 16
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.danger

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.letter
                            font.family: Appearance.font.familyMono
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            color: Appearance.colors.danger
                        }
                    }

                    StyledText {
                        width: parent.width - 30
                        text: modelData.desc
                        font.pixelSize: Appearance.font.sizeSmall
                        color: Appearance.colors.text
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
