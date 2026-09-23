import QtQuick
import QtWebView
import ".."

Rectangle {
    id: engineRoot
    color: Theme.screenBg
    clip: true

    property string currentPath: ""
    property bool ready: false

    signal codeEdited(string text, string path)

    WebView {
        id: webView
        anchors.fill: parent
        url: "qrc:/qt/qml/DawnStudio/src/qml/editor/editor.html"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebView.LoadSucceededStatus) {
                engineRoot.ready = true
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
            if (title.indexOf("docChange:") === 0) {
                getCode(function(text) {
                    if (typeof ProjectModel !== "undefined" && ProjectModel.currentIndex >= 0) {
                        ProjectModel.setModified(ProjectModel.currentIndex, true)
                        ProjectModel.updateContent(ProjectModel.currentIndex, text)
                    }
                    engineRoot.codeEdited(text, currentPath)
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
            if (code < 128) {
                utf8Bytes.push(code)
            } else if (code < 2048) {
                utf8Bytes.push(192 | (code >> 6), 128 | (code & 63))
            } else {
                utf8Bytes.push(224 | (code >> 12), 128 | ((code >> 6) & 63), 128 | (code & 63))
            }
        }
        let b64 = Qt.btoa(String.fromCharCode.apply(null, utf8Bytes))
        webView.runJavaScript("if (typeof setCodeB64 === 'function') setCodeB64('" + b64 + "');")
    }

    function getCode(callback) {
        webView.runJavaScript("if (typeof getCode === 'function') getCode(); else '';", function(result) {
            if (callback) callback(result || "")
        })
    }

    function saveCurrent() {
        if (typeof ProjectModel === "undefined" || ProjectModel.currentIndex < 0) return
        getCode(function(text) {
            let f = ProjectModel.fileAt(ProjectModel.currentIndex)
            if (!f || !f.path) return
            if (typeof FileManager !== "undefined" && FileManager.writeFile(f.path, text)) {
                ProjectModel.setModified(ProjectModel.currentIndex, false)
                ProjectModel.updateContent(ProjectModel.currentIndex, text)
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
                currentPath = f.path || ""
                loadCode(f.content || "")
                engineRoot.codeEdited(f.content || "", currentPath)
            } else {
                currentPath = ""
            }
        }

        function onCurrentFileChanged(path, content) {
            currentPath = path
            loadCode(content)
            engineRoot.codeEdited(content || "", currentPath)
        }
    }
}