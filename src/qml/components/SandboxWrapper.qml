import QtQuick
import QtQuick.Controls

Rectangle {
    id: wrapper
    color: "#0d0e10"
    clip: true

    readonly property bool isSandboxContainer: true
    property alias targetItem: containerArea

    // Fondo reticulado sutil
    Canvas {
        anchors.fill: parent
        opacity: 0.15
        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = "#ffffff"
            ctx.lineWidth = 1
            var gridSize = 20

            for (var x = 0; x < width; x += gridSize) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }

            for (var y = 0; y < height; y += gridSize) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
    }

    Item {
        id: containerArea
        anchors.fill: parent
    }
}