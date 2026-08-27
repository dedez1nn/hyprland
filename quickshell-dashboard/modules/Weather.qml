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
        spacing: 6

        StyledText {
            text: stat.icon
            font.pixelSize: Appearance.font.sizeSmall + 1
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: stat.value
            font.family: Appearance.font.familyMono
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.textMuted
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Divisor fino entre os chips de telemetria.
    component Divider: Rectangle {
        width: 1
        height: 12
        color: Appearance.colors.cardBorder
        anchors.verticalCenter: parent.verticalCenter
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
                    font.family: Appearance.font.familyMono
                    font.pixelSize: Appearance.font.sizeLarge
                    color: Appearance.colors.accent
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
            spacing: 14

            Stat { icon: "💧"; value: WeatherService.humidity + "%" }
            Divider {}
            Stat { icon: "💨"; value: Math.round(WeatherService.windSpeed) + "km/h" }
            Divider {}
            Stat { icon: "🌧️"; value: WeatherService.rainChance + "%" }
            Divider {}
            Stat { icon: "👁️"; value: WeatherService.visibilityKm + "km" }
            Divider {}
            Stat { icon: "🌅"; value: WeatherService.sunrise }
            Divider {}
            Stat { icon: "🌇"; value: WeatherService.sunset }
        }
    }
}
