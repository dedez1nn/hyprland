pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Liga/desliga cada widget do dashboard, com persistência em
 * config/widget-visibility.json (mesmo espírito do WidgetPositionService
 * e WidgetSizeService). Não existe uma lista separada de "widgets de
 * início": o que está marcado aqui É o que aparece assim que o
 * quickshell-dashboard.service sobe no boot, porque esse arquivo é lido
 * direto, sem depender de nenhuma sessão anterior. Ligar/desligar pelo
 * WidgetsMenu já decide o estado tanto de agora quanto do próximo boot.
 *
 * `catalog` é a lista central de widgets que existem no dashboard —
 * DashboardWindow.qml e WidgetsMenu.qml leem daqui em vez de manter cada
 * um sua própria lista, então adicionar um widget novo é só acrescentar
 * uma entrada aqui.
 */
Singleton {
    id: root

    readonly property var catalog: [
        { key: "welcomeCard", label: "Boas-vindas", defaultEnabled: true },
        { key: "clock", label: "Relógio e calendário", defaultEnabled: true },
        { key: "weather", label: "Clima", defaultEnabled: true },
        { key: "musicPlayer", label: "Player de música", defaultEnabled: true },
        { key: "quickNotes", label: "Notion", defaultEnabled: true },
        { key: "entropy", label: "Entropia do sistema", defaultEnabled: true, group: "Diagnóstico de boot" },
        { key: "kernelTaint", label: "Saúde do kernel", defaultEnabled: true, group: "Diagnóstico de boot" },
        { key: "bootStatus", label: "Status do boot", defaultEnabled: true, group: "Diagnóstico de boot" },
        { key: "systemdBootTime", label: "Tempo de boot", defaultEnabled: true, group: "Diagnóstico de boot" }
    ]

    property var overrides: ({})

    function defaultFor(key) {
        const entry = root.catalog.find(w => w.key === key);
        return entry ? entry.defaultEnabled : true;
    }

    function isEnabled(key) {
        return root.overrides.hasOwnProperty(key) ? root.overrides[key] : root.defaultFor(key);
    }

    function setEnabled(key, value) {
        const next = Object.assign({}, root.overrides);
        next[key] = value;
        root.overrides = next;
        file.setText(JSON.stringify(next, null, 2));
    }

    // Usado pelo "desativar todos" de um grupo no WidgetsMenu (ex: os 4
    // widgets de diagnóstico de boot) — liga/desliga todo mundo daquele
    // grupo numa escrita só, em vez de uma por widget.
    function setGroupEnabled(group, value) {
        const next = Object.assign({}, root.overrides);
        root.catalog.filter(w => w.group === group).forEach(w => next[w.key] = value);
        root.overrides = next;
        file.setText(JSON.stringify(next, null, 2));
    }

    function isGroupFullyEnabled(group) {
        return root.catalog.filter(w => w.group === group).every(w => root.isEnabled(w.key));
    }

    FileView {
        id: file
        path: Qt.resolvedUrl("../config/widget-visibility.json")
        onLoadedChanged: {
            try {
                root.overrides = JSON.parse(file.text());
            } catch (e) {
                root.overrides = {};
            }
        }
        onLoadFailed: (error) => {
            root.overrides = {};
        }
    }
}
