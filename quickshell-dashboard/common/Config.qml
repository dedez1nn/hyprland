pragma Singleton

import QtQuick

/**
 * Ajusta parâmetros de cada widget (não liga/desliga — isso é
 * WidgetVisibilityService, com o catálogo completo de widgets e o
 * estado persistido de cada um).
 * Editável na mão por enquanto; se precisar recarregar a quente no futuro,
 * vira um FileView como o ConfigLoader.qml do módulo overview.
 */
QtObject {
    readonly property QtObject welcomeCard: QtObject {
        property string greetingName: "André"
        property int width: 320
    }

    readonly property QtObject clock: QtObject {
        property int width: 320
        property int height: 120
        property string locale: "pt_BR"
    }

    readonly property QtObject position: QtObject {
        property int margin: 40 // distância de cada widget até a borda da tela mais próxima
    }
}
