pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Lê config/secrets.json (token do Notion, link .ics do Proton Calendar).
 * Esse arquivo nunca é commitado (ver .gitignore) — preencha a partir de
 * config/secrets.example.json editando direto no editor, sem colar em
 * chat/log nenhum.
 */
Singleton {
    id: root

    property string protonCalendarIcsUrl: ""
    property string notionToken: ""
    property string notionDatabaseId: ""
    property bool loaded: false

    FileView {
        id: secretsFile
        path: Qt.resolvedUrl("../config/secrets.json")
        onLoadedChanged: {
            try {
                const data = JSON.parse(secretsFile.text());
                root.protonCalendarIcsUrl = data.protonCalendarIcsUrl || "";
                const notion = data.notion || {};
                root.notionToken = notion.token || "";
                root.notionDatabaseId = notion.databaseId || "";
            } catch (e) {
                console.error("[SecretsService] Falha ao ler config/secrets.json:", e);
            }
            root.loaded = true;
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                console.log("[SecretsService] config/secrets.json não existe ainda. Copie de secrets.example.json e preencha.");
            } else {
                console.error("[SecretsService] Erro ao carregar secrets.json:", error);
            }
            root.loaded = true;
        }
    }
}
