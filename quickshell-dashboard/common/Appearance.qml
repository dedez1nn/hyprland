pragma Singleton

import QtQuick

/**
 * Paleta de cores, fontes e raios de borda usados por todos os widgets
 * do dashboard. Centralizado aqui pra manter consistência visual.
 */
QtObject {
    id: root

    readonly property QtObject colors: QtObject {
        // Paleta ctOS/DedSec (Watch Dogs): terminal hacker preto com ciano
        // como único destaque. Ver artifact do mockup pra referência visual
        // completa (calibração de cores/tipografia).
        readonly property color background: "#06090a"
        readonly property color backgroundAlt: "#0b1011"
        readonly property color surface: "#10181a"
        readonly property color text: "#eef8f7"
        readonly property color textMuted: "#6d8483"
        readonly property color textFaint: "#3c4d4c"
        readonly property color accent: "#38e8e2"
        // Ciano escurecido — bordas, cantos de mira, estados dim. Amarelo
        // de alerta fica de fora da paleta de widget (reservado pra avisos
        // pontuais, não é um token de uso geral).
        readonly property color accentAlt: "#175355"
        readonly property color borderBright: "#29494a"
        readonly property color danger: "#ff4d5e"
        readonly property color success: "#8ef0a6"

        // Sombra do relevo suave (ver common/widgets/Card.qml)
        readonly property color shadowDark: "#8c000000"

        // Fundo do card: backgroundAlt com ~86% de opacidade, deixando o
        // wallpaper aparecer de leve por trás. borda fina pra marcar o
        // contorno já que o preenchimento não é mais sólido.
        readonly property color cardBackground: "#db0b1011"
        readonly property color cardBorder: "#1c2b2c"
    }

    readonly property QtObject font: QtObject {
        // Chakra Petch (labels/títulos, angular e técnica) + Share Tech
        // Mono (hora, temperatura, contadores — qualquer dado tabular).
        // Instaladas em ~/.local/share/fonts (google/fonts upstream), não
        // vêm com o sistema por padrão — mesma armadilha do "Rubik" antigo:
        // conferir com `fc-list` antes de trocar, senão cai num fallback
        // silencioso.
        readonly property string family: "Chakra Petch"
        readonly property string familyMono: "Share Tech Mono"
        readonly property int sizeSmall: 11
        readonly property int sizeNormal: 13
        readonly property int sizeLarge: 18
        readonly property int sizeHuge: 32
    }

    readonly property int radiusSmall: 2
    readonly property int radiusNormal: 2
    readonly property int radiusLarge: 3

    readonly property int animationFast: 120
    readonly property int animationNormal: 220
}
