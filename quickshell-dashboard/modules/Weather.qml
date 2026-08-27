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
    implicitWidth: content.implicitWidth + 40
    implicitHeight: content.implicitHeight + 40

    component Stat: Row {
        id: stat
        required property string icon
        required property string value
        spacing: 8

        Image {
            source: stat.icon
            width: 13
            height: 13
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: stat.value
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        spacing: 14

        Row {
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
            }
        }

        Row {
            visible: WeatherService.ready
            spacing: 20

            Stat { icon: "../common/assets/humidity.svg"; value: WeatherService.humidity + "% umidade" }
            Stat { icon: "../common/assets/wind.svg"; value: Math.round(WeatherService.windSpeed) + " km/h" }
            Stat { icon: "../common/assets/rain-chance.svg"; value: WeatherService.rainChance + "% de chuva" }
            Stat { icon: "../common/assets/visibility.svg"; value: WeatherService.visibilityKm + " km vis." }
            Stat { icon: "../common/assets/sunrise.svg"; value: WeatherService.sunrise }
            Stat { icon: "../common/assets/sunset.svg"; value: WeatherService.sunset }
        }
    }
}
