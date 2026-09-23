import QtQuick
import QtQuick.Controls
import ".."
import "../icons"

Rectangle {
    id: tabBar
    height: Theme.tabHeight
    color: Theme.bgBar
    visible: ProjectModel.count > 0

    signal tabSelected(int index)
    signal tabClosed(int index)

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.borderDark
        z: 2
    }

    Flickable {
        anchors.fill: parent
        contentWidth: tabRowContainer.width
        flickableDirection: Flickable.HorizontalFlick
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: tabRowContainer
            height: parent.height
            spacing: 2

            Repeater {
                model: ProjectModel.openFiles

                Rectangle {
                    id: tabItem
                    height: Theme.tabHeight
                    width: Math.max(110, labelText.implicitWidth + 48)
                    color: index === ProjectModel.currentIndex
                           ? Theme.bgTabActive
                           : (tabMA.containsMouse ? Theme.bgTab : "transparent")

                    MouseArea {
                        id: tabMA
                        anchors.fill: parent
                        anchors.rightMargin: 28
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ProjectModel.currentIndex = index
                            tabBar.tabSelected(index)
                        }
                    }

                    Rectangle {
                        id: dirtyDot
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.orange
                        visible: modelData.modified === true
                    }

                    Text {
                        id: labelText
                        anchors.left: dirtyDot.visible ? dirtyDot.right : parent.left
                        anchors.leftMargin: dirtyDot.visible ? 6 : 12
                        anchors.right: closeBtnContainer.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: index === ProjectModel.currentIndex ? Theme.textActive : Theme.textDim
                        font.pixelSize: 12
                        font.bold: index === ProjectModel.currentIndex
                        font.family: "sans-serif"
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: closeBtnContainer
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 3
                        color: closeMA.containsMouse ? Theme.btnTop : "transparent"

                        AppIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 10
                            color: closeMA.containsMouse ? Theme.textActive : Theme.textMuted
                        }

                        MouseArea {
                            id: closeMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tabBar.tabClosed(index)
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: Theme.borderTab
                        visible: index === ProjectModel.currentIndex
                    }
                }
            }
        }
    }
}