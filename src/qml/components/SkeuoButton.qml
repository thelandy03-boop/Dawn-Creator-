import QtQuick
import QtQuick.Controls
import ".."
import "../icons"

Rectangle {
    id: root
    property string iconName: ""
    property string label: ""
    property bool isActive: false
    property bool isPrimary: false
    property string toolTipText: ""
    signal clicked()

    // Dimensiones implícitas para que RowLayout/ColumnLayout respeten el tamaño exacto
    implicitWidth: label === "" ? 36 : (txt.implicitWidth + (iconName !== "" ? 34 : 20))
    implicitHeight: 32
    width: implicitWidth
    height: implicitHeight
    radius: Theme.radius
    opacity: enabled ? 1.0 : 0.5

    ToolTip.visible: toolTipText !== "" && ma.containsMouse
    ToolTip.text: toolTipText

    property bool isDown: ma.pressed || isActive

    gradient: Gradient {
        GradientStop { position: 0.0; color: root.isDown ? Theme.btnPressed : (root.isPrimary ? "#2a6fbf" : Theme.btnTop) }
        GradientStop { position: 1.0; color: root.isDown ? Theme.btnPressed : (root.isPrimary ? "#1e4f8a" : Theme.btnBottom) }
    }

    border.color: Theme.borderDark
    border.width: 1

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        color: "transparent"
        border.color: root.isPrimary ? "#5a9fef" : Theme.borderLight
        border.width: 1
        visible: !root.isDown
    }

    Row {
        anchors.centerIn: parent
        spacing: 5

        AppIcon {
            visible: root.iconName !== ""
            name: root.iconName
            size: 14
            color: root.isDown || root.isPrimary ? "#ffffff" : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: txt
            visible: root.label !== ""
            text: root.label
            color: root.isDown || root.isPrimary ? "#ffffff" : Theme.text
            font.pixelSize: 11
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
