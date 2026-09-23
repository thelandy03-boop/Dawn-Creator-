import QtQuick
import ".."

Rectangle {
    id: root
    color: Theme.screenBg
    radius: Theme.radius

    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.right: parent.right
        height: 2; color: "#09090a"; radius: root.radius
    }
    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 2; color: "#09090a"; radius: root.radius
    }
    Rectangle {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.left: parent.left
        height: 1; color: "#3a3c40"; radius: root.radius
    }
}
