pragma Singleton

import QtQuick

/**
 * Paleta de cores, fontes e raios de borda usados por todos os widgets
 * do dashboard. Centralizado aqui pra manter consistência visual.
 */
QtObject {
    id: root

    readonly property QtObject colors: QtObject {
        readonly property color background: "#1a1b26"
        readonly property color backgroundAlt: "#24283b"
        readonly property color surface: "#292e42"
        readonly property color text: "#c0caf5"
        readonly property color textMuted: "#7982a9"
        readonly property color accent: "#7aa2f7"
        readonly property color accentAlt: "#bb9af7"
        readonly property color danger: "#f7768e"
        readonly property color success: "#9ece6a"

        // Sombra do relevo suave (ver common/widgets/Card.qml)
        readonly property color shadowDark: "#8c000000"

        // Fundo do card: backgroundAlt com ~72% de opacidade, deixando o
        // wallpaper aparecer de leve por trás. borda fina pra marcar o
        // contorno já que o preenchimento não é mais sólido.
        readonly property color cardBackground: "#b824283b"
        readonly property color cardBorder: "#66c0c0c0"
    }

    readonly property QtObject font: QtObject {
        // "Open Sans" está instalada de verdade no sistema — trocada de
        // "Rubik" (nunca esteve instalada, caía num fallback silencioso do
        // fontconfig, geralmente Noto Sans).
        readonly property string family: "Open Sans"
        readonly property int sizeSmall: 11
        readonly property int sizeNormal: 13
        readonly property int sizeLarge: 18
        readonly property int sizeHuge: 32
    }

    readonly property int radiusSmall: 8
    readonly property int radiusNormal: 14
    readonly property int radiusLarge: 20

    readonly property int animationFast: 120
    readonly property int animationNormal: 220
}
