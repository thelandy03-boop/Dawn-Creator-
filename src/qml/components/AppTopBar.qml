import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../icons"

Rectangle {
    id: topBar
    implicitHeight: Theme.barHeight
    implicitWidth: 680
    height: implicitHeight
    color: Theme.bgBar

    property bool isMobile: false
    property bool explorerOpen: false
    property bool hasOpenFile: false

    signal toggleExplorer()
    signal openPlugins()
    signal openTerminal()
    signal saveClicked()
    signal pasteClicked()
    signal runClicked()

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.borderDark
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 8
        spacing: 8

        // Botón 3 flechas (›››)
        Rectangle {
            id: arrowsBtn
            implicitWidth: 40
            implicitHeight: 32
            width: implicitWidth
            height: implicitHeight
            radius: Theme.radius
            visible: !topBar.explorerOpen
            color: arrowsMA.pressed ? Theme.btnPressed : (arrowsMA.containsMouse ? Theme.btnTop : "transparent")
            border.color: arrowsMA.containsMouse ? Theme.borderLight : "transparent"
            border.width: 1

            AppIcon {
                anchors.centerIn: parent
                name: "arrows"
                size: 18
                color: Theme.text
            }

            MouseArea {
                id: arrowsMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: topBar.toggleExplorer()
            }
        }

        // Logo
        Row {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.ledGreen
                anchors.verticalCenter: parent.verticalCenter
                border.color: "#a0ffa0"
                border.width: 1
            }
            Text {
                text: topBar.isMobile ? "Dawn" : "Dawn Studio"
                color: Theme.textActive
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item { Layout.fillWidth: true }

        SkeuoButton {
            iconName: "paste"
            label: topBar.isMobile ? "" : "PEGAR TEXTO"
            enabled: topBar.hasOpenFile
            toolTipText: "Pegar texto del portapapeles"
            Accessible.name: "Pegar texto del portapapeles en el editor"
            onClicked: topBar.pasteClicked()
        }

        SkeuoButton {
            iconName: "save"
            label: topBar.isMobile ? "" : "SAVE"
            onClicked: topBar.saveClicked()
        }

        SkeuoButton {
            iconName: "play"
            label: topBar.isMobile ? "" : "RUN"
            isPrimary: true
            onClicked: topBar.runClicked()
        }

        SkeuoButton {
            iconName: "terminal"
            label: topBar.isMobile ? "" : "TERM"
            onClicked: topBar.openTerminal()
        }

        SkeuoButton {
            iconName: "plugin"
            label: topBar.isMobile ? "" : "PLUGINS"
            onClicked: topBar.openPlugins()
        }
    }
}
