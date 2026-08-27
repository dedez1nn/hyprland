import QtQuick
import QtQuick.Effects
import ".."
import "../../services"

/**
 * Fundo padrão usado por todo widget do dashboard (WelcomeCard,
 * ClockCalendar, Weather, etc): relevo suave, fundo semi-transparente
 * (deixa o wallpaper aparecer de leve) com uma borda fina pra marcar o
 * contorno. Uma RectangularShadow (sombra escura embaixo/direita) sugere
 * o card esculpido do próprio fundo — shader dedicado do QtQuick.Effects,
 * bem mais barato que um blur genérico atrás do card inteiro. Antes eram
 * duas sombras (+ uma clara em cima/esquerda); cortada pra reduzir o
 * número de shaders ativos (memória) — ver BACKLOG.md.
 *
 * Também dá pra arrastar segurando em qualquer área vazia do card — a
 * MouseArea de arrastar cobre o card inteiro, mas fica declarada antes do
 * conteúdo de cada widget, então qualquer botão/MouseArea próprio (ex: os
 * controles do MusicPlayer) fica por cima na ordem de pintura e continua
 * clicável normalmente; só onde não tem nada por cima é que o clique vira
 * arrasto. Posição final salva em WidgetPositionService, volta no próximo
 * reload. Widgets que não definem positionKey não salvam posição.
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

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Appearance.radiusNormal
        color: Appearance.colors.cardBackground
        border.width: 1
        border.color: Appearance.colors.cardBorder
    }

    // Arrastar o card: cobre a área inteira, mas fica embaixo do conteúdo
    // de cada widget na ordem de pintura (ver comentário acima).
    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root

        onPressed: WidgetPositionService.dragging = true

        onReleased: {
            WidgetPositionService.dragging = false;
            if (root.positionKey.length > 0) {
                WidgetPositionService.set(root.positionKey, root.x, root.y);
            }
        }
    }
}
