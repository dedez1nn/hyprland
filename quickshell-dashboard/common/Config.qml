pragma Singleton

import QtQuick

/**
 * Liga/desliga cada widget e ajusta posição/tamanho.
 * Editável na mão por enquanto; se precisar recarregar a quente no futuro,
 * vira um FileView como o ConfigLoader.qml do módulo overview.
 */
QtObject {
    readonly property QtObject widgets: QtObject {
        property bool welcomeCard: true
        property bool clock: true
        property bool weather: true
        property bool musicPlayer: true
        property bool quickNotes: true
        property bool dock: false // parte 6
    }

    readonly property QtObject welcomeCard: QtObject {
        property string greetingName: "Andre"
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
