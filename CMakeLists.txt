cmake_minimum_required(VERSION 3.20)
project(dawn-studio VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 WebView)

qt_add_executable(dawn-studio
    src/cpp/main.cpp
    src/core/filemanager.h
    src/core/filemanager.cpp
    src/core/projectmodel.h
    src/core/projectmodel.cpp
    src/core/pluginmanager.h
    src/core/pluginmanager.cpp
    src/core/terminalmanager.h
    src/core/terminalmanager.cpp
    src/core/qmlsandbox.h
    src/core/qmlsandbox.cpp
)

qt_add_qml_module(dawn-studio
    URI DawnStudio
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        src/qml/Main.qml
        src/qml/Theme.qml
        src/qml/components/AppTopBar.qml
        src/qml/components/EditorTabBar.qml
        src/qml/components/CodeEngine.qml
        src/qml/components/LiveCanvas.qml
        src/qml/components/SandboxWrapper.qml
        src/qml/components/SkeuoButton.qml
        src/qml/components/SkeuoPanel.qml
        src/qml/panels/FileDrawer.qml
        src/qml/panels/PluginDrawer.qml
        src/qml/panels/TerminalSheet.qml
        src/qml/icons/AppIcon.qml
    RESOURCES
        src/qml/qmldir
        src/qml/editor/editor.html
        src/qml/editor/codemirror.js
        src/qml/editor/codemirror.css
        src/qml/editor/javascript.js
        src/qml/editor/dracula.css
        src/qml/terminal/terminal.html
        src/qml/terminal/xterm.js
        src/qml/terminal/xterm.css
)

target_link_libraries(dawn-studio
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::WebView
)

if(UNIX AND NOT APPLE AND NOT ANDROID)
    target_link_libraries(dawn-studio PRIVATE util)
endif()