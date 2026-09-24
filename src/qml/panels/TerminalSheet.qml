import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebView
import ".."
import "../components"

Item {
    id: root

    onVisibleChanged: {
        if (visible) {
            if (!TerminalManager.running) {
                var targetPath = (typeof FileManager !== "undefined" && FileManager.currentFolder) ? FileManager.currentFolder : "";
                TerminalManager.startShell(targetPath);
            }
            termWebView.runJavaScript("setTimeout(function(){ if (typeof fitTerminal === 'function') { fitTerminal(); focusTerm(); } }, 100);");
        }
    }

    Connections {
        target: TerminalManager
        function onDataReceived(b64Data) {
            termWebView.runJavaScript("if (typeof window.writeB64 === 'function') window.writeB64('" + b64Data + "');");
        }
        function onRunningChanged(running) {
            if (!running && root.visible) {
                termWebView.runJavaScript("if (typeof window.writeB64 === 'function') window.writeB64('DQobWzMzbVtQcm9jZXNvIHRlcm1pbmFkb11bMG0NCg==');");
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header tipo hardware / AIDE
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: Theme.bgBar
            border.color: Theme.borderDark
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // LED indicador de estado PTY
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: TerminalManager.running ? "#50fa7b" : "#ff5555"
                    border.color: Qt.darker(color, 1.4)
                }

                Text {
                    text: "TERMINAL PTY"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                SkeuoButton {
                    label: "^C"
                    onClicked: TerminalManager.interrupt()
                }

                SkeuoButton {
                    label: "CLEAR"
                    onClicked: termWebView.runJavaScript("if (typeof window.clearTerm === 'function') window.clearTerm();")
                }

                SkeuoButton {
                    label: "RESTART"
                    onClicked: {
                        TerminalManager.stopShell();
                        termWebView.runJavaScript("if (typeof window.clearTerm === 'function') window.clearTerm();");
                        var targetPath = (typeof FileManager !== "undefined" && FileManager.currentFolder) ? FileManager.currentFolder : "";
                        TerminalManager.startShell(targetPath);
                    }
                }

                SkeuoButton {
                    label: "✕"
                    onClicked: {
                        if (typeof terminalDrawer !== "undefined") {
                            terminalDrawer.close();
                        }
                    }
                }
            }
        }

        // Terminal xterm.js embebido
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WebView {
                id: termWebView
                anchors.fill: parent
                url: typeof WebAssets !== "undefined" ? WebAssets.terminalUrl : ""
                settings.localContentCanAccessFileUrls: true

                onLoadingChanged: function(loadRequest) {
                    if (loadRequest.status === WebView.LoadSucceededStatus) {
                        var targetPath = (typeof FileManager !== "undefined" && FileManager.currentFolder) ? FileManager.currentFolder : "";
                        if (!TerminalManager.running) {
                            TerminalManager.startShell(targetPath);
                        }
                        runJavaScript("setTimeout(function(){ if (typeof fitTerminal === 'function') { fitTerminal(); focusTerm(); } }, 120);");
                    }
                }

                onTitleChanged: {
                    if (title.indexOf("pty:") === 0) {
                        var parts = title.split(":");
                        if (parts.length >= 3) {
                            var type = parts[2];
                            if (type === "in" && parts.length >= 4) {
                                var b64Data = parts.slice(3).join(":");
                                TerminalManager.sendInputB64(b64Data);
                            } else if (type === "resize" && parts.length >= 5) {
                                var cols = parseInt(parts[3]);
                                var rows = parseInt(parts[4]);
                                TerminalManager.resizePty(cols, rows);
                            }
                        }
                    }
                }
            }
        }
    }
}
