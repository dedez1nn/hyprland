import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"
import "../services"

/**
 * Janela em layer-shell cobrindo a tela inteira, com os widgets espalhados
 * (cada um numa posição padrão diferente) em vez de empilhados num canto.
 * Não bloqueia cliques fora dos cards (mask = união da área de cada widget
 * individualmente). Foco de teclado é `OnDemand` (não `None`): só é cedido
 * de verdade quando algo dentro da janela pede foco (ex: clicar numa nota
 * do QuickNotes pra editar) — sem isso nenhum TextEdit do dashboard
 * recebe tecla nenhuma, mesmo com o QML achando que tem foco.
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
 *
 * Cada `visible` consulta WidgetVisibilityService.isEnabled(key) em vez
 * de um bool fixo — é o que o WidgetsMenu (canto superior direito) liga
 * e desliga, e também o que decide o que já aparece ligado no boot.
 *
 * Os 4 widgets de diagnóstico de boot (Entropy/KernelTaint/BootStatus/
 * SystemdBootTime) somam a visibilidade normal com
 * BootSessionService.showBootWidgets — em grid 2×2 no centro da tela,
 * maiores que o MusicPlayer (ver comentário de cada um).
 */
PanelWindow {
    id: root
    screen: Quickshell.screens[0]
    visible: HyprlandWorkspaceService.isEmpty
    color: "transparent"

    WlrLayershell.namespace: "quickshell:dashboard"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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
        Region { item: quickNotes }
        Region { item: widgetsMenu }
        Region { item: entropyWidget }
        Region { item: kernelTaintWidget }
        Region { item: bootStatusWidget }
        Region { item: systemdBootTimeWidget }
    }

    mask: WidgetPositionService.dragging ? null : cardsRegion

    WelcomeCard {
        id: welcomeCard
        visible: WidgetVisibilityService.isEnabled("welcomeCard")
        x: WidgetPositionService.get(positionKey)?.x ?? ((root.width - width) / 2)
        y: WidgetPositionService.get(positionKey)?.y ?? Config.position.margin
    }

    ClockCalendar {
        id: clockCalendar
        visible: WidgetVisibilityService.isEnabled("clock")
        x: WidgetPositionService.get(positionKey)?.x ?? Config.position.margin
        y: WidgetPositionService.get(positionKey)?.y ?? ((root.height - height) / 2)
    }

    MusicPlayer {
        id: musicPlayer
        visible: WidgetVisibilityService.isEnabled("musicPlayer") && MediaService.active
        x: WidgetPositionService.get(positionKey)?.x ?? (root.width - width - Config.position.margin)
        y: WidgetPositionService.get(positionKey)?.y ?? ((root.height - height) / 2)
    }

    Weather {
        id: weather
        visible: WidgetVisibilityService.isEnabled("weather")
        x: WidgetPositionService.get(positionKey)?.x ?? (root.width - width - Config.position.margin)
        y: WidgetPositionService.get(positionKey)?.y ?? (root.height - height - Config.position.margin)
    }

    QuickNotes {
        id: quickNotes
        visible: WidgetVisibilityService.isEnabled("quickNotes")
        x: WidgetPositionService.get(positionKey)?.x ?? Config.position.margin
        y: WidgetPositionService.get(positionKey)?.y ?? (root.height - height - Config.position.margin)
    }

    // Não é um Card: fixo, sem drag/resize/positionKey — sempre no topo
    // direito, mesma margem dos outros widgets. Único item da Region que
    // não depende de WidgetVisibilityService.isEnabled: o próprio menu
    // que liga/desliga os outros não pode ser desligável por ele mesmo.
    WidgetsMenu {
        id: widgetsMenu
        x: root.width - width - Config.position.margin
        y: Config.position.margin
    }

    // Grid 2×2 no centro da tela, com um respiro de 24px entre os
    // cards — cada um ainda cai em WidgetPositionService.get() primeiro,
    // então uma vez arrastado, a posição do grid para de valer pra ele
    // (igual a qualquer outro widget).
    QtObject {
        id: bootGrid
        readonly property int gap: 24
        readonly property real totalWidth: entropyWidget.baseWidth * 2 + gap
        readonly property real totalHeight: entropyWidget.baseHeight * 2 + gap
        readonly property real left: (root.width - totalWidth) / 2
        readonly property real top: (root.height - totalHeight) / 2
    }

    EntropyWidget {
        id: entropyWidget
        visible: WidgetVisibilityService.isEnabled("entropy") && BootSessionService.showBootWidgets && !BootSessionService.isDismissed(positionKey)
        x: WidgetPositionService.get(positionKey)?.x ?? bootGrid.left
        y: WidgetPositionService.get(positionKey)?.y ?? bootGrid.top
    }

    KernelTaintWidget {
        id: kernelTaintWidget
        visible: WidgetVisibilityService.isEnabled("kernelTaint") && BootSessionService.showBootWidgets && !BootSessionService.isDismissed(positionKey)
        x: WidgetPositionService.get(positionKey)?.x ?? (bootGrid.left + entropyWidget.baseWidth + bootGrid.gap)
        y: WidgetPositionService.get(positionKey)?.y ?? bootGrid.top
    }

    BootStatusWidget {
        id: bootStatusWidget
        visible: WidgetVisibilityService.isEnabled("bootStatus") && BootSessionService.showBootWidgets && !BootSessionService.isDismissed(positionKey)
        x: WidgetPositionService.get(positionKey)?.x ?? bootGrid.left
        y: WidgetPositionService.get(positionKey)?.y ?? (bootGrid.top + entropyWidget.baseHeight + bootGrid.gap)
    }

    SystemdBootTimeWidget {
        id: systemdBootTimeWidget
        visible: WidgetVisibilityService.isEnabled("systemdBootTime") && BootSessionService.showBootWidgets && !BootSessionService.isDismissed(positionKey)
        x: WidgetPositionService.get(positionKey)?.x ?? (bootGrid.left + entropyWidget.baseWidth + bootGrid.gap)
        y: WidgetPositionService.get(positionKey)?.y ?? (bootGrid.top + entropyWidget.baseHeight + bootGrid.gap)
    }
}
