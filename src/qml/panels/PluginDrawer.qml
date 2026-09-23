import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../icons"

Rectangle {
    color: Theme.screenBg

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        anchors.margins: 12

        Row {
            spacing: 8
            AppIcon { name: "plugin"; color: Theme.accent; size: 18 }
            Text { text: "PLUGINS INSTALADOS"; color: Theme.text; font.bold: true }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            color: "#1c1d1f"
            radius: 6

            Loader {
                id: pluginLoader
                anchors.fill: parent
                anchors.margins: 8
            }

            Text {
                anchors.centerIn: parent
                visible: pluginLoader.source == ""
                text: "Haz clic en 'Abrir' abajo\npara cargar un plugin"
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: PluginManager.availablePlugins
            spacing: 6

            delegate: Rectangle {
                width: ListView.view.width
                height: 50
                color: Theme.btnTop
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8

                    Column {
                        Layout.fillWidth: true
                        Text { text: modelData.name; color: "#fff"; font.bold: true }
                        Text { text: modelData.description; color: Theme.textMuted; font.pixelSize: 10 }
                    }

                    Button {
                        text: "Abrir"
                        onClicked: pluginLoader.source = "file://" + modelData.entryPoint
                    }
                }
            }
        }
    }
}
