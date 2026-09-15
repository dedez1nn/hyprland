import QtQuick
import "../common"
import "../services"

/**
 * Teste de velocidade sob demanda (ver SpeedTestService): botão "Testar
 * agora" mede ping/download/upload contra o Cloudflare speed test e
 * mostra o resultado — sai de verdade pela rede até a internet.
 */
Card {
    id: root
    positionKey: "speedTest"
    implicitWidth: 300
    implicitHeight: content.implicitHeight + 32

    // Só o número: a unidade (Mbps/Gbps) vai no label abaixo, não aqui —
    // "14.3 Gbps" inteiro no texto grande não cabe nas colunas de 1/3 do
    // card lado a lado.
    function formatValue(value) {
        return value >= 1000 ? (value / 1000).toFixed(1) : value.toFixed(1);
    }

    function formatUnit(value) {
        return value >= 1000 ? "Gbps" : "Mbps";
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        StyledText {
            width: parent.width
            text: "TESTE DE VELOCIDADE"
            font.bold: true
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        Item {
            width: parent.width
            height: button.implicitHeight

            Rectangle {
                id: button
                anchors.right: parent.right
                implicitWidth: buttonLabel.implicitWidth + 20
                implicitHeight: buttonLabel.implicitHeight + 10
                radius: Appearance.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: SpeedTestService.state === "running" ? Appearance.colors.textFaint : Appearance.colors.accent
                opacity: SpeedTestService.state === "running" ? 0.6 : 1

                StyledText {
                    id: buttonLabel
                    anchors.centerIn: parent
                    text: SpeedTestService.state === "running" ? "Testando..." : "Testar agora"
                    font.pixelSize: Appearance.font.sizeSmall
                    color: Appearance.colors.accent
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: SpeedTestService.state !== "running"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SpeedTestService.runTest()
                }
            }
        }

        Row {
            width: parent.width
            spacing: 0

            Column {
                width: parent.width / 3
                spacing: 2

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: SpeedTestService.state === "done" ? SpeedTestService.pingMs.toFixed(0) : "--"
                    font.bold: true
                    font.pixelSize: Appearance.font.sizeLarge
                    color: Appearance.colors.text
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "PING (ms)"
                    font.pixelSize: Appearance.font.sizeSmall - 2
                    color: Appearance.colors.textFaint
                }
            }

            Column {
                width: parent.width / 3
                spacing: 2

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: SpeedTestService.state === "done" ? root.formatValue(SpeedTestService.downloadMbps) : "--"
                    font.bold: true
                    font.pixelSize: Appearance.font.sizeLarge
                    color: Appearance.colors.text
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "DOWNLOAD" + (SpeedTestService.state === "done" ? " (" + root.formatUnit(SpeedTestService.downloadMbps) + ")" : "")
                    font.pixelSize: Appearance.font.sizeSmall - 2
                    color: Appearance.colors.textFaint
                }
            }

            Column {
                width: parent.width / 3
                spacing: 2

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: SpeedTestService.state === "done" ? root.formatValue(SpeedTestService.uploadMbps) : "--"
                    font.bold: true
                    font.pixelSize: Appearance.font.sizeLarge
                    color: Appearance.colors.text
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "UPLOAD" + (SpeedTestService.state === "done" ? " (" + root.formatUnit(SpeedTestService.uploadMbps) + ")" : "")
                    font.pixelSize: Appearance.font.sizeSmall - 2
                    color: Appearance.colors.textFaint
                }
            }
        }

        StyledText {
            width: parent.width
            visible: SpeedTestService.state === "error"
            text: "Falha ao rodar o teste"
            font.pixelSize: Appearance.font.sizeSmall - 2
            color: Appearance.colors.danger
        }
    }
}
