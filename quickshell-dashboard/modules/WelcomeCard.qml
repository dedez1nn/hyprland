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

        // Avatar: foto recortada em círculo, com cantos de mira ciano em
        // volta (reticle do HUD ctOS). Cai pra iniciais se avatar.png não
        // existir.
        Item {
            id: avatar
            width: 64
            height: 64
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarClip
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.surface
                clip: true

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: "../common/assets/avatar.png"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: Config.welcomeCard.greetingName.charAt(0).toUpperCase()
                    font.pixelSize: Appearance.font.sizeHuge * 0.6
                    font.bold: true
                    color: Appearance.colors.accent
                }
            }

            // cantos de mira
            Rectangle { x: -2; y: -2; width: 9; height: 2; color: Appearance.colors.accent }
            Rectangle { x: -2; y: -2; width: 2; height: 9; color: Appearance.colors.accent }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: -2; y: -2; width: 9; height: 2; color: Appearance.colors.accent }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: -2; y: -2; width: 2; height: 9; color: Appearance.colors.accent }
            Rectangle { x: -2; anchors.bottom: parent.bottom; anchors.bottomMargin: -2; width: 9; height: 2; color: Appearance.colors.accent }
            Rectangle { x: -2; anchors.bottom: parent.bottom; anchors.bottomMargin: -2; width: 2; height: 9; color: Appearance.colors.accent }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: -2; anchors.bottom: parent.bottom; anchors.bottomMargin: -2; width: 9; height: 2; color: Appearance.colors.accent }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: -2; anchors.bottom: parent.bottom; anchors.bottomMargin: -2; width: 2; height: 9; color: Appearance.colors.accent }
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

            StyledText {
                text: "STATUS :: SESSÃO ATIVA"
                font.family: Appearance.font.familyMono
                font.pixelSize: Appearance.font.sizeSmall - 2
                font.letterSpacing: 1
                color: Appearance.colors.accent
            }

            Row {
                id: statsRow
                spacing: 24

                Column {
                    spacing: 4

                    StyledText {
                        text: "TEMPO DE ATIVIDADE"
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        font.letterSpacing: 1
                        color: Appearance.colors.textMuted
                    }

                    StyledText {
                        text: ActiveTimeService.prettyText
                        font.family: Appearance.font.familyMono
                        font.pixelSize: Appearance.font.sizeSmall + 2
                        color: Appearance.colors.accent
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
                            text: "STREAK"
                            font.pixelSize: Appearance.font.sizeSmall - 2
                            font.letterSpacing: 1
                            color: Appearance.colors.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: CommitStreakService.ready
                            ? `${CommitStreakService.streak} ${CommitStreakService.streak === 1 ? "dia" : "dias"}`
                            : "checando..."
                        font.family: Appearance.font.familyMono
                        font.pixelSize: Appearance.font.sizeSmall + 2
                        color: Appearance.colors.accent
                    }
                }
            }
        }
    }
}
