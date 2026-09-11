import QtQuick
import "../common"
import "../services"

/**
 * Botão fixo no canto superior direito do dashboard (não é um Card — não
 * arrasta, não redimensiona, sempre no mesmo lugar) que abre um painel
 * com um checkbox por widget do WidgetVisibilityService.catalog. Cada
 * checkbox liga/desliga aquele widget na hora e decide se ele volta a
 * aparecer no próximo boot (ver comentário do serviço).
 *
 * implicitWidth/Height cobrem o painel também quando aberto, não só o
 * botão — a Region que o DashboardWindow usa pra decidir onde aceitar
 * clique é a geometria deste Item, então se ela ficasse do tamanho do
 * botão sozinho, abrir o painel desenharia algo que não recebe clique
 * nenhum (a mask cortaria justo na borda do botão).
 */
Item {
    id: root
    property bool open: false

    readonly property int rowHeight: 28
    readonly property int panelWidth: 260

    // Achata o catálogo numa lista de linhas do menu, inserindo um
    // cabeçalho de grupo (com o toggle "desativar/ativar todos") antes
    // do primeiro widget de cada grupo — hoje só "Diagnóstico de boot"
    // (Entropy/KernelTaint/BootStatus/SystemdBootTime), mas funciona pra
    // qualquer grupo futuro sem mudar nada aqui.
    readonly property var menuRows: {
        const rows = [];
        let lastGroup = null;
        for (const w of WidgetVisibilityService.catalog) {
            const group = w.group || null;
            if (group !== null && group !== lastGroup) {
                rows.push({ isHeader: true, group });
            }
            rows.push({ isHeader: false, widget: w });
            lastGroup = group;
        }
        return rows;
    }

    implicitWidth: Math.max(button.implicitWidth, root.open ? root.panelWidth : 0)
    implicitHeight: button.implicitHeight + (root.open ? 6 + panel.height : 0)

    Rectangle {
        id: button
        anchors.top: parent.top
        anchors.right: parent.right
        implicitWidth: buttonLabel.implicitWidth + 24
        implicitHeight: buttonLabel.implicitHeight + 14
        radius: Appearance.radiusSmall
        color: Appearance.colors.cardBackground
        border.width: 1
        border.color: root.open ? Appearance.colors.accent : Appearance.colors.cardBorder

        StyledText {
            id: buttonLabel
            anchors.centerIn: parent
            text: "MENU"
            font.bold: true
            font.letterSpacing: 1
            font.pixelSize: Appearance.font.sizeSmall
            color: root.open ? Appearance.colors.accent : Appearance.colors.text
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    Rectangle {
        id: panel
        visible: root.open
        anchors.top: button.bottom
        anchors.topMargin: 6
        anchors.right: button.right
        width: root.panelWidth
        implicitHeight: menuColumn.implicitHeight + 16
        radius: Appearance.radiusSmall
        color: Appearance.colors.cardBackground
        border.width: 1
        border.color: Appearance.colors.cardBorder

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            StyledText {
                text: "WIDGETS"
                font.bold: true
                font.letterSpacing: 1
                font.pixelSize: Appearance.font.sizeSmall - 1
                color: Appearance.colors.textFaint
                bottomPadding: 4
            }

            Repeater {
                model: root.menuRows

                delegate: Item {
                    id: rowItem
                    width: menuColumn.width
                    height: modelData.isHeader ? root.rowHeight + 8 : root.rowHeight

                    // Cabeçalho de grupo: nome do grupo + toggle "ativar/
                    // desativar todos" — só existe pra grupos definidos
                    // (ver menuRows); widgets soltos (sem group) não
                    // ganham cabeçalho nenhum.
                    Row {
                        id: headerRow
                        visible: modelData.isHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4

                        readonly property bool groupOn: modelData.isHeader && WidgetVisibilityService.isGroupFullyEnabled(modelData.group)

                        StyledText {
                            width: parent.width - allToggle.implicitWidth
                            text: modelData.isHeader ? modelData.group.toUpperCase() : ""
                            font.bold: true
                            font.letterSpacing: 1
                            font.pixelSize: Appearance.font.sizeSmall - 1
                            color: Appearance.colors.textFaint
                        }

                        StyledText {
                            id: allToggle
                            text: headerRow.groupOn ? "desativar todos" : "ativar todos"
                            font.pixelSize: Appearance.font.sizeSmall - 1
                            color: Appearance.colors.accent

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WidgetVisibilityService.setGroupEnabled(modelData.group, !headerRow.groupOn)
                            }
                        }
                    }

                    // Linha normal: checkbox + nome do widget.
                    Item {
                        visible: !modelData.isHeader
                        anchors.fill: parent

                        readonly property bool widgetOn: !modelData.isHeader && WidgetVisibilityService.isEnabled(modelData.widget.key)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            text: parent.widgetOn ? "☑" : "☐"
                            font.pixelSize: Appearance.font.sizeNormal
                            color: parent.widgetOn ? Appearance.colors.accent : Appearance.colors.textMuted
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 22
                            text: modelData.isHeader ? "" : modelData.widget.label
                            font.pixelSize: Appearance.font.sizeSmall
                            color: parent.widgetOn ? Appearance.colors.text : Appearance.colors.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WidgetVisibilityService.setEnabled(modelData.widget.key, !parent.widgetOn)
                        }
                    }
                }
            }
        }
    }
}
