import QtQuick
import QtQuick.Effects
import ".."
import "../../services"

/**
 * Fundo padrão usado por todo widget do dashboard (WelcomeCard,
 * ClockCalendar, Weather, etc): relevo suave, fundo semi-transparente
 * (deixa o wallpaper aparecer de leve) com uma borda fina pra marcar o
 * contorno. Duas RectangularShadow (sombra escura embaixo/direita + luz
 * sutil em cima/esquerda) simulam o card sendo esculpido do próprio
 * fundo, cada uma como um shader dedicado do QtQuick.Effects — bem mais
 * barato que um blur genérico atrás do card inteiro.
 *
 * Também dá pra arrastar pela alça (as "três ranhuras") no canto superior
 * direito — a posição final é salva em WidgetPositionService e volta no
 * próximo reload. Widgets que não definem positionKey não salvam posição.
 */
Item {
    id: root

    property string positionKey: ""

    z: dragArea.drag.active ? 100 : 0

    RectangularShadow {
        anchors.fill: surface
        z: -1
        radius: surface.radius
        color: Appearance.colors.shadowDark
        offset: Qt.vector2d(7, 7)
        blur: 22
        spread: 1
        cached: true
    }

    RectangularShadow {
        anchors.fill: surface
        z: -1
        radius: surface.radius
        color: Appearance.colors.shadowLight
        offset: Qt.vector2d(-5, -5)
        blur: 18
        spread: 1
        cached: true
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Appearance.radiusNormal
        color: Appearance.colors.cardBackground
        border.width: 1
        border.color: Appearance.colors.cardBorder
    }

    // Alça de arrastar: três ranhuras no canto superior direito.
    Item {
        id: dragHandle
        width: 28
        height: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4

        Column {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: 3

                Rectangle {
                    width: 14
                    height: 2
                    radius: 1
                    color: Appearance.colors.textMuted
                    opacity: dragArea.containsMouse || dragArea.drag.active ? 0.9 : 0.5
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: root

            onReleased: {
                if (root.positionKey.length > 0) {
                    WidgetPositionService.set(root.positionKey, root.x, root.y);
                }
            }
        }
    }
}
