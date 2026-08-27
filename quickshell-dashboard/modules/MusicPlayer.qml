import QtQuick
import "../common"
import "../services"

/**
 * Mini player. Só é exibido (ver DashboardWindow.qml) quando
 * MediaService.active é true, ou seja, quando o que está tocando é
 * realmente o YouTube Music — não aparece pra outros players/abas.
 */
Card {
    id: root
    positionKey: "musicPlayer"
    implicitWidth: Config.clock.width
    implicitHeight: 96

    Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Rectangle {
            width: 56
            height: 56
            radius: Appearance.radiusSmall
            color: Appearance.colors.surface
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: MediaService.artUrl
                visible: MediaService.artUrl.length > 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            StyledText {
                anchors.centerIn: parent
                visible: MediaService.artUrl.length === 0
                text: "🎵"
                font.pixelSize: 24
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 118
            spacing: 4

            StyledText {
                width: parent.width
                text: MediaService.title.length > 0 ? MediaService.title : "YouTube Music"
                font.pixelSize: Appearance.font.sizeNormal
                font.bold: true
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: MediaService.artist
                font.pixelSize: Appearance.font.sizeSmall
                color: Appearance.colors.textMuted
                elide: Text.ElideRight
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            StyledText {
                text: "⏮"
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaService.previous()
                }
            }

            StyledText {
                text: MediaService.playing ? "⏸" : "▶"
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaService.playPause()
                }
            }

            StyledText {
                text: "⏭"
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaService.next()
                }
            }
        }
    }
}
