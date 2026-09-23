import QtQuick
import QtQuick.Controls

Rectangle {
    color: "#2b2d30"
    radius: 6

    Column {
        anchors.centerIn: parent
        spacing: 8

        Text { text: "🎨 Plugin QML Cargado"; color: "#fff"; font.bold: true }

        Button {
            text: "Cambiar Color"
            onClicked: box.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
        }

        Rectangle { id: box; width: 80; height: 30; radius: 4; color: "#cba6f7" }
    }
}
