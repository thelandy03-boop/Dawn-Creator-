import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "panels"

ApplicationWindow {
    id: window
    width: 1100
    height: 720
    minimumWidth: 360
    minimumHeight: 500
    visible: true
    title: windowTitle()
    color: Theme.bgHardware

    readonly property bool inSandbox: typeof isSandbox !== "undefined" && isSandbox
    // Si está en el Sandbox, mantiene la interfaz completa de escritorio sin pasar a modo móvil
    readonly property bool isMobile: !inSandbox && width < 720
    property bool showLiveCanvas: false

    function windowTitle() {
        let f = ProjectModel.fileAt(ProjectModel.currentIndex)
        if (f && f.name)
            return (f.modified ? "\u25CF " : "") + f.name + " — Dawn Studio"
        return "Dawn Studio"
    }

    Shortcut { sequence: "Ctrl+S"; onActivated: codeEngine.saveCurrent() }
    Shortcut { sequence: "Ctrl+O"; onActivated: openFileDialog.open() }
    Shortcut { sequence: "Ctrl+W"; onActivated: if (ProjectModel.currentIndex >= 0) ProjectModel.closeFile(ProjectModel.currentIndex) }
    Shortcut { sequence: "Ctrl+B"; onActivated: fileDrawer.opened ? fileDrawer.close() : fileDrawer.open() }
    Shortcut { sequence: "Ctrl+J"; onActivated: terminalDrawer.opened ? terminalDrawer.close() : terminalDrawer.open() }
    Shortcut { sequence: "Ctrl+L"; onActivated: window.showLiveCanvas = !window.showLiveCanvas }

    function openPath(path) {
        let content = FileManager.readFile(path)
        ProjectModel.openFile(path, content)
    }

    Connections {
        target: ProjectModel
        function onCurrentIndexChanged() {
            let f = ProjectModel.fileAt(ProjectModel.currentIndex)
            if (f && f.path) {
                liveCanvas.currentFilePath = f.path
                liveCanvas.qmlCode = FileManager.readFile(f.path)
            }
        }
    }

    // ═══ DRAWER EXPLORER (izquierda) ═══
    Drawer {
        id: fileDrawer
        width: Math.min(280, window.width * 0.85)
        height: parent.height
        edge: Qt.LeftEdge
        modal: true
        dim: false
        interactive: true
        dragMargin: 30

        background: Rectangle {
            color: Theme.bgBar
            Rectangle {
                anchors.right: parent.right
                width: 1; height: parent.height
                color: Theme.borderDark
            }
        }

        FileDrawer {
            anchors.fill: parent
            onFileClicked: function(path, name) {
                openPath(path)
                fileDrawer.close()
            }
            onCloseRequested: fileDrawer.close()
        }
    }

    // ═══ DRAWER PLUGINS (derecha) ═══
    Drawer {
        id: pluginDrawer
        width: Math.min(320, window.width * 0.9)
        height: parent.height
        edge: Qt.RightEdge
        modal: true
        dim: false

        background: Rectangle { color: Theme.bgBar }

        PluginDrawer { anchors.fill: parent }
    }

    // ═══ DRAWER TERMINAL (abajo) ═══
    Drawer {
        id: terminalDrawer
        width: parent.width
        height: Math.min(250, window.height * 0.5)
        edge: Qt.BottomEdge
        modal: false
        dim: false

        background: Rectangle {
            color: Theme.bgBar
            Rectangle {
                anchors.top: parent.top
                width: parent.width; height: 1
                color: Theme.borderDark
            }
        }

        TerminalSheet { anchors.fill: parent }
    }

    // ═══ LAYOUT PRINCIPAL ═══
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        AppTopBar {
            Layout.fillWidth: true
            isMobile: window.isMobile
            explorerOpen: fileDrawer.opened
            onToggleExplorer: fileDrawer.opened ? fileDrawer.close() : fileDrawer.open()
            onOpenPlugins: pluginDrawer.open()
            onOpenTerminal: terminalDrawer.opened ? terminalDrawer.close() : terminalDrawer.open()
            onSaveClicked: codeEngine.saveCurrent()
            onRunClicked: {
                codeEngine.saveCurrent()
                let f = ProjectModel.fileAt(ProjectModel.currentIndex)
                if (f && f.path && (f.extension === "qml" || f.extension === "py" || f.extension === "sh")) {
                    FileManager.runFile(f.path)
                } else {
                    FileManager.runProject()
                }
            }
        }

        EditorTabBar {
            id: editorTabs
            Layout.fillWidth: true
            onTabSelected: function(index) { 
                ProjectModel.currentIndex = index 
                let f = ProjectModel.fileAt(index)
                if (f && f.path) {
                    liveCanvas.currentFilePath = f.path
                    liveCanvas.qmlCode = FileManager.readFile(f.path)
                }
            }
            onTabClosed: function(index) { ProjectModel.closeFile(index) }
        }

        // Zona del Editor y Vista Dividida en Vivo
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.screenBg
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Editor de Código
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.screenBg

                    CodeEngine {
                        id: codeEngine
                        anchors.fill: parent
                        anchors.margins: 1
                        onCodeEdited: function(text, path) {
                            if (window.showLiveCanvas && !window.inSandbox) {
                                liveCanvas.currentFilePath = path
                                liveCanvas.qmlCode = text
                            }
                        }
                    }
                }

                // Separador central
                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: Theme.borderDark
                    visible: window.showLiveCanvas && !window.inSandbox
                }

                // Previsualizador Live Canvas a la derecha
                LiveCanvas {
                    id: liveCanvas
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 0.45
                    visible: window.showLiveCanvas && !window.inSandbox
                }
            }

            // Botón Flotante "LIVE CANVAS" (Oculto dentro del Sandbox)
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                width: 86; height: 28; radius: 14
                color: liveBtnMa.pressed ? "#1e4f8a" : (window.showLiveCanvas ? "#2a6fbf" : "#222528")
                border.color: window.showLiveCanvas ? "#5a9fef" : Theme.borderDark
                border.width: 1
                z: 100
                visible: !window.inSandbox

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: window.showLiveCanvas ? "#50fa7b" : "#707880"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "LIVE"
                        color: window.showLiveCanvas ? "#ffffff" : "#a0a8b0"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: liveBtnMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.showLiveCanvas = !window.showLiveCanvas
                        if (window.showLiveCanvas) {
                            let f = ProjectModel.fileAt(ProjectModel.currentIndex)
                            if (f && f.path) {
                                liveCanvas.currentFilePath = f.path
                                liveCanvas.qmlCode = FileManager.readFile(f.path)
                            } else {
                                codeEngine.getCode(function(text) {
                                    liveCanvas.qmlCode = text
                                })
                            }
                        }
                    }
                }
            }
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            color: Theme.bgBar

            Rectangle {
                anchors.top: parent.top
                width: parent.width; height: 1
                color: Theme.borderDark
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 14

                Text {
                    text: {
                        let f = ProjectModel.fileAt(ProjectModel.currentIndex)
                        if (!f) return "—"
                        return (f.extension || "Text").toUpperCase()
                    }
                    color: Theme.accent
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "monospace"
                }

                Text {
                    text: "UTF-8"
                    color: Theme.textMuted
                    font.pixelSize: 11
                }

                Text {
                    text: ProjectModel.count + " archivo(s)"
                    color: Theme.textMuted
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: FileManager.projectName || "Dawn Studio 0.3"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
        }
    }
}