import QtQuick
import "../common"
import "../services"

/**
 * Clima atual (Open-Meteo) + cidade detectada por IP.
 * Ver services/WeatherService.qml pro cuidado com ProtonVPN.
 */
Card {
    id: root
    positionKey: "weather"
    implicitWidth: Config.clock.width
    implicitHeight: 128

    Row {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: WeatherService.icon
            font.pixelSize: Appearance.font.sizeHuge
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StyledText {
                text: WeatherService.temperatureText
                font.pixelSize: Appearance.font.sizeLarge
                font.bold: true
            }

            StyledText {
                text: WeatherService.ready
                    ? `${WeatherService.description} · ${WeatherService.cityName}`
                    : (WeatherService.error ? "Clima indisponível" : "Carregando clima...")
                font.pixelSize: Appearance.font.sizeSmall
                color: Appearance.colors.textMuted
            }

            Row {
                visible: WeatherService.ready
                spacing: 10

                Image {
                    source: "../common/assets/humidity.svg"
                    width: 12
                    height: 12
                    smooth: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: WeatherService.humidity + "%"
                    font.pixelSize: Appearance.font.sizeSmall
                    color: Appearance.colors.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }

                Image {
                    source: "../common/assets/wind.svg"
                    width: 12
                    height: 12
                    smooth: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: Math.round(WeatherService.windSpeed) + " km/h"
                    font.pixelSize: Appearance.font.sizeSmall
                    color: Appearance.colors.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
