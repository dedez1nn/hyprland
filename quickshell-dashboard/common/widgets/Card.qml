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
 *
 * `resizable: true` liga as alças de redimensionar nas bordas
 * direita/inferior (largura/altura isoladas) e no canto inferior-direito
 * (as duas juntas, na diagonal) — mesmo mecanismo usado antes só no
 * QuickNotes, agora aqui pra qualquer Card poder usar. Quem ativa isso
 * deve setar `baseWidth`/`baseHeight` (tamanho mínimo, e o default antes
 * de qualquer resize salvo) e bindar seu implicitWidth/implicitHeight a
 * `cardWidth`/`cardHeight` — o Card não pode impor isso sozinho porque
 * um Card sem resizable (a maioria) precisa poder seguir definindo seu
 * implicitWidth do jeito que já faz hoje, sem o base brigar com isso.
 * Tamanho persistido em WidgetSizeService, por positionKey.
 *
 * `closable: true` liga um "✕" no canto superior-direito; clicar emite
 * `closed()` — quem usa o Card decide o que "fechar" significa (ex: os
 * widgets de diagnóstico de boot chamam BootSessionService.dismiss()).
 * O Card não esconde nada por conta própria.
 */
Item {
    id: root

    property string positionKey: ""
    property bool resizable: false
    property real baseWidth: 300
    property real baseHeight: 200
    property bool closable: false
    signal closed()

    property real cardWidth: WidgetSizeService.getSize(root.positionKey)?.width ?? root.baseWidth
    property real cardHeight: WidgetSizeService.getSize(root.positionKey)?.height ?? root.baseHeight

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

    // Cantos de mira ciano (canto superior-esquerdo + inferior-direito) —
    // assinatura visual do HUD ctOS/DedSec. Só Rectangles simples, sem
    // shader extra.
    Rectangle { x: 0; y: 0; width: 12; height: 2; color: Appearance.colors.accentAlt }
    Rectangle { x: 0; y: 0; width: 2; height: 12; color: Appearance.colors.accentAlt }
    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 12; height: 2; color: Appearance.colors.accentAlt }
    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 12; color: Appearance.colors.accentAlt }

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

    ResizeHandles {
        visible: root.resizable
        enabled: root.resizable
        target: root
        positionKey: root.positionKey
        minWidth: root.baseWidth
        minHeight: root.baseHeight
    }

    Rectangle {
        id: closeButton
        visible: root.closable
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        z: 60
        width: 18
        height: 18
        radius: 9
        color: closeArea.containsMouse ? Appearance.colors.danger : "transparent"
        border.width: 1
        border.color: closeArea.containsMouse ? Appearance.colors.danger : Appearance.colors.cardBorder

        StyledText {
            anchors.centerIn: parent
            text: "✕"
            font.pixelSize: Appearance.font.sizeSmall - 2
            color: closeArea.containsMouse ? Appearance.colors.background : Appearance.colors.textMuted
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closed()
        }
    }
}
