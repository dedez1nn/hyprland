import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"
import "../services"

/**
 * Janela em layer-shell cobrindo a tela inteira, com os widgets espalhados
 * (cada um numa posição padrão diferente) em vez de empilhados num canto.
 * Não rouba foco de teclado nem bloqueia cliques fora dos cards (mask =
 * união da área de cada widget individualmente).
 *
 * Cada widget usa x/y (não anchors) porque dá pra arrastar pela alça no
 * canto do Card — anchors reescreveriam a posição a cada relayout e
 * brigariam com o drag. Sem posição salva em WidgetPositionService, cai na
 * posição padrão calculada abaixo; a posição arrastada é salva e volta no
 * próximo reload.
 *
 * Só fica visível quando o workspace atual está sem janelas
 * (HyprlandWorkspaceService) — funciona como uma área de trabalho, não uma
 * sobreposição por cima do que você está usando. A camada Bottom é mantida
 * como reforço, pra não flashar por cima de uma janela nova entre o evento
 * do Hyprland e a atualização do estado.
 *
 * Enquanto WidgetPositionService.dragging é true, a mask vira a tela
 * inteira (sem isso, o Hyprland para de mandar eventos de mouse assim que
 * o cursor sai da área minúscula de um card durante o arraste).
 */
PanelWindow {
    id: root
    screen: Quickshell.screens[0]
    visible: HyprlandWorkspaceService.isEmpty
    color: "transparent"

    WlrLayershell.namespace: "quickshell:dashboard"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Region {
        id: cardsRegion
        Region { item: welcomeCard }
        Region { item: clockCalendar }
        Region { item: musicPlayer }
        Region { item: weather }
    }

    mask: WidgetPositionService.dragging ? null : cardsRegion

    WelcomeCard {
        id: welcomeCard
        visible: Config.widgets.welcomeCard
        x: WidgetPositionService.get(positionKey)?.x ?? ((root.width - width) / 2)
        y: WidgetPositionService.get(positionKey)?.y ?? Config.position.margin
    }

    ClockCalendar {
        id: clockCalendar
        visible: Config.widgets.clock
        x: WidgetPositionService.get(positionKey)?.x ?? Config.position.margin
        y: WidgetPositionService.get(positionKey)?.y ?? ((root.height - height) / 2)
    }

    MusicPlayer {
        id: musicPlayer
        visible: Config.widgets.musicPlayer && MediaService.active
        x: WidgetPositionService.get(positionKey)?.x ?? (root.width - width - Config.position.margin)
        y: WidgetPositionService.get(positionKey)?.y ?? ((root.height - height) / 2)
    }

    Weather {
        id: weather
        visible: Config.widgets.weather
        x: WidgetPositionService.get(positionKey)?.x ?? (root.width - width - Config.position.margin)
        y: WidgetPositionService.get(positionKey)?.y ?? (root.height - height - Config.position.margin)
    }
}
