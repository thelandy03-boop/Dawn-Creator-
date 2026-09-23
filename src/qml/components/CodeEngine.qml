import QtQuick
import QtWebView
import ".."

Rectangle {
    id: engineRoot
    color: Theme.screenBg
    clip: true

    property string currentPath: ""
    property bool ready: false
    property int lspDocumentVersion: 0
    property string lspOpenPath: ""

    signal codeEdited(string text, string path)

    WebView {
        id: webView
        anchors.fill: parent
        url: "qrc:/qt/qml/DawnStudio/src/qml/editor/editor.html"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebView.LoadSucceededStatus) {
                engineRoot.ready = true
                engineRoot.notifyLspStatus()
                if (typeof ProjectModel !== "undefined" && ProjectModel.currentIndex >= 0) {
                    let f = ProjectModel.fileAt(ProjectModel.currentIndex)
                    if (f && f.content !== undefined) {
                        currentPath = f.path || ""
                        engineRoot.loadCode(f.content)
                    }
                }
            }
        }

        onTitleChanged: {
            if (title.indexOf("dawn-lsp:") === 0) {
                engineRoot.handleLspRequest(title.substring(9))
                return
            }
            if (title.indexOf("docChange:") === 0) {
                let editedPath = engineRoot.currentPath
                getCode(function(text) {
                    if (engineRoot.currentPath !== editedPath) return
                    if (editedPath.endsWith(".qml")) {
                        engineRoot.lspDocumentVersion++
                        if (typeof QmlLanguageManager !== "undefined")
                            QmlLanguageManager.changeDocument(editedPath, text, engineRoot.lspDocumentVersion)
                    }
                    if (typeof ProjectModel !== "undefined") {
                        let index = ProjectModel.indexOfPath(editedPath)
                        if (index >= 0) {
                            ProjectModel.updateContent(index, text)
                            ProjectModel.setModified(index, true)
                        }
                    }
                    engineRoot.codeEdited(text, editedPath)
                })
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.screenBg
        visible: typeof ProjectModel !== "undefined" ? (ProjectModel.count === 0) : true
        z: 10

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "Dawn Studio"
                color: Theme.textMuted
                font.pixelSize: 22
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.5
            }
            Text {
                text: "Abre un archivo con ››› o Ctrl+O"
                color: Theme.textMuted
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.4
            }
        }
    }

    function loadCode(codeStr) {
        if (!ready || codeStr === undefined) return
        let utf8Bytes = []
        for (let i = 0; i < codeStr.length; i++) {
            let code = codeStr.charCodeAt(i)
            if (code >= 0xd800 && code <= 0xdbff && i + 1 < codeStr.length) {
                let low = codeStr.charCodeAt(i + 1)
                if (low >= 0xdc00 && low <= 0xdfff) {
                    code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00)
                    i++
                } else {
                    code = 0xfffd
                }
            } else if (code >= 0xdc00 && code <= 0xdfff) {
                code = 0xfffd
            }

            if (code < 128) {
                utf8Bytes.push(code)
            } else if (code < 2048) {
                utf8Bytes.push(192 | (code >> 6), 128 | (code & 63))
            } else if (code < 65536) {
                utf8Bytes.push(224 | (code >> 12), 128 | ((code >> 6) & 63), 128 | (code & 63))
            } else {
                utf8Bytes.push(240 | (code >> 18), 128 | ((code >> 12) & 63),
                               128 | ((code >> 6) & 63), 128 | (code & 63))
            }
        }

        let binary = ""
        for (let offset = 0; offset < utf8Bytes.length; offset += 0x8000) {
            binary += String.fromCharCode.apply(null, utf8Bytes.slice(offset, offset + 0x8000))
        }
        let b64 = Qt.btoa(binary)
        let mode = "text"
        if (typeof FileManager !== "undefined" && currentPath) {
            let extension = FileManager.fileExtension(currentPath)
            if (extension === "qml") mode = "qml"
            else if (extension === "js" || extension === "mjs") mode = "javascript"
            else if (extension === "json") mode = "json"
        }
        webView.runJavaScript("if (typeof setLspPath === 'function') setLspPath(" + JSON.stringify(currentPath) + "); if (typeof setCodeB64 === 'function') setCodeB64('" + b64 + "', '" + mode + "');")
    }

    function getCode(callback) {
        webView.runJavaScript("if (typeof getCode === 'function') getCode(); else '';", function(result) {
            if (callback) callback(result || "")
        })
    }

    function pasteClipboard() {
        if (!ready || !currentPath || typeof FileManager === "undefined") return
        let clipboardB64 = FileManager.clipboardTextB64()
        if (!clipboardB64) return
        webView.runJavaScript("if (typeof insertTextB64 === 'function') insertTextB64('" + clipboardB64 + "');")
    }

    function saveCurrent() {
        if (typeof ProjectModel === "undefined" || ProjectModel.currentIndex < 0) return
        let file = ProjectModel.fileAt(ProjectModel.currentIndex)
        if (!file || !file.path) return

        let path = file.path
        getCode(function(text) {
            if (engineRoot.currentPath !== path) return
            if (typeof FileManager !== "undefined" && FileManager.writeFile(path, text)) {
                let index = ProjectModel.indexOfPath(path)
                if (index >= 0) {
                    ProjectModel.updateContent(index, text)
                    ProjectModel.setModified(index, false)
                }
            }
        })
    }

    Connections {
        target: typeof ProjectModel !== "undefined" ? ProjectModel : null
        ignoreUnknownSignals: true

        function onCurrentIndexChanged() {
            if (typeof ProjectModel === "undefined") return
            let f = ProjectModel.fileAt(ProjectModel.currentIndex)
            if (f) {
                engineRoot.switchLspDocument(f.path || "", f.content || "")
                currentPath = f.path || ""
                loadCode(f.content || "")
                engineRoot.codeEdited(f.content || "", currentPath)
            } else {
                currentPath = ""
            }
        }

        function onCurrentFileChanged(path, content) {
            engineRoot.switchLspDocument(path, content || "")
            currentPath = path
            loadCode(content)
            engineRoot.codeEdited(content || "", currentPath)
        }
    }

    Connections {
        target: typeof QmlLanguageManager !== "undefined" ? QmlLanguageManager : null
        ignoreUnknownSignals: true
        function onNotificationReceived(method, params) {
            if (method === "textDocument/publishDiagnostics")
                webView.runJavaScript("window.setLspDiagnostics(" + JSON.stringify(JSON.stringify(params)) + ")")
        }
        function onResponseReceived(requestId, result, error) {
            webView.runJavaScript("window.applyLspResponse(" + requestId + "," + JSON.stringify(JSON.stringify({result: result, error: error})) + ")")
        }
        function onStatusChanged() {
            engineRoot.notifyLspStatus()
            if (QmlLanguageManager.status === "qmlls conectado" && engineRoot.lspOpenPath) {
                let f = ProjectModel.fileAt(ProjectModel.currentIndex)
                if (f) QmlLanguageManager.openDocument(engineRoot.lspOpenPath, f.content || "", engineRoot.lspDocumentVersion)
            }
        }
    }

    Component.onCompleted: {
        if (typeof QmlLanguageManager !== "undefined" && typeof FileManager !== "undefined")
            QmlLanguageManager.start(FileManager.currentFolder)
    }

    function notifyLspStatus() {
        if (ready && typeof QmlLanguageManager !== "undefined")
            webView.runJavaScript("window.setLspStatus(" + JSON.stringify(QmlLanguageManager.status) + ")")
    }

    function switchLspDocument(path, text) {
        if (typeof QmlLanguageManager === "undefined") return
        if (lspOpenPath && lspOpenPath !== path) QmlLanguageManager.closeDocument(lspOpenPath)
        lspOpenPath = path.endsWith(".qml") ? path : ""
        lspDocumentVersion = 1
        if (lspOpenPath) QmlLanguageManager.openDocument(lspOpenPath, text, lspDocumentVersion)
    }

    function handleLspRequest(encoded) {
        let request
        try { request = JSON.parse(decodeURIComponent(encoded)) } catch (error) { return }
        if (typeof QmlLanguageManager === "undefined") return
        if (request.type === "completion")
            QmlLanguageManager.requestCompletion(request.path, request.line, request.character, request.id)
        else if (request.type === "hover")
            QmlLanguageManager.requestHover(request.path, request.line, request.character, request.id)
    }
}
