import QtQuick
import "../common"
import "../services"

/**
 * Notas do Notion: lista tudo que a integração enxerga (páginas e
 * databases compartilhadas, via NotionService.search()); clicar num item
 * abre o conteúdo (blocos) daquela página em modo leitura. Botão "Editar"
 * no topo libera a edição das caixas de texto; "Salvar" (embaixo) grava
 * de volta no Notion e volta pro modo leitura. Seletor 1×/2×/3× no canto
 * superior direito dobra/triplica o tamanho do card. Ver
 * services/NotionService.qml pras limitações conhecidas (tipos de bloco
 * suportados, sem rich text de verdade).
 */
Card {
    id: root
    positionKey: "quickNotes"

    readonly property int baseWidth: Config.clock.width
    readonly property int baseHeight: 280
    property int sizeLevel: 1 // 1x, 2x ou 3x — ver seletor no canto superior direito
    property bool editing: false

    implicitWidth: root.baseWidth * root.sizeLevel
    implicitHeight: root.baseHeight * root.sizeLevel

    // Fonte das notas (lista + blocos): cresce junto com o sizeLevel — sem
    // isso, aumentar o card só dava mais espaço, sem deixar a letra maior.
    // Mais grossa (Font.Medium) e mais branca que o texto padrão do
    // dashboard (Appearance.colors.text é um azulado claro, não branco).
    readonly property int noteFontSize: Appearance.font.sizeNormal + (root.sizeLevel - 1) * 2
    readonly property color noteTextColor: "#f5f7ff"

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

    // Seletor de tamanho: 1×/2×/3× multiplicam width/height do card inteiro.
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 4
        z: 10

        Repeater {
            model: [1, 2, 3]

            delegate: StyledText {
                text: modelData + "×"
                font.pixelSize: Appearance.font.sizeSmall
                font.bold: root.sizeLevel === modelData
                color: root.sizeLevel === modelData ? Appearance.colors.accent : Appearance.colors.textMuted

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sizeLevel = modelData
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Row {
            width: parent.width - 50
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
                    }
                }
            }

            StyledText {
                width: parent.width - (NotionService.view === "detail" ? 30 : 0)
                text: NotionService.view === "detail" ? NotionService.openPageTitle : "Notion"
                font.bold: true
                elide: Text.ElideRight
            }
        }

        ActionButton {
            label: "Editar"
            visible: NotionService.view === "detail" && NotionService.blocksReady && !NotionService.blocksError && !root.editing
            onClicked: root.editing = true
        }

        StyledText {
            visible: !NotionService.configured
            text: "Notion não configurado"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            visible: NotionService.configured && NotionService.view === "list" && !NotionService.listReady && !NotionService.listError
            text: "Carregando..."
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            visible: NotionService.configured && NotionService.listError
            text: "Notion indisponível"
            color: Appearance.colors.danger
            font.pixelSize: Appearance.font.sizeSmall
        }

        StyledText {
            visible: NotionService.configured && NotionService.view === "list" && NotionService.listReady && !NotionService.listError && NotionService.items.length === 0
            text: "Nada compartilhado com a integração ainda"
            color: Appearance.colors.textMuted
            font.pixelSize: Appearance.font.sizeSmall
        }

        ListView {
            visible: NotionService.configured && NotionService.view === "list" && NotionService.listReady && !NotionService.listError && NotionService.items.length > 0
            width: parent.width
            height: parent.height - 40
            clip: true
            spacing: 4
            model: NotionService.items

            delegate: Item {
                width: ListView.view.width
                height: 22

                Row {
                    anchors.fill: parent
                    spacing: 8

                    StyledText {
                        text: modelData.object === "database" ? "🗄️" : "📄"
                        font.pixelSize: Appearance.font.sizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        width: parent.width - 30
                        text: modelData.title
                        elide: Text.ElideRight
                        font.pixelSize: root.noteFontSize
                        font.weight: Font.Medium
                        color: root.noteTextColor
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
            visible: NotionService.configured && NotionService.view === "detail"
            width: parent.width
            height: parent.height - 40
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

                Repeater {
                    model: NotionService.blocksReady ? NotionService.blocks : []

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
                            width: Math.max(0, blocksColumn.width - modelData.depth * 16 - (modelData.type === "to_do" ? 30 : 6))
                            text: modelData.text
                            readOnly: !root.editing || !modelData.supported
                            color: !modelData.supported ? Appearance.colors.textMuted : (modelData.checked ? Appearance.colors.textMuted : root.noteTextColor)
                            font.family: Appearance.font.family
                            font.pixelSize: root.noteFontSize
                            font.weight: modelData.type.startsWith("heading") ? Font.Bold : Font.Medium
                            font.strikeout: modelData.checked === true
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            onActiveFocusChanged: {
                                if (!activeFocus && modelData.supported && text !== modelData.text) {
                                    NotionService.setBlockText(modelData.id, text);
                                }
                            }
                        }
                    }
                }

                Row {
                    visible: root.editing
                    spacing: 14

                    StyledText {
                        text: "+ nova nota"
                        color: Appearance.colors.accent
                        font.pixelSize: Appearance.font.sizeSmall
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotionService.addBlock("")
                        }
                    }

                    ActionButton {
                        label: NotionService.saving ? "Salvando..." : "Salvar"
                        enabled: !NotionService.saving
                        onClicked: {
                            NotionService.saveAll();
                            root.editing = false;
                        }
                    }
                }
            }
        }
    }
}
