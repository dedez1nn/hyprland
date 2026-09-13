import QtQuick
import "../common"
import "../services"

/**
 * Switch pra ligar/desligar a suspensão automática por inatividade. Ver
 * IdleSuspendService pro mecanismo (systemd-inhibit) e o que continua
 * funcionando mesmo desativado (aviso de ociosidade, bloqueio de tela).
 */
Card {
    id: root
    positionKey: "idleSuspend"
    implicitWidth: 230
    implicitHeight: content.implicitHeight + 32

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        StyledText {
            text: "SUSPENSÃO AUTOMÁTICA"
            font.bold: true
            font.letterSpacing: 1
            color: Appearance.colors.textMuted
        }

        Row {
            spacing: 10

            Rectangle {
                id: track
                width: 40
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: IdleSuspendService.suspendEnabled ? Appearance.colors.accent : Appearance.colors.surface
                border.width: 1
                border.color: IdleSuspendService.suspendEnabled ? Appearance.colors.accent : Appearance.colors.cardBorder

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: IdleSuspendService.suspendEnabled ? parent.width - width - 2 : 2
                    color: IdleSuspendService.suspendEnabled ? Appearance.colors.background : Appearance.colors.textMuted

                    Behavior on x {
                        NumberAnimation { duration: Appearance.animationFast }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IdleSuspendService.setSuspendEnabled(!IdleSuspendService.suspendEnabled)
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: IdleSuspendService.suspendEnabled ? "Ativada" : "Desativada"
                color: IdleSuspendService.suspendEnabled ? Appearance.colors.text : Appearance.colors.textMuted
            }
        }
    }
}
