import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../icons"

Rectangle {
    id: explorer
    color: Theme.bgBar

    signal fileClicked(string path, string name)
    signal closeRequested()

    // Raíz fija del workspace (no se sale con ↑)
    property string rootPath: FileManager.currentFolder
    property string activeFolderPath: rootPath
    property string clipboardPath: ""
    property string clipboardName: ""
    property int selectedIndex: -1
    property bool projectExpanded: true

    ListModel { id: treeModel }

    function refresh() {
        var expandedPaths = []
        for (var i = 0; i < treeModel.count; i++) {
            if (treeModel.get(i).expanded)
                expandedPaths.push(treeModel.get(i).path)
        }

        treeModel.clear()
        selectedIndex = -1

        if (!projectExpanded)
            return

        var items = FileManager.listDirectory(rootPath)
        for (var j = 0; j < items.length; j++) {
            treeModel.append({
                "name": items[j].name,
                "path": items[j].path,
                "isDir": items[j].isDir,
                "extension": items[j].extension || "",
                "level": 0,
                "expanded": false,
                "parentPath": rootPath
            })
        }

        for (var e = 0; e < expandedPaths.length; e++) {
            for (var k = 0; k < treeModel.count; k++) {
                var it = treeModel.get(k)
                if (it.path === expandedPaths[e] && !it.expanded) {
                    toggleFolder(k)
                    break
                }
            }
        }
    }

    function toggleFolder(index) {
        var item = treeModel.get(index)
        if (!item || !item.isDir)
            return

        if (item.expanded) {
            item.expanded = false
            removeChildren(index, item.level)
        } else {
            item.expanded = true
            var subItems = FileManager.listDirectory(item.path)
            var insertIndex = index + 1
            for (var i = 0; i < subItems.length; i++) {
                treeModel.insert(insertIndex + i, {
                    "name": subItems[i].name,
                    "path": subItems[i].path,
                    "isDir": subItems[i].isDir,
                    "extension": subItems[i].extension || "",
                    "level": item.level + 1,
                    "expanded": false,
                    "parentPath": item.path
                })
            }
            activeFolderPath = item.path
        }
    }

    function removeChildren(parentIndex, parentLevel) {
        var checkIndex = parentIndex + 1
        while (checkIndex < treeModel.count) {
            var child = treeModel.get(checkIndex)
            if (child.level > parentLevel)
                treeModel.remove(checkIndex)
            else
                break
        }
    }

    function collapseAll() {
        for (var i = 0; i < treeModel.count; i++) {
            if (treeModel.get(i).expanded)
                treeModel.setProperty(i, "expanded", false)
        }
        // reconstruir solo nivel raíz
        var keep = []
        for (var j = 0; j < treeModel.count; j++) {
            if (treeModel.get(j).level === 0)
                keep.push({
                    "name": treeModel.get(j).name,
                    "path": treeModel.get(j).path,
                    "isDir": treeModel.get(j).isDir,
                    "extension": treeModel.get(j).extension,
                    "level": 0,
                    "expanded": false,
                    "parentPath": rootPath
                })
        }
        treeModel.clear()
        for (var k = 0; k < keep.length; k++)
            treeModel.append(keep[k])
    }

    function iconColorFor(item) {
        if (item.isDir)
            return Theme.yellow
        switch (item.extension) {
        case "qml": case "js": return Theme.accent
        case "cpp": case "h": case "c": case "hpp": return Theme.purple
        case "json": case "md": case "txt": return Theme.yellow
        default: return Theme.textMuted
        }
    }

    Component.onCompleted: {
        activeFolderPath = rootPath
        refresh()
    }

    Connections {
        target: FileManager
        function onCurrentFolderChanged() {
            rootPath = FileManager.currentFolder
            activeFolderPath = rootPath
            projectExpanded = true
            refresh()
        }
    }

    // Icono plano tipo VS Code
    component VsIconBtn: Item {
        id: vib
        property string iconName: ""
        property string glyph: ""
        property color fg: Theme.textMuted
        signal clicked()

        width: 22
        height: 22

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: ma.containsMouse ? "#2a2f36" : "transparent"
        }

        AppIcon {
            anchors.centerIn: parent
            visible: vib.iconName !== ""
            name: vib.iconName
            size: 14
            color: ma.containsMouse ? Theme.textActive : vib.fg
        }

        Text {
            anchors.centerIn: parent
            visible: vib.glyph !== ""
            text: vib.glyph
            color: ma.containsMouse ? Theme.textActive : vib.fg
            font.pixelSize: 12
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: vib.clicked()
        }
        ToolTip.visible: ma.containsMouse && vib.glyph === "" && vib.iconName !== ""
        ToolTip.text: vib.iconName
        ToolTip.delay: 600
    }

    component MenuRow: Rectangle {
        id: mrow
        property string label: ""
        property bool danger: false
        signal clicked()

        height: 30
        radius: 3
        color: mMa.containsMouse ? (danger ? "#3a1e1e" : "#2a3038") : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: mrow.label
            color: mrow.danger
                   ? (mMa.containsMouse ? "#ff6b6b" : "#ff5555")
                   : (mMa.containsMouse ? Theme.textActive : Theme.text)
            font.pixelSize: 12
        }

        MouseArea {
            id: mMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mrow.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═══ Título EXPLORADOR (como VS Code) ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Theme.bgBar

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "EXPLORADOR"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.1
                    Layout.fillWidth: true
                }

                // Cerrar drawer (Dawn lo necesita; VS Code no)
                VsIconBtn {
                    iconName: "close"
                    fg: Theme.textMuted
                    onClicked: explorer.closeRequested()
                }
            }
        }

        // ═══ Cabecera del workspace: ▾ QML-EDITOR + acciones ═══
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: projMa.containsMouse ? "#252a30" : Theme.bgBar

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 6
                spacing: 2

                // Chevron + nombre proyecto (click = colapsar/expandir árbol)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            text: projectExpanded ? "▼" : "▶"
                            color: Theme.textMuted
                            font.pixelSize: 8
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: (FileManager.projectName || "PROJECT").toUpperCase()
                            color: Theme.textActive
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: projMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            projectExpanded = !projectExpanded
                            if (projectExpanded)
                                refresh()
                            else
                                treeModel.clear()
                        }
                    }
                }

                // Nuevo archivo
                VsIconBtn {
                    iconName: "file"
                    fg: Theme.textMuted
                    onClicked: {
                        activeFolderPath = rootPath
                        dialogInput.openDialog(
                            "Nuevo archivo",
                            "Nombre (ej: Main.qml)",
                            "",
                            function(name) {
                                if (!name || !name.trim()) return
                                if (FileManager.createFile(activeFolderPath + "/" + name.trim()))
                                    refresh()
                            })
                    }
                }

                // Nueva carpeta
                VsIconBtn {
                    iconName: "folder"
                    fg: Theme.textMuted
                    onClicked: {
                        activeFolderPath = rootPath
                        dialogInput.openDialog(
                            "Nueva carpeta",
                            "Nombre de la carpeta",
                            "",
                            function(name) {
                                if (!name || !name.trim()) return
                                if (FileManager.createFolder(activeFolderPath + "/" + name.trim()))
                                    refresh()
                            })
                    }
                }

                // Pegar si hay corte
                VsIconBtn {
                    glyph: "⇩"
                    fg: Theme.accent
                    visible: clipboardPath !== ""
                    onClicked: {
                        var dest = activeFolderPath + "/" + clipboardName
                        if (FileManager.renamePath(clipboardPath, dest)) {
                            clipboardPath = ""
                            clipboardName = ""
                            refresh()
                        }
                    }
                }

                // Refrescar
                VsIconBtn {
                    glyph: "↻"
                    fg: Theme.textMuted
                    onClicked: refresh()
                }

                // Colapsar todo
                VsIconBtn {
                    glyph: "☰"
                    fg: Theme.textMuted
                    onClicked: collapseAll()
                }
            }
        }

        // Separador fino
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderDark
        }

        // ═══ Árbol (sin path bar, sin ↑) ═══
        ListView {
            id: fileList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: treeModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5
            }

            delegate: Rectangle {
                width: fileList.width
                height: 26
                color: {
                    if (index === explorer.selectedIndex)
                        return "#2a3340"
                    if (rowMa.containsMouse)
                        return "#252a30"
                    return "transparent"
                }

                Rectangle {
                    anchors.left: parent.left
                    width: 2
                    height: parent.height
                    color: Theme.accent
                    visible: index === explorer.selectedIndex
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10 + (model.level * 12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        width: 10
                        text: model.isDir ? (model.expanded ? "▼" : "▶") : " "
                        color: Theme.textMuted
                        font.pixelSize: 8
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    AppIcon {
                        name: model.isDir ? "folder" : "file"
                        size: 13
                        color: explorer.iconColorFor(model)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: model.name
                        color: (index === explorer.selectedIndex || rowMa.containsMouse)
                               ? Theme.textActive : Theme.text
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: Math.max(40, fileList.width - (10 + model.level * 12 + 50))
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ⋮ hover
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⋮"
                    color: Theme.textMuted
                    font.pixelSize: 12
                    visible: rowMa.containsMouse

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            explorer.selectedIndex = index
                            if (model.isDir)
                                explorer.activeFolderPath = model.path
                            contextMenu.openFor(model.name, model.path, model.isDir)
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        explorer.selectedIndex = index
                        if (mouse.button === Qt.RightButton) {
                            if (model.isDir)
                                explorer.activeFolderPath = model.path
                            contextMenu.openFor(model.name, model.path, model.isDir)
                            return
                        }
                        if (model.isDir) {
                            explorer.toggleFolder(index)
                            explorer.activeFolderPath = model.path
                        } else {
                            explorer.fileClicked(model.path, model.name)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: fileList.count === 0 && projectExpanded
                text: "Carpeta vacía"
                color: Theme.textMuted
                font.pixelSize: 12
            }
        }
    }

    // ═══ Menú contextual ═══
    Rectangle {
        id: contextMenu
        anchors.fill: parent
        color: "#b0000000"
        visible: false
        z: 20

        property string targetName: ""
        property string targetPath: ""
        property bool targetIsDir: false

        function openFor(name, path, isDir) {
            targetName = name
            targetPath = path
            targetIsDir = isDir
            visible = true
        }
        function closeMenu() { visible = false }

        MouseArea { anchors.fill: parent; onClicked: contextMenu.closeMenu() }

        Rectangle {
            width: 200
            height: menuCol.implicitHeight + 14
            anchors.centerIn: parent
            radius: 4
            color: "#1e2226"
            border.color: Theme.borderDark
            border.width: 1

            Column {
                id: menuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 7
                spacing: 1

                Text {
                    width: parent.width
                    text: contextMenu.targetName
                    color: Theme.accent
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                    bottomPadding: 4
                }

                Rectangle { width: parent.width; height: 1; color: Theme.borderDark }

                MenuRow {
                    width: parent.width
                    label: "Renombrar"
                    onClicked: {
                        contextMenu.closeMenu()
                        dialogInput.openDialog("Renombrar", "Nuevo nombre", contextMenu.targetName, function(newName) {
                            if (!newName || !newName.trim() || newName === contextMenu.targetName) return
                            var parentDir = FileManager.parentDir(contextMenu.targetPath)
                            if (FileManager.renamePath(contextMenu.targetPath, parentDir + "/" + newName.trim()))
                                refresh()
                        })
                    }
                }

                MenuRow {
                    width: parent.width
                    label: "Cortar"
                    onClicked: {
                        clipboardPath = contextMenu.targetPath
                        clipboardName = contextMenu.targetName
                        contextMenu.closeMenu()
                    }
                }

                MenuRow {
                    width: parent.width
                    label: "Nueva carpeta aquí"
                    visible: contextMenu.targetIsDir
                    onClicked: {
                        var base = contextMenu.targetPath
                        contextMenu.closeMenu()
                        dialogInput.openDialog("Nueva carpeta", "Nombre", "", function(name) {
                            if (!name || !name.trim()) return
                            if (FileManager.createFolder(base + "/" + name.trim()))
                                refresh()
                        })
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.borderDark }

                MenuRow {
                    width: parent.width
                    label: "Eliminar"
                    danger: true
                    onClicked: {
                        contextMenu.closeMenu()
                        confirmDialog.openConfirm(
                            "Eliminar",
                            "¿Eliminar \"" + contextMenu.targetName + "\"?",
                            function() {
                                if (FileManager.deletePath(contextMenu.targetPath))
                                    refresh()
                            })
                    }
                }
            }
        }
    }

    // ═══ Diálogo input ═══
    Rectangle {
        id: dialogInput
        anchors.fill: parent
        color: "#c0000000"
        visible: false
        z: 30

        property string titleText: ""
        property string hintText: ""
        property var acceptCb: null

        function openDialog(title, hint, initial, cb) {
            titleText = title
            hintText = hint
            acceptCb = cb
            inputField.text = initial || ""
            visible = true
            inputField.forceActiveFocus()
            inputField.selectAll()
        }
        function closeDialog() { visible = false }

        MouseArea { anchors.fill: parent; onClicked: dialogInput.closeDialog() }

        Rectangle {
            width: 250
            height: 142
            anchors.centerIn: parent
            radius: 4
            color: "#1e2226"
            border.color: Theme.borderDark
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: dialogInput.titleText
                    color: Theme.textActive
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: dialogInput.hintText
                    color: Theme.textMuted
                    font.pixelSize: 11
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 3
                    color: "#121416"
                    border.width: 1
                    border.color: inputField.activeFocus ? Theme.accent : Theme.borderDark

                    TextInput {
                        id: inputField
                        anchors.fill: parent
                        anchors.margins: 8
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                        font.pixelSize: 12
                        selectByMouse: true
                        clip: true
                        Keys.onReturnPressed: okBtn.fire()
                        Keys.onEnterPressed: okBtn.fire()
                        Keys.onEscapePressed: dialogInput.closeDialog()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 3
                        color: canMa.containsMouse ? "#2a3038" : "#222528"
                        border.color: Theme.borderDark
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.text
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            id: canMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dialogInput.closeDialog()
                        }
                    }

                    Rectangle {
                        id: okBtn
                        Layout.fillWidth: true
                        height: 28
                        radius: 3
                        color: okMa.containsMouse ? "#2d6bb5" : "#225699"
                        border.color: Theme.accent
                        border.width: 1
                        function fire() {
                            dialogInput.closeDialog()
                            if (dialogInput.acceptCb)
                                dialogInput.acceptCb(inputField.text)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "Aceptar"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            id: okMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: okBtn.fire()
                        }
                    }
                }
            }
        }
    }

    // ═══ Confirm delete ═══
    Rectangle {
        id: confirmDialog
        anchors.fill: parent
        color: "#c0000000"
        visible: false
        z: 30

        property string titleText: ""
        property string bodyText: ""
        property var acceptCb: null

        function openConfirm(title, body, cb) {
            titleText = title
            bodyText = body
            acceptCb = cb
            visible = true
        }
        function closeConfirm() { visible = false }

        MouseArea { anchors.fill: parent; onClicked: confirmDialog.closeConfirm() }

        Rectangle {
            width: 250
            height: 130
            anchors.centerIn: parent
            radius: 4
            color: "#1e2226"
            border.color: Theme.borderDark
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: confirmDialog.titleText
                    color: "#ff5555"
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: confirmDialog.bodyText
                    color: Theme.text
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 3
                        color: c1.containsMouse ? "#2a3038" : "#222528"
                        border.color: Theme.borderDark
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.text
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            id: c1
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: confirmDialog.closeConfirm()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 3
                        color: c2.containsMouse ? "#a83232" : "#8a2525"
                        border.color: "#5a2020"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Eliminar"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            id: c2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                confirmDialog.closeConfirm()
                                if (confirmDialog.acceptCb)
                                    confirmDialog.acceptCb()
                            }
                        }
                    }
                }
            }
        }
    }
}