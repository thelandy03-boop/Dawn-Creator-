import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"
import "panels"

ApplicationWindow {
    id: window
    width: 1100
    height: 720
    minimumWidth: inSandbox ? 360 : 0
    minimumHeight: inSandbox ? 500 : 0
    visible: true
    title: windowTitle()
    color: Theme.bgHardware

    readonly property bool inSandbox: typeof isSandbox !== "undefined" && isSandbox
    // Si está en el Sandbox, mantiene la interfaz completa de escritorio sin pasar a modo móvil
    readonly property bool compactHeight: height < 520
    readonly property bool isMobile: !inSandbox && (width < 720 || compactHeight)
    property bool showLiveCanvas: false
    property bool updateRequired: false
    property string latestVersion: ""
    property string releasePage: "https://github.com/thelandy03-boop/Dawn-Creator-/releases/latest"

    function checkForUpdate() {
        let request = new XMLHttpRequest()
        request.open("GET", "https://api.github.com/repos/thelandy03-boop/Dawn-Creator-/releases/latest")
        request.setRequestHeader("Accept", "application/vnd.github+json")
        request.setRequestHeader("X-GitHub-Api-Version", "2022-11-28")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status !== 200) {
                console.info("No se pudo consultar una actualización de Dawn (HTTP " + request.status + ")")
                return
            }
            try {
                const release = JSON.parse(request.responseText)
                const candidate = String(release.tag_name || "").replace(/^v/i, "")
                const platformAssets = {
                    "android": "Dawn-Studio-Android-arm64-v8a.apk",
                    "linux": "Dawn-Studio-Linux-x86_64.tar.gz",
                    "windows": "Dawn-Studio-Windows-x64.zip",
                    "osx": "Dawn-Studio-macOS.zip"
                }
                const expectedAsset = platformAssets[Qt.platform.os]
                const hasPlatformAsset = expectedAsset && (release.assets || []).some(function(asset) {
                    return asset.name === expectedAsset
                })
                if (!hasPlatformAsset) return

                const currentParts = String(AppVersion || "0.0.0").split(".")
                const latestParts = candidate.split(".")
                if (currentParts.length < 2 || latestParts.length < 2) return
                let comparison = 0
                for (let i = 0; i < Math.max(currentParts.length, latestParts.length); ++i) {
                    const currentNumber = parseInt(currentParts[i] || "0", 10)
                    const latestNumber = parseInt(latestParts[i] || "0", 10)
                    if (!Number.isFinite(currentNumber) || !Number.isFinite(latestNumber)) return
                    if (latestNumber !== currentNumber) {
                        comparison = latestNumber > currentNumber ? 1 : -1
                        break
                    }
                }
                if (comparison > 0) {
                    latestVersion = candidate
                    updateRequired = true
                }
            } catch (error) {
                console.warn("La respuesta de actualizaciones de Dawn no es válida:", error)
            }
        }
        request.send()
    }

    Component.onCompleted: checkForUpdate()

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

    FileDialog {
        id: openFileDialog
        title: "Abrir archivo"
        fileMode: FileDialog.OpenFile
        currentFolder: FileManager.localFileUrl(FileManager.currentFolder)
        nameFilters: ["Archivos QML y texto (*.qml *.js *.json *.txt)", "Todos los archivos (*)"]
        onAccepted: window.openPath(FileManager.localFilePath(selectedFile.toString()))
    }

    function openPath(path) {
        let localPath = FileManager.localFilePath(path)
        let content = FileManager.readFile(localPath)
        ProjectModel.openFile(localPath, content)
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
        height: Math.min(250, window.height * (window.compactHeight ? 0.65 : 0.5))
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
            hasOpenFile: ProjectModel.currentIndex >= 0
            explorerOpen: fileDrawer.opened
            onToggleExplorer: fileDrawer.opened ? fileDrawer.close() : fileDrawer.open()
            onOpenPlugins: pluginDrawer.open()
            onOpenTerminal: terminalDrawer.opened ? terminalDrawer.close() : terminalDrawer.open()
            onSaveClicked: codeEngine.saveCurrent()
            onPasteClicked: codeEngine.pasteClipboard()
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
            Layout.preferredHeight: window.compactHeight ? 20 : 24
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
                    visible: !window.compactHeight
                }

                Text {
                    text: ProjectModel.count + " archivo(s)"
                    color: Theme.textMuted
                    font.pixelSize: 11
                }

                Text {
                    text: QmlLanguageManager.status
                    color: QmlLanguageManager.status === "qmlls conectado" ? "#50fa7b" : Theme.textMuted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                    visible: !window.compactHeight
                    ToolTip.visible: statusMouse.containsMouse
                    ToolTip.text: QmlLanguageManager.status
                    MouseArea { id: statusMouse; anchors.fill: parent; hoverEnabled: true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: FileManager.projectName || "Dawn Studio 0.3"
                    color: Theme.textMuted
                    font.pixelSize: 10
                    visible: !window.compactHeight
                }
            }
        }
    }

    // Una versión obligatoria cubre toda la app hasta que se instale y reinicie
    // la versión más reciente publicada en GitHub Releases.
    Rectangle {
        anchors.fill: parent
        z: 10000
        visible: window.updateRequired
        color: "#e6111317"

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 430)
            height: updateCardColumn.implicitHeight + 40
            radius: 10
            color: Theme.bgBar
            border.color: Theme.accent
            border.width: 1

            ColumnLayout {
                id: updateCardColumn
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Text {
                    text: "Nueva versión del sistema"
                    color: Theme.textActive
                    font.pixelSize: 20
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: "La versión " + window.latestVersion + " es obligatoria. Actualiza Dawn Studio para continuar."
                    color: Theme.textMuted
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Button {
                    text: "ACTUALIZAR"
                    Layout.fillWidth: true
                    onClicked: Qt.openUrlExternally(window.releasePage)
                }
            }
        }
    }
}
