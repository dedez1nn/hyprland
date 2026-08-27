pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Posição (x, y) de cada widget arrastado pela alça no canto do Card.
 * Persistido em config/positions.json — específico da tela/resolução
 * atual, por isso fora do controle de versão (ver .gitignore). Sem
 * entrada salva, o widget usa a posição padrão calculada em
 * DashboardWindow.qml.
 */
Singleton {
    id: root

    property var positions: ({})

    function get(name) {
        return root.positions[name] || null;
    }

    function set(name, x, y) {
        const next = Object.assign({}, root.positions);
        next[name] = { x: Math.round(x), y: Math.round(y) };
        root.positions = next;
        file.setText(JSON.stringify(next, null, 2));
    }

    FileView {
        id: file
        path: Qt.resolvedUrl("../config/positions.json")
        onLoadedChanged: {
            try {
                root.positions = JSON.parse(file.text());
            } catch (e) {
                root.positions = {};
            }
        }
        onLoadFailed: (error) => {
            root.positions = {};
        }
    }
}
