pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Integração com a API do Notion: lista tudo que a integração enxerga
 * (POST /v1/search, cobre páginas e databases compartilhadas com ela, não
 * uma database fixa) e permite abrir uma página pra ler/editar o texto
 * dos blocos de primeiro nível.
 *
 * Importante: todo `curl` aqui vai como lista de argv no `command` do
 * `Process`, nunca como string `bash -c` concatenada — o texto dos blocos
 * é digitado pelo usuário (pode ter aspas, cifrão, crase etc.) e vai
 * direto no `-d <json>`; interpolar isso numa string de shell arriscaria
 * injeção de comando. O `CalendarService` usa `bash -c` com segurança
 * porque só interpola a URL do próprio secrets.json, nunca texto digitado
 * depois.
 *
 * Limitações conhecidas (MVP):
 * - Só os tipos de bloco paragraph/heading_1-3/bulleted_list_item/
 *   numbered_list_item/to_do são lidos e editáveis; qualquer outro tipo
 *   (tabela, imagem, blocos aninhados etc.) aparece como linha
 *   somente-leitura "(bloco não suportado)".
 * - Só o primeiro nível de `children` da página aberta — blocos filhos
 *   aninhados (toggle, sub-página) não são expandidos.
 * - Sem rich text de verdade (negrito, cor, link) — só texto plano.
 * - PATCH de um bloco reescreve o objeto do tipo inteiro; formatação/cor
 *   eventual do bloco original não é preservada (exceto `checked` do
 *   to_do, que é reenviado de propósito pra não desmarcar a tarefa).
 */
