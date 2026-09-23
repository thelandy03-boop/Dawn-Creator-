import QtQuick
import QtQuick.Shapes

Item {
    id: root
    width: size
    height: size

    property string name: "file"
    property color color: "#e0e0e0"
    property int size: 18

    Item {
        width: 18
        height: 18
        scale: root.size / 18.0
        transformOrigin: Item.TopLeft

        // ── file ──
        Shape {
            visible: root.name === "file"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.5; strokeColor: root.color; fillColor: "transparent"
                startX: 5; startY: 2
                PathLine { x: 11; y: 2 } PathLine { x: 15; y: 6 }
                PathLine { x: 15; y: 16 } PathLine { x: 5; y: 16 } PathLine { x: 5; y: 2 }
            }
            ShapePath {
                strokeWidth: 1.3; strokeColor: root.color; fillColor: "transparent"
                startX: 11; startY: 2
                PathLine { x: 11; y: 6 } PathLine { x: 15; y: 6 }
            }
        }

        // ── folder ──
        Shape {
            visible: root.name === "folder"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.5; strokeColor: root.color; fillColor: "transparent"
                startX: 2; startY: 6
                PathLine { x: 2; y: 15 } PathLine { x: 16; y: 15 } PathLine { x: 16; y: 6 }
                PathLine { x: 9; y: 6 } PathLine { x: 7; y: 4 } PathLine { x: 2; y: 4 } PathLine { x: 2; y: 6 }
            }
        }

        // ── arrows (›››) ──
        Shape {
            visible: root.name === "arrows"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.8; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 2; startY: 5
                PathLine { x: 6; y: 9 } PathLine { x: 2; y: 13 }
            }
            ShapePath {
                strokeWidth: 1.8; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 7; startY: 5
                PathLine { x: 11; y: 9 } PathLine { x: 7; y: 13 }
            }
            ShapePath {
                strokeWidth: 1.8; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 12; startY: 5
                PathLine { x: 16; y: 9 } PathLine { x: 12; y: 13 }
            }
        }

        // ── close ──
        Shape {
            visible: root.name === "close"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.8; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 4; startY: 4
                PathLine { x: 14; y: 14 }
            }
            ShapePath {
                strokeWidth: 1.8; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 14; startY: 4
                PathLine { x: 4; y: 14 }
            }
        }

        // ── plugin ──
        Shape {
            visible: root.name === "plugin"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.5; strokeColor: root.color; fillColor: "transparent"
                startX: 7; startY: 2
                PathLine { x: 11; y: 2 } PathLine { x: 11; y: 4 } PathLine { x: 14; y: 4 }
                PathLine { x: 14; y: 7 } PathLine { x: 16; y: 7 } PathLine { x: 16; y: 11 }
                PathLine { x: 14; y: 11 } PathLine { x: 14; y: 14 } PathLine { x: 11; y: 14 }
                PathLine { x: 11; y: 16 } PathLine { x: 7; y: 16 } PathLine { x: 7; y: 14 }
                PathLine { x: 4; y: 14 } PathLine { x: 4; y: 11 } PathLine { x: 2; y: 11 }
                PathLine { x: 2; y: 7 } PathLine { x: 4; y: 7 } PathLine { x: 4; y: 4 }
                PathLine { x: 7; y: 4 } PathLine { x: 7; y: 2 }
            }
        }

        // ── save ──
        Shape {
            visible: root.name === "save"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.5; strokeColor: root.color; fillColor: "transparent"
                startX: 3; startY: 3
                PathLine { x: 12; y: 3 } PathLine { x: 15; y: 6 }
                PathLine { x: 15; y: 15 } PathLine { x: 3; y: 15 } PathLine { x: 3; y: 3 }
            }
        }

        // ── paste ──
        Item {
            visible: root.name === "paste"
            anchors.fill: parent
            Rectangle {
                x: parent.width * 0.22; y: parent.height * 0.18
                width: parent.width * 0.60; height: parent.height * 0.72
                radius: 1; color: "transparent"
                border.color: root.color; border.width: 1.4
            }
            Rectangle {
                x: parent.width * 0.36; y: parent.height * 0.08
                width: parent.width * 0.32; height: parent.height * 0.20
                radius: 2; color: "#222528"
                border.color: root.color; border.width: 1.2
            }
            Rectangle {
                x: parent.width * 0.34; y: parent.height * 0.48
                width: parent.width * 0.34; height: 1.4; color: root.color
            }
            Rectangle {
                x: parent.width * 0.34; y: parent.height * 0.65
                width: parent.width * 0.25; height: 1.4; color: root.color
            }
        }

        // ── play ──
        Shape {
            visible: root.name === "play"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 0; fillColor: root.color
                startX: 5; startY: 3
                PathLine { x: 15; y: 9 } PathLine { x: 5; y: 15 } PathLine { x: 5; y: 3 }
            }
        }

        // ── code ──
        Shape {
            visible: root.name === "code"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.6; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 6; startY: 5
                PathLine { x: 2; y: 9 } PathLine { x: 6; y: 13 }
            }
            ShapePath {
                strokeWidth: 1.6; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 12; startY: 5
                PathLine { x: 16; y: 9 } PathLine { x: 12; y: 13 }
            }
        }

        // ── terminal (>_) ──
        Shape {
            visible: root.name === "terminal"
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1.6; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 3; startY: 5
                PathLine { x: 8; y: 9 } PathLine { x: 3; y: 13 }
            }
            ShapePath {
                strokeWidth: 1.6; strokeColor: root.color; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 10; startY: 13
                PathLine { x: 15; y: 13 }
            }
        }
    }
}
