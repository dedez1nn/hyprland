pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Tamanho (width, height) de cada widget redimensionado pelas alças do
 * Card. Persistido em config/sizes.json — específico da tela/resolução
 * atual, por isso fora do controle de versão (ver .gitignore), no mesmo
 * espírito do WidgetPositionService (posição). Sem entrada salva, o
 * widget usa o tamanho padrão definido nele mesmo.
 */
Singleton {
    id: root

    property var sizes: ({})

    function getSize(name) {
        return root.sizes[name] || null;
    }

    function setSize(name, width, height) {
        const next = Object.assign({}, root.sizes);
        next[name] = { width: Math.round(width), height: Math.round(height) };
        root.sizes = next;
        file.setText(JSON.stringify(next, null, 2));
    }

    FileView {
        id: file
        path: Qt.resolvedUrl("../config/sizes.json")
        onLoadedChanged: {
            try {
                root.sizes = JSON.parse(file.text());
            } catch (e) {
                root.sizes = {};
            }
        }
        onLoadFailed: (error) => {
            root.sizes = {};
        }
    }
}
