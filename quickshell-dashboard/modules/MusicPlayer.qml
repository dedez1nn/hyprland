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
            border.width: 1
            border.color: Appearance.colors.borderBright
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
                text: "♫"
                color: Appearance.colors.accent
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

            component TransportButton: Rectangle {
                id: btn
                required property string glyph
                signal clicked()

                width: 26
                height: 26
                color: btnArea.containsMouse ? Appearance.colors.accentAlt : "transparent"
                border.width: 1
                border.color: Appearance.colors.borderBright

                StyledText {
                    anchors.centerIn: parent
                    text: btn.glyph
                    color: Appearance.colors.accent
                    font.pixelSize: 13
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btn.clicked()
                }
            }

            TransportButton { glyph: "⏮"; onClicked: MediaService.previous() }
            TransportButton { glyph: MediaService.playing ? "⏸" : "▶"; onClicked: MediaService.playPause() }
            TransportButton { glyph: "⏭"; onClicked: MediaService.next() }
        }
    }
}
