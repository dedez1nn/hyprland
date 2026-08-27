import QtQuick
import "../common"
import "../services"

/**
 * Card de boas-vindas: avatar (placeholder, sem foto por enquanto),
 * saudação de acordo com o horário, tempo ativo na sessão (exclui tempo
 * ocioso — ver ActiveTimeService) e streak de dias seguidos commitando
 * (ver CommitStreakService).
 */
Card {
    id: root
    positionKey: "welcomeCard"
    implicitWidth: Config.welcomeCard.width
    implicitHeight: content.implicitHeight + 40

    readonly property string greeting: {
        switch (ClockService.greetingPeriod) {
        case "madrugada": return "Boa madrugada";
        case "manhã": return "Bom dia";
        case "tarde": return "Boa tarde";
        default: return "Boa noite";
        }
    }

    Row {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Avatar placeholder: círculo com a inicial do nome.
        // Trocar por Image quando tiver uma foto definida.
        Rectangle {
            id: avatar
            width: 64
            height: 64
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Appearance.colors.accent

            StyledText {
                anchors.centerIn: parent
                text: Config.welcomeCard.greetingName.charAt(0).toUpperCase()
                font.pixelSize: Appearance.font.sizeHuge * 0.6
                font.bold: true
                color: Appearance.colors.background
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            StyledText {
                width: statsRow.implicitWidth
                horizontalAlignment: Text.AlignHCenter
                text: `${root.greeting}, ${Config.welcomeCard.greetingName}`
                font.pixelSize: Appearance.font.sizeLarge
                font.bold: true
            }

            Row {
                id: statsRow
                spacing: 24

                Column {
                    spacing: 4

                    StyledText {
                        text: "Tempo de atividade"
                        font.pixelSize: Appearance.font.sizeSmall
                        color: Appearance.colors.textMuted
                    }

                    StyledText {
                        text: ActiveTimeService.prettyText
                        font.pixelSize: Appearance.font.sizeSmall
                        font.bold: true
                    }
                }

                Column {
                    spacing: 4

                    Row {
                        spacing: 6

                        Image {
                            source: "../common/assets/git.png"
                            width: 14
                            height: 14
                            smooth: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "streak:"
                            font.pixelSize: Appearance.font.sizeSmall
                            color: Appearance.colors.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: CommitStreakService.ready
                            ? `${CommitStreakService.streak} ${CommitStreakService.streak === 1 ? "dia" : "dias"}`
                            : "checando..."
                        font.pixelSize: Appearance.font.sizeSmall
                        font.bold: true
                    }
                }
            }
        }
    }
}