Singleton {
    id: root

    readonly property bool configured: SecretsService.notionToken.length > 0
    readonly property var supportedBlockTypes: ["paragraph", "heading_1", "heading_2", "heading_3", "bulleted_list_item", "numbered_list_item", "to_do"]

    // Navegação: "list" (busca) ou "detail" (blocos de uma página aberta)
    property string view: "list"
    property string openPageId: ""
    property string openPageTitle: ""

    property var items: []
    property bool listReady: false
    property bool listError: false

    property var blocks: []
    property bool blocksReady: false
    property bool blocksError: false

    property var writeQueue: []
    property var currentJob: null
    readonly property bool saving: currentJob !== null || writeQueue.length > 0
    property bool writeError: false

    readonly property bool hasDirtyBlocks: blocks.some(b => b.dirty)

    function richTextToPlain(richTextArr) {
        return (richTextArr || []).map(rt => rt.plain_text ?? rt.text?.content ?? "").join("");
    }

    function extractTitle(obj) {
        if (obj.object === "database") {
            return root.richTextToPlain(obj.title) || "Database sem título";
        }
        const props = obj.properties || {};
        for (const key in props) {
            if (props[key].type === "title") {
                return root.richTextToPlain(props[key].title) || "Página sem título";
            }
        }
        return "Sem título";
    }

    function parseSearchItem(obj) {
        return { id: obj.id, object: obj.object, title: root.extractTitle(obj) };
    }

    function parseBlock(raw) {
        if (!root.supportedBlockTypes.includes(raw.type)) {
            return { id: raw.id, type: raw.type, text: "(bloco não suportado)", supported: false, dirty: false };
        }
        const typeObj = raw[raw.type];
        const block = { id: raw.id, type: raw.type, text: root.richTextToPlain(typeObj.rich_text), supported: true, dirty: false };
        if (raw.type === "to_do") block.checked = !!typeObj.checked;
        return block;
    }

    function buildBlockPayload(block) {
        const payload = { rich_text: [{ type: "text", text: { content: block.text } }] };
        if (block.type === "to_do") payload.checked = !!block.checked;
        return { [block.type]: payload };
    }

    function search() {
        if (!root.configured) return;
        searchProc.running = true;
    }

    function openPage(id, title) {
        root.openPageId = id;
        root.openPageTitle = title;
        root.view = "detail";
        root.blocks = [];
        root.blocksReady = false;
        root.blocksError = false;
        blocksProc.running = true;
    }

    function closePage() {
        root.view = "list";
        root.openPageId = "";
        root.openPageTitle = "";
        root.blocks = [];
    }

    function setBlockText(blockId, text) {
        root.blocks = root.blocks.map(b => b.id === blockId ? Object.assign({}, b, { text, dirty: true }) : b);
    }

    function saveBlock(block) {
        root.writeQueue = root.writeQueue.concat([{
            kind: "save",
            blockId: block.id,
            text: block.text,
            url: "https://api.notion.com/v1/blocks/" + block.id,
            body: JSON.stringify(root.buildBlockPayload(block))
        }]);
        root.processQueue();
    }

    function saveAll() {
        root.blocks.filter(b => b.dirty && b.supported).forEach(b => root.saveBlock(b));
    }

    function addBlock(text) {
        if (!root.openPageId) return;
        root.writeQueue = root.writeQueue.concat([{
            kind: "add",
            url: "https://api.notion.com/v1/blocks/" + root.openPageId + "/children",
            body: JSON.stringify({ children: [{ paragraph: { rich_text: text.length > 0 ? [{ type: "text", text: { content: text } }] : [] } }] })
        }]);
        root.processQueue();
    }

    function processQueue() {
        if (root.currentJob !== null || root.writeQueue.length === 0) return;
        root.currentJob = root.writeQueue[0];
        root.writeQueue = root.writeQueue.slice(1);
        writeProc.running = true;
    }

    function handleWriteResult(text) {
        const job = root.currentJob;
        root.currentJob = null;
        try {
            const data = JSON.parse(text);
            if (data.object === "error") throw new Error(data.message);
            if (job.kind === "save") {
                root.blocks = root.blocks.map(b => b.id === job.blockId ? Object.assign({}, b, { dirty: false }) : b);
            } else if (job.kind === "add") {
                const created = (data.results || []).map(root.parseBlock);
                root.blocks = root.blocks.concat(created);
            }
            root.writeError = false;
        } catch (e) {
            console.error("[NotionService] Falha ao salvar:", e);
            root.writeError = true;
        }
        root.processQueue();
    }

    Component.onCompleted: if (root.configured) root.search()

    Connections {
        target: SecretsService
        function onNotionTokenChanged() { if (root.configured) root.search() }
    }

    Process {
        id: searchProc
        command: [
            "curl", "-s", "--max-time", "10",
            "-X", "POST", "https://api.notion.com/v1/search",
            "-H", "Authorization: Bearer " + SecretsService.notionToken,
            "-H", "Notion-Version: 2022-06-28",
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify({ sort: { direction: "descending", timestamp: "last_edited_time" }, page_size: 50 })
        ]
        stdout: StdioCollector {
            id: searchCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(searchCollector.text);
                    if (data.object === "error") throw new Error(data.message);
                    root.items = (data.results || []).map(root.parseSearchItem);
                    root.listReady = true;
                    root.listError = false;
                } catch (e) {
                    console.error("[NotionService] Falha ao buscar itens:", e);
                    root.listError = true;
                }
            }
        }
    }

    Process {
        id: blocksProc
        command: [
            "curl", "-s", "--max-time", "10",
            "-X", "GET", "https://api.notion.com/v1/blocks/" + root.openPageId + "/children?page_size=100",
            "-H", "Authorization: Bearer " + SecretsService.notionToken,
            "-H", "Notion-Version: 2022-06-28"
        ]
        stdout: StdioCollector {
            id: blocksCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(blocksCollector.text);
                    if (data.object === "error") throw new Error(data.message);
                    root.blocks = (data.results || []).map(root.parseBlock);
                    root.blocksReady = true;
                    root.blocksError = false;
                } catch (e) {
                    console.error("[NotionService] Falha ao buscar blocos:", e);
                    root.blocksError = true;
                }
            }
        }
    }

    Process {
        id: writeProc
        command: root.currentJob ? [
            "curl", "-s", "--max-time", "10",
            "-X", "PATCH", root.currentJob.url,
            "-H", "Authorization: Bearer " + SecretsService.notionToken,
            "-H", "Notion-Version: 2022-06-28",
            "-H", "Content-Type: application/json",
            "-d", root.currentJob.body
        ] : ["true"]
        stdout: StdioCollector {
            id: writeCollector
            onStreamFinished: root.handleWriteResult(writeCollector.text)
        }
    }
}
