import QtQuick
import QtQuick.Controls
import ".."

Rectangle {
    id: root
    color: "#0d0e10"
    clip: true

    readonly property bool inSandbox: typeof isSandbox !== "undefined" && isSandbox

    property string qmlCode: ""
    property string currentFilePath: ""
    property var currentLiveObject: null
    property var currentRootObj: null
    property string errorMessage: ""
    property bool hasError: false
    
    property string previewMode: "file"
    property string previewFileName: ""
    property bool hasActiveCode: false

    visible: !inSandbox

    Timer {
        id: compileDebounce
        interval: 150
        repeat: false
        onTriggered: root.recompile()
    }

    onQmlCodeChanged: if (!inSandbox) compileDebounce.restart()
    onCurrentFilePathChanged: if (!inSandbox) compileDebounce.restart()
    onPreviewModeChanged: if (!inSandbox) compileDebounce.restart()

    function recompile() {
        if (inSandbox) return

        clearCanvas()
        hasError = false
        errorMessage = ""

        var targetCode = ""
        var targetPath = ""

        if (previewMode === "project") {
            if (typeof FileManager !== "undefined") {
                var rootFolder = FileManager.currentFolder
                var candidates = [
                    rootFolder + "/src/qml/Main.qml",
                    rootFolder + "/src/Main.qml",
                    rootFolder + "/Main.qml",
                    rootFolder + "/main.qml"
                ]

                for (var i = 0; i < candidates.length; i++) {
                    if (FileManager.fileExists(candidates[i])) {
                        targetPath = candidates[i]
                        targetCode = FileManager.readFile(targetPath)
                        break
                    }
                }
            }
        } else {
            targetPath = currentFilePath
            if (qmlCode && qmlCode.trim().length > 0) {
                targetCode = qmlCode
            } else if (targetPath && typeof FileManager !== "undefined" && FileManager.fileExists(targetPath)) {
                targetCode = FileManager.readFile(targetPath)
            }
        }

        if (!targetCode || targetCode.trim() === "") {
            hasActiveCode = false
            previewFileName = "Sin archivo"
            return
        }

        hasActiveCode = true

        if (targetPath) {
            var parts = targetPath.split("/")
            previewFileName = parts[parts.length - 1]
        } else {
            previewFileName = "Sin título.qml"
        }

        var baseUrl = "qrc:/qt/qml/DawnStudio/src/qml/LiveCanvasDynamic.qml"
        if (targetPath && targetPath.length > 0) {
            baseUrl = "file://" + targetPath
        }

        var finalCode = targetCode
        if (finalCode.indexOf("import QtQuick") === -1) {
            finalCode = "import QtQuick\nimport QtQuick.Controls\nimport QtQuick.Layouts\n" + targetCode
        }

        // Al cargar un archivo suelto con setData(), Qt no hereda las
        // importaciones de su archivo original. Importar el directorio de
        // origen permite resolver componentes hermanos como SkeuoButton.
        if (previewMode === "file" && targetPath) {
            finalCode = 'import "."\n' + finalCode
        }

        if (typeof QmlSandbox !== "undefined") {
            var res = QmlSandbox.compileAndCreate(finalCode, baseUrl, sandboxWrapper.targetItem)
            if (res.error && res.error.length > 0) {
                hasError = true
                errorMessage = res.error
            } else {
                currentLiveObject = res.item
                currentRootObj = res.rootObj
            }
        }
    }

    function clearCanvas() {
        if (currentRootObj) {
            try { currentRootObj.destroy() } catch(e) {}
            currentRootObj = null; currentLiveObject = null
        } else if (currentLiveObject) {
            try { currentLiveObject.destroy() } catch(e) {}
            currentLiveObject = null
        }
    }

    // Cabecera del Canvas
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: "#222528"
        z: 30

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 8; height: 8; radius: 4
                color: !hasActiveCode ? "#707880" : (hasError ? "#ff5555" : "#50fa7b")
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "LIVE: " + previewFileName
                color: "#a0a8b0"
                font.pixelSize: 10
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                width: 72; height: 20; radius: 3
                color: root.previewMode === "project" ? "#2a6fbf" : (projMa.containsMouse ? "#32373e" : "#1a1c1e")
                border.color: root.previewMode === "project" ? "#5a9fef" : "#363a40"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "📁 Proyecto"
                    color: root.previewMode === "project" ? "#ffffff" : "#a0a8b0"
                    font.pixelSize: 9
                    font.bold: true
                }

                MouseArea {
                    id: projMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewMode = "project"
                }
            }

            Rectangle {
                width: 78; height: 20; radius: 3
                color: root.previewMode === "file" ? "#2a6fbf" : (fileMa.containsMouse ? "#32373e" : "#1a1c1e")
                border.color: root.previewMode === "file" ? "#5a9fef" : "#363a40"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "📄 Archivo"
                    color: root.previewMode === "file" ? "#ffffff" : "#a0a8b0"
                    font.pixelSize: 9
                    font.bold: true
                }

                MouseArea {
                    id: fileMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewMode = "file"
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: "#363a40"
        }
    }

    // Wrapper del lienzo
    SandboxWrapper {
        id: sandboxWrapper
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    // Estado vacío
    Rectangle {
        anchors.fill: sandboxWrapper
        color: "#0d0e10"
        visible: !hasActiveCode && !hasError
        z: 10

        Column {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 42; height: 42; radius: 21
                color: "#1e2226"
                border.color: "#363a40"
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "🎨"
                    font.pixelSize: 18
                }
            }

            Text {
                text: "Lienzo Listo"
                color: "#e0e0e0"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Abre o crea un archivo .qml para ver\nla previsualización en tiempo real."
                color: "#707880"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Tarjeta de errores de sintaxis
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        anchors.bottomMargin: 16
        height: Math.min(contentCol.implicitHeight + 16, 110)
        radius: 6
        color: "#2a1515"
        border.color: "#ff5555"
        border.width: 1
        visible: hasError
        z: 200

        Column {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: "⚠️ Error de sintaxis QML"
                color: "#ff5555"
                font.bold: true
                font.pixelSize: 11
            }

            Text {
                text: errorMessage
                color: "#ffaaaa"
                font.pixelSize: 10
                font.family: "monospace"
                wrapMode: Text.WrapAnywhere
                width: parent.width
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
