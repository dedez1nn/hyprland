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
 *   (tabela, imagem, sub-página etc.) aparece como linha somente-leitura
 *   "(bloco não suportado)".
 * - Blocos filhos (ex: checklist indentada sob um parágrafo) são buscados
 *   recursivamente (um GET /children por bloco com has_children=true) até
 *   maxFetchDepth níveis de profundidade — abaixo disso, netos de netos
 *   não são expandidos. Isso significa um GET por bloco aninhado; páginas
 *   muito grandes/profundas demoram mais pra abrir.
 * - Sem rich text de verdade (negrito, cor, link) — só texto plano.
 * - PATCH de um bloco reescreve o objeto do tipo inteiro; formatação/cor
 *   eventual do bloco original não é preservada (exceto `checked` do
 *   to_do, que é reenviado de propósito pra não desmarcar a tarefa).
 */
Singleton {
    id: root

    readonly property bool configured: SecretsService.notionToken.length > 0
    readonly property var supportedBlockTypes: ["paragraph", "heading_1", "heading_2", "heading_3", "bulleted_list_item", "numbered_list_item", "to_do"]
    readonly property int maxFetchDepth: 4

    // Navegação: "list" (busca) ou "detail" (blocos de uma página aberta)
    property string view: "list"
    property string openPageId: ""
    property string openPageTitle: ""

    property var items: []
    property bool listReady: false
    property bool listError: false

    // Busca recursiva de blocos filhos: fetchQueue guarda { id, depth } de
    // cada bloco (ou a própria página) ainda por buscar; blocksByParent
    // acumula os resultados brutos parseados por id do pai, remontados em
    // lista única (flatten) só quando a fila esvazia.
    property var fetchQueue: []
    property var currentFetchJob: null
    property var blocksByParent: ({})

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
        const hasChildren = !!raw.has_children;
        if (!root.supportedBlockTypes.includes(raw.type)) {
            return { id: raw.id, type: raw.type, text: "(bloco não suportado)", supported: false, dirty: false, hasChildren };
        }
        const typeObj = raw[raw.type];
        const block = { id: raw.id, type: raw.type, text: root.richTextToPlain(typeObj.rich_text), supported: true, dirty: false, hasChildren };
        if (raw.type === "to_do") block.checked = !!typeObj.checked;
        return block;
    }

    // Remonta a árvore buscada em blocksByParent numa lista única, na
    // ordem em que apareceriam no Notion (cada bloco seguido dos seus
    // próprios filhos), com `depth` pra indentação visual.
    function flattenBlocks(parentId, depth) {
        const children = root.blocksByParent[parentId] || [];
        let result = [];
        for (const block of children) {
            result.push(Object.assign({}, block, { depth }));
            if (block.hasChildren && root.blocksByParent[block.id]) {
                result = result.concat(root.flattenBlocks(block.id, depth + 1));
            }
        }
        return result;
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
        root.blocksByParent = {};
        root.fetchQueue = [{ id, depth: 0 }];
        root.processFetchQueue();
    }

    function processFetchQueue() {
        if (root.currentFetchJob !== null) return;
        if (root.fetchQueue.length === 0) {
            root.blocks = root.flattenBlocks(root.openPageId, 0);
            root.blocksReady = true;
            return;
        }
        root.currentFetchJob = root.fetchQueue[0];
        root.fetchQueue = root.fetchQueue.slice(1);
        blocksProc.running = true;
    }

    function closePage() {
        root.view = "list";
        root.openPageId = "";
        root.openPageTitle = "";
        root.blocks = [];
        root.fetchQueue = [];
        root.blocksByParent = {};
    }

    function setBlockText(blockId, text) {
        root.blocks = root.blocks.map(b => b.id === blockId ? Object.assign({}, b, { text, dirty: true }) : b);
    }

    function toggleChecked(blockId) {
        root.blocks = root.blocks.map(b => b.id === blockId ? Object.assign({}, b, { checked: !b.checked, dirty: true }) : b);
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
                // addBlock só acrescenta no nível raiz da página (ver função
                // addBlock), por isso depth fixo em 0 aqui.
                const created = (data.results || []).map(raw => Object.assign(root.parseBlock(raw), { depth: 0 }));
                root.blocks = root.blocks.concat(created);
                const parents = Object.assign({}, root.blocksByParent);
                parents[root.openPageId] = (parents[root.openPageId] || []).concat(created);
                root.blocksByParent = parents;
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

    // Retry periódico: cobre a busca inicial falhando por rede/DNS ainda não
    // prontos (ex: unit do systemd subindo antes da rede) ou qualquer outra
    // falha transitória da API. Sem isso, listError ficava travado pra
    // sempre, já que search() só roda de novo manualmente ou quando o token
    // muda.
    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: if (root.configured && root.listError) root.search()
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
        command: root.currentFetchJob ? [
            "curl", "-s", "--max-time", "10",
            "-X", "GET", "https://api.notion.com/v1/blocks/" + root.currentFetchJob.id + "/children?page_size=100",
            "-H", "Authorization: Bearer " + SecretsService.notionToken,
            "-H", "Notion-Version: 2022-06-28"
        ] : ["true"]
        stdout: StdioCollector {
            id: blocksCollector
            onStreamFinished: {
                const job = root.currentFetchJob;
                root.currentFetchJob = null;
                try {
                    const data = JSON.parse(blocksCollector.text);
                    if (data.object === "error") throw new Error(data.message);
                    const parsed = (data.results || []).map(root.parseBlock);
                    const nextParents = Object.assign({}, root.blocksByParent);
                    nextParents[job.id] = parsed;
                    root.blocksByParent = nextParents;

                    if (job.depth < root.maxFetchDepth) {
                        const nested = parsed.filter(b => b.hasChildren).map(b => ({ id: b.id, depth: job.depth + 1 }));
                        root.fetchQueue = root.fetchQueue.concat(nested);
                    }
                    if (job.depth === 0) root.blocksError = false;
                } catch (e) {
                    console.error("[NotionService] Falha ao buscar blocos de " + job.id + ":", e);
                    // Falha num bloco aninhado só deixa aquele sub-nível sem
                    // expandir (blocksByParent[job.id] fica ausente, flatten
                    // ignora); só falha a página inteira se for o nível 0.
                    if (job.depth === 0) root.blocksError = true;
                }
                root.processFetchQueue();
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
