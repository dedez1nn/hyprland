import QtQuick
import ".."
import "../../services"

/**
 * Alças de redimensionar de um Card resizable: borda direita (só
 * largura), borda inferior (só altura), canto inferior-direito (as duas
 * juntas, na diagonal). `target` é o Card (precisa expor cardWidth/
 * cardHeight graváveis); tamanho final persistido em WidgetSizeService
 * por `positionKey`.
 *
 * Cada alça usa mapToItem(target, mouse.x, mouse.y) pra converter a
 * posição do mouse (relativa à própria alça, que se move junto com a
 * borda que ela ancora) pra coordenadas fixas relativas ao target —
 * target.x/y não mudam durante o resize, só cardWidth/cardHeight
 * crescem.
 */
Item {
    id: root
    required property Item target
    required property string positionKey
    required property real minWidth
    required property real minHeight
    anchors.fill: parent
    z: 50

    function persist() {
        WidgetSizeService.setSize(root.positionKey, root.target.cardWidth, root.target.cardHeight);
    }

    MouseArea {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 10
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        onPressed: WidgetPositionService.dragging = true
        onPositionChanged: (mouse) => {
            if (pressed) {
                const p = mapToItem(root.target, mouse.x, mouse.y);
                root.target.cardWidth = Math.max(root.minWidth, p.x);
            }
        }
        onReleased: {
            WidgetPositionService.dragging = false;
            root.persist();
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 10
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        onPressed: WidgetPositionService.dragging = true
        onPositionChanged: (mouse) => {
            if (pressed) {
                const p = mapToItem(root.target, mouse.x, mouse.y);
                root.target.cardHeight = Math.max(root.minHeight, p.y);
            }
        }
        onReleased: {
            WidgetPositionService.dragging = false;
            root.persist();
        }
    }

    Item {
        id: cornerHandle
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 16
        height: 16

        Rectangle {
            width: 12
            height: 2
            radius: 1
            color: Appearance.colors.accentAlt
            anchors.centerIn: parent
            rotation: -45
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: WidgetPositionService.dragging = true
            onPositionChanged: (mouse) => {
                if (pressed) {
                    const p = mapToItem(root.target, mouse.x, mouse.y);
                    root.target.cardWidth = Math.max(root.minWidth, p.x);
                    root.target.cardHeight = Math.max(root.minHeight, p.y);
                }
            }
            onReleased: {
                WidgetPositionService.dragging = false;
                root.persist();
            }
        }
    }
}
