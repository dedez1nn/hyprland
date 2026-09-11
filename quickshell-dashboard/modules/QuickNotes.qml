import QtQuick
import "../common"
import "../services"

/**
 * Notas do Notion: lista tudo que a integração enxerga (páginas e
 * databases compartilhadas, via NotionService.search()); clicar num item
 * abre o conteúdo (blocos) daquela página em modo leitura. Botão "Editar"
 * no topo libera a edição das caixas de texto; "Novo" (embaixo, em modo
 * edição) abre um menu com os tipos de bloco criáveis (ver
 * NotionService.creatableBlockTypes); "Salvar" grava de volta no Notion e
 * volta pro modo leitura. Tamanho livre: arrastar a borda direita muda só
 * a largura, a borda inferior só a altura, o canto inferior-direito muda
 * as duas na diagonal (troca o antigo seletor fixo 1×/2×/3×) — tamanho
 * final persistido em WidgetSizeService, volta no próximo reload. Ver
 * services/NotionService.qml pras limitações conhecidas (tipos de bloco
 * suportados, sem rich text de verdade).
 */
Card {
    id: root
    positionKey: "quickNotes"
    resizable: true

    // Bem mais largo que Config.clock.width (320, pensado pra widgets de
    // uma linha só como clima/música) — notas do Notion são parágrafo,
    // 320px de largura quebrava linha a cada 4-5 palavras. Também o
    // tamanho mínimo que as alças de redimensionar do Card aceitam.
    baseWidth: 460
    baseHeight: 480
    property bool editing: false
    property bool newMenuOpen: false

    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    // Fonte das notas (lista + blocos): cresce junto com o tamanho do
    // card — sem isso, aumentar o card só dava mais espaço, sem deixar a
    // letra maior. Escala pela média width/height (mesma proporção que o
    // antigo sizeLevel dava: 1x → +0, 2x → +2, 3x → +4). Mais grossa
    // (Font.Medium) e mais branca que o texto padrão do dashboard
    // (Appearance.colors.text é um azulado claro, não branco).
    readonly property real sizeScale: (root.cardWidth / root.baseWidth + root.cardHeight / root.baseHeight) / 2
    readonly property int noteFontSize: Appearance.font.sizeNormal + Math.max(0, Math.round((root.sizeScale - 1) * 2))
    readonly property color noteTextColor: "#f5f7ff"

    function escapeHtml(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Um <p> por bloco, todos concatenados num texto rich-text só (ver
    // blocksHtml/readOnlyText abaixo). Em modo leitura isso substitui o
    // TextEdit por bloco do modo edição — com um TextEdit por bloco,
    // arrastar o mouse pra selecionar não atravessa de um bloco pro
    // outro (cada um é uma seleção própria); um texto único resolve isso
    // e ainda permite Ctrl+A/copiar a página inteira de uma vez.
    function blockToHtml(block) {
        const indent = block.depth * 16;
        const marker = block.type === "to_do" ? (block.checked ? "☑ " : "☐ ") : "";
        const weight = block.type.startsWith("heading") ? "bold" : "normal";
        const color = !block.supported ? Appearance.colors.textMuted : (block.checked ? Appearance.colors.textMuted : root.noteTextColor);
        const strike = block.checked === true ? "text-decoration:line-through;" : "";
        const body = block.supported ? root.escapeHtml(block.text) : "(bloco não suportado)";
        return "<p style=\"margin:0 0 6px " + indent + "px;font-weight:" + weight + ";color:" + color + ";" + strike + "\">" + marker + (body.length > 0 ? body : "&nbsp;") + "</p>";
    }

    readonly property string blocksHtml: NotionService.blocksReady ? NotionService.blocks.map(root.blockToHtml).join("") : ""

    component ActionButton: Rectangle {
        id: btn
        required property string label
        property bool enabled: true
        signal clicked()

        radius: Appearance.radiusSmall
        color: Appearance.colors.surface
        border.width: 1
        border.color: Appearance.colors.cardBorder
        opacity: enabled ? 1 : 0.5
        implicitWidth: labelText.implicitWidth + 20
        implicitHeight: labelText.implicitHeight + 10

        StyledText {
            id: labelText
            anchors.centerIn: parent
            text: btn.label
            color: "#ffffff"
            font.bold: true
            font.pixelSize: Appearance.font.sizeSmall
        }

        MouseArea {
            anchors.fill: parent
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // Badge com o total de itens, no canto superior direito.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        z: 10
        visible: NotionService.configured && NotionService.view === "list" && NotionService.items.length > 0
        width: Math.max(20, notesBadge.implicitWidth + 8)
        height: 20
        color: "transparent"
        border.width: 1
        border.color: Appearance.colors.accentAlt

        StyledText {
            id: notesBadge
            anchors.centerIn: parent
            text: NotionService.items.length
            font.family: Appearance.font.familyMono
            font.pixelSize: Appearance.font.sizeSmall
            color: Appearance.colors.accent
        }
    }

    // Item (não Column) porque a área de conteúdo (lista/blocos) precisa
    // preencher exatamente o espaço que sobra abaixo do cabeçalho — com
    // Column + uma altura fixa "chutada" (ex: parent.height - 40), o botão
    // "Editar" aparecendo/sumindo desalinhava a conta e o conteúdo
    // vazava pra fora do card (sem clip, desenhava por cima do wallpaper).
    // Aqui cada área usa anchors.top/bottom de verdade, então nunca
    // ultrapassa os limites do card, não importa o que esteja visível.
    Item {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        clip: true

        Column {
            id: header
            anchors.top: parent.top
            width: parent.width - 50
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                StyledText {
                    visible: NotionService.view === "detail"
                    text: "←"
                    font.pixelSize: Appearance.font.sizeLarge
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NotionService.closePage();
                            root.editing = false;
                            root.newMenuOpen = false;
                        }
                    }
                }

                StyledText {
                    width: parent.width - (NotionService.view === "detail" ? 30 : 0)
                    text: NotionService.view === "detail" ? NotionService.openPageTitle : "INTEL FEED"
                    font.bold: true
                    font.letterSpacing: NotionService.view === "detail" ? 0 : 1
                    elide: Text.ElideRight
                }
            }

            ActionButton {
                label: "Editar"
                visible: NotionService.view === "detail" && NotionService.blocksReady && !NotionService.blocksError && !root.editing
                onClicked: root.editing = true
            }
        }

        StyledText {
            anchors.top: header.bottom
            anchors.topMargin: 10
            visible: !NotionService.configured
            text: "Notion não configurado"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: header.bottom
            anchors.topMargin: 10
            visible: NotionService.configured && NotionService.view === "list" && !NotionService.listReady && !NotionService.listError
            text: "Carregando..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: header.bottom
            anchors.topMargin: 10
            visible: NotionService.configured && NotionService.listError
            text: "Notion indisponível"
            color: Appearance.colors.danger
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            anchors.top: header.bottom
            anchors.topMargin: 10
            visible: NotionService.configured && NotionService.view === "list" && NotionService.listReady && !NotionService.listError && NotionService.items.length === 0
            text: "Nada compartilhado com a integração ainda"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        ListView {
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: NotionService.configured && NotionService.view === "list" && NotionService.listReady && !NotionService.listError && NotionService.items.length > 0
            clip: true
            spacing: 4
            model: NotionService.items

            delegate: Item {
                width: ListView.view.width
                height: 22

                Row {
                    anchors.fill: parent
                    spacing: 10

                    Rectangle {
                        width: 3
                        height: 14
                        color: Appearance.colors.accentAlt
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        width: parent.width - 3 - 10 - 34 - 8
                        text: modelData.title
                        elide: Text.ElideRight
                        font.pixelSize: root.noteFontSize
                        font.weight: Font.Medium
                        color: root.noteTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        width: 34
                        text: modelData.object === "database" ? "DB" : "PAGE"
                        font.family: Appearance.font.familyMono
                        font.pixelSize: Appearance.font.sizeSmall - 2
                        color: Appearance.colors.textFaint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotionService.openPage(modelData.id, modelData.title);
                        root.editing = false;
                    }
                }
            }
        }

        Flickable {
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            // Reserva espaço pro footer fixo (Novo/Salvar) só quando ele
            // aparece — sem isso, o footer ficaria sobrepondo a última
            // linha de blocos em vez de ficar sempre visível embaixo.
            anchors.bottomMargin: footer.visible ? footer.height + 10 : 0
            visible: NotionService.configured && NotionService.view === "detail"
            clip: true
            contentWidth: width
            contentHeight: blocksColumn.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: blocksColumn
                width: parent.width
                spacing: 6

                StyledText {
                    visible: !NotionService.blocksReady && !NotionService.blocksError
                    text: "Carregando..."
                    color: Appearance.colors.textMuted
                    font.pixelSize: Appearance.font.sizeSmall
                }

                StyledText {
                    visible: NotionService.blocksError
                    text: "Não foi possível carregar essa página"
                    color: Appearance.colors.danger
                    font.pixelSize: Appearance.font.sizeSmall
                }

                // Modo leitura: texto único (ver root.blocksHtml) pra
                // permitir arrastar o mouse selecionando através de
                // vários blocos, e Ctrl+A/copiar a página inteira.
                TextEdit {
                    width: blocksColumn.width
                    visible: !root.editing && NotionService.blocksReady
                    readOnly: true
                    selectByMouse: true
                    persistentSelection: true
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.WordWrap
                    text: root.blocksHtml
                    font.family: Appearance.font.family
                    font.pixelSize: root.noteFontSize
                }

                // Modo edição: volta a ser um TextEdit por bloco — cada
                // bloco precisa ser editável e salvo separadamente (ver
                // NotionService.setBlockText), o que um texto único não
                // permite.
                Repeater {
                    model: root.editing && NotionService.blocksReady ? NotionService.blocks : []

                    delegate: Row {
                        width: blocksColumn.width
                        spacing: 6

                        Item {
                            width: modelData.depth * 16
                            height: 1
                        }

                        StyledText {
                            visible: modelData.type === "to_do"
                            text: modelData.checked ? "☑" : "☐"
                            font.pixelSize: root.noteFontSize
                            color: modelData.checked ? Appearance.colors.success : root.noteTextColor

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.editing
                                cursorShape: root.editing ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: NotionService.toggleChecked(modelData.id)
                            }
                        }

                        TextEdit {
                            width: Math.max(0, blocksColumn.width - modelData.depth * 16 - (modelData.type === "to_do" ? 24 : 0) - 12)
                            text: modelData.text
                            readOnly: !root.editing || !modelData.supported
                            color: !modelData.supported ? Appearance.colors.textMuted : (modelData.checked ? Appearance.colors.textMuted : root.noteTextColor)
                            font.family: Appearance.font.family
                            font.pixelSize: root.noteFontSize
                            font.weight: modelData.type.startsWith("heading") ? Font.Bold : Font.Medium
                            font.strikeout: modelData.checked === true
                            wrapMode: TextEdit.WordWrap
                            selectByMouse: true
                            onActiveFocusChanged: {
                                if (!activeFocus && modelData.supported && text !== modelData.text) {
                                    NotionService.setBlockText(modelData.id, text);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer fixo (fora do Flickable, então nunca sofre o clip dele —
        // importante pro menu do "Novo" abrir por cima das notas em vez de
        // ser cortado). Só aparece em modo edição, na página aberta.
        Row {
            id: footer
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            visible: root.editing && NotionService.view === "detail"
            spacing: 10
            z: 15

            ActionButton {
                id: newButton
                label: "Novo"
                onClicked: root.newMenuOpen = !root.newMenuOpen
            }

            ActionButton {
                label: NotionService.saving ? "Salvando..." : "Salvar"
                enabled: !NotionService.saving
                onClicked: {
                    NotionService.saveAll();
                    root.editing = false;
                    root.newMenuOpen = false;
                }
            }
        }

        // Menu do "Novo": um tipo de bloco por linha, igual ao seletor "/"
        // do próprio Notion (ver NotionService.creatableBlockTypes).
        // Ancorado acima do footer, fora do Flickable pelo mesmo motivo.
        Rectangle {
            id: newMenu
            visible: root.newMenuOpen
            // footer, não newButton: newButton é filho de footer (um
            // "sobrinho", não irmão direto de newMenu), e QML só permite
            // ancorar em pai/irmão/filho — dava "Cannot anchor to an item
            // that isn't a parent or sibling" em runtime. footer.left
            // coincide com newButton.left porque ele é o primeiro item
            // do Row.
            anchors.left: footer.left
            anchors.bottom: footer.top
            anchors.bottomMargin: 6
            z: 30
            width: 180
            implicitHeight: menuColumn.implicitHeight + 8
            color: Appearance.colors.surface
            border.width: 1
            border.color: Appearance.colors.cardBorder
            radius: Appearance.radiusSmall

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4

                Repeater {
                    model: NotionService.creatableBlockTypes

                    delegate: Item {
                        width: menuColumn.width
                        height: 26
                        opacity: modelData.disabled ? 0.4 : 1

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            text: modelData.label
                            font.pixelSize: Appearance.font.sizeSmall
                            color: root.noteTextColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !modelData.disabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NotionService.addBlock(modelData.type, "");
                                root.newMenuOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
