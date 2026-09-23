cmake_minimum_required(VERSION 3.20)
project(dawn-studio VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(UNIX AND NOT APPLE)
    find_program(DAWN_PATCHELF_EXECUTABLE NAMES patchelf)
    if(DAWN_PATCHELF_EXECUTABLE)
        # Debian's Qt plugins may have no RPATH; use patchelf for relocation.
        set(QT_DEPLOY_USE_PATCHELF ON)
        set(QT_DEPLOY_PATCHELF_EXECUTABLE "${DAWN_PATCHELF_EXECUTABLE}")
    endif()
endif()

find_package(Qt6 6.8...<6.9 REQUIRED COMPONENTS Quick QuickControls2 QuickDialogs2 WebView)

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
    src/core/qmllanguagemanager.h
    src/core/qmllanguagemanager.cpp
    src/core/qmlsandbox.h
    src/core/qmlsandbox.cpp
)

target_compile_definitions(dawn-studio PRIVATE DAWN_APP_VERSION=\"${PROJECT_VERSION}\")

if(ANDROID)
    string(REPLACE "." ";" DAWN_VERSION_PARTS "${PROJECT_VERSION}")
    list(GET DAWN_VERSION_PARTS 0 DAWN_VERSION_MAJOR)
    list(GET DAWN_VERSION_PARTS 1 DAWN_VERSION_MINOR)
    list(GET DAWN_VERSION_PARTS 2 DAWN_VERSION_PATCH)
    math(EXPR DAWN_ANDROID_VERSION_CODE
        "${DAWN_VERSION_MAJOR} * 1000000 + ${DAWN_VERSION_MINOR} * 1000 + ${DAWN_VERSION_PATCH}")
    set_target_properties(dawn-studio PROPERTIES
        QT_ANDROID_PACKAGE_NAME "io.github.thelandy03boop.dawnstudio"
        QT_ANDROID_APP_NAME "Dawn Studio"
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE "${DAWN_ANDROID_VERSION_CODE}"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 35
    )
endif()

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
        src/qml/editor/codemirror6.bundle.js
        src/qml/editor/THIRD_PARTY_NOTICES.md
        src/qml/terminal/terminal.html
        src/qml/terminal/xterm.js
        src/qml/terminal/xterm.css
)

target_link_libraries(dawn-studio
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::QuickDialogs2
        Qt6::WebView
)

if(UNIX AND NOT APPLE AND NOT ANDROID)
    target_link_libraries(dawn-studio PRIVATE util)
endif()

# Install an application-local Qt runtime so users do not need Qt on their PCs.
include(GNUInstallDirs)
if(UNIX AND NOT APPLE AND NOT ANDROID)
    set_target_properties(dawn-studio PROPERTIES
        INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
    )
endif()
if(NOT ANDROID)
    install(TARGETS dawn-studio
        BUNDLE DESTINATION .
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif()

# qmlls is a developer tool and may not be installed with every Qt kit. Bundle
# it when the packager provides it; otherwise the editor reports that it is absent.
set(DAWN_QMLLS_EXECUTABLE "" CACHE FILEPATH "Optional Qt 6.8 qmlls executable to bundle")
if(NOT DAWN_QMLLS_EXECUTABLE)
    find_program(DAWN_QMLLS_DISCOVERED NAMES qmlls qmlls.exe)
    if(DAWN_QMLLS_DISCOVERED)
        set(DAWN_QMLLS_EXECUTABLE "${DAWN_QMLLS_DISCOVERED}")
    endif()
endif()
if(DAWN_QMLLS_EXECUTABLE AND NOT ANDROID)
    install(PROGRAMS "${DAWN_QMLLS_EXECUTABLE}" DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

if(NOT ANDROID)
    qt_generate_deploy_qml_app_script(
        TARGET dawn-studio
        OUTPUT_SCRIPT deploy_qt_runtime_script
        NO_UNSUPPORTED_PLATFORM_ERROR
        DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
    )
    install(SCRIPT "${deploy_qt_runtime_script}")
endif()

if(UNIX AND NOT APPLE AND NOT ANDROID)
    find_program(DAWN_QTPATHS_EXECUTABLE NAMES qtpaths6 qtpaths REQUIRED)
    execute_process(COMMAND "${DAWN_QTPATHS_EXECUTABLE}" --query QT_INSTALL_PLUGINS
        OUTPUT_VARIABLE DAWN_QT_PLUGIN_DIR OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND "${DAWN_QTPATHS_EXECUTABLE}" --query QT_INSTALL_LIBEXECS
        OUTPUT_VARIABLE DAWN_QT_LIBEXEC_DIR OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND "${DAWN_QTPATHS_EXECUTABLE}" --query QT_INSTALL_DATA
        OUTPUT_VARIABLE DAWN_QT_DATA_DIR OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)

    file(GLOB DAWN_QPA_PLUGIN_FILES "${DAWN_QT_PLUGIN_DIR}/platforms/*.so")
    if(DAWN_QPA_PLUGIN_FILES)
        install(FILES ${DAWN_QPA_PLUGIN_FILES} DESTINATION "${CMAKE_INSTALL_DATADIR}/qt6/plugins/platforms")
    endif()
    file(GLOB DAWN_WEBVIEW_PLUGIN_FILES "${DAWN_QT_PLUGIN_DIR}/webview/*.so")
    if(DAWN_WEBVIEW_PLUGIN_FILES)
        install(FILES ${DAWN_WEBVIEW_PLUGIN_FILES} DESTINATION "${CMAKE_INSTALL_DATADIR}/qt6/plugins/webview")
    endif()
    set(DAWN_HAS_QTWEBENGINE_PROCESS FALSE)
    if(EXISTS "${DAWN_QT_LIBEXEC_DIR}/QtWebEngineProcess")
        set(DAWN_HAS_QTWEBENGINE_PROCESS TRUE)
        install(PROGRAMS "${DAWN_QT_LIBEXEC_DIR}/QtWebEngineProcess" DESTINATION "${CMAKE_INSTALL_LIBEXECDIR}")
    endif()
    if(EXISTS "${DAWN_QT_DATA_DIR}/resources/qtwebengine_resources.pak")
        install(DIRECTORY "${DAWN_QT_DATA_DIR}/resources/" DESTINATION "${CMAKE_INSTALL_DATADIR}/qt6/resources")
        install(DIRECTORY "${DAWN_QT_DATA_DIR}/translations/qtwebengine_locales/"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/qt6/translations/qtwebengine_locales")
    endif()

    set(DAWN_EXTRA_EXECUTABLE_ARGS "")
    if(DAWN_HAS_QTWEBENGINE_PROCESS)
        set(DAWN_EXTRA_EXECUTABLE_ARGS "\"${CMAKE_INSTALL_LIBEXECDIR}/QtWebEngineProcess\"")
    endif()
    if(DAWN_QMLLS_EXECUTABLE)
        string(APPEND DAWN_EXTRA_EXECUTABLE_ARGS " \"${CMAKE_INSTALL_BINDIR}/qmlls\"")
    endif()
    set(DAWN_QPA_MODULE_ARGS "")
    foreach(plugin IN LISTS DAWN_QPA_PLUGIN_FILES)
        get_filename_component(plugin_name "${plugin}" NAME)
        string(APPEND DAWN_QPA_MODULE_ARGS " \"${CMAKE_INSTALL_DATADIR}/qt6/plugins/platforms/${plugin_name}\"")
    endforeach()
    foreach(plugin IN LISTS DAWN_WEBVIEW_PLUGIN_FILES)
        get_filename_component(plugin_name "${plugin}" NAME)
        string(APPEND DAWN_QPA_MODULE_ARGS " \"${CMAKE_INSTALL_DATADIR}/qt6/plugins/webview/${plugin_name}\"")
    endforeach()

    qt_generate_deploy_script(
        TARGET dawn-studio
        OUTPUT_SCRIPT deploy_extra_runtime_script
        CONTENT "
            qt_deploy_runtime_dependencies(
                EXECUTABLE \"${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:dawn-studio>\"
                ADDITIONAL_EXECUTABLES ${DAWN_EXTRA_EXECUTABLE_ARGS}
                ADDITIONAL_MODULES ${DAWN_QPA_MODULE_ARGS}
                VERBOSE
            )
        "
    )
    install(SCRIPT "${deploy_extra_runtime_script}")

    set(DAWN_QT_CONF_FILE "${CMAKE_CURRENT_BINARY_DIR}/dawn-qt.conf")
    file(WRITE "${DAWN_QT_CONF_FILE}"
        "[Paths]\nPrefix=..\nLibraries=${CMAKE_INSTALL_LIBDIR}\nPlugins=${CMAKE_INSTALL_DATADIR}/qt6/plugins\nQml2Imports=qml\nLibraryExecutables=${CMAKE_INSTALL_LIBEXECDIR}\nData=${CMAKE_INSTALL_DATADIR}/qt6\nTranslations=${CMAKE_INSTALL_DATADIR}/qt6/translations\n")
    install(FILES "${DAWN_QT_CONF_FILE}" DESTINATION "${CMAKE_INSTALL_BINDIR}" RENAME qt.conf)
    if(DAWN_PATCHELF_EXECUTABLE)
        install(CODE [[
            set(webengine_process "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/libexec/QtWebEngineProcess")
            if(EXISTS "${webengine_process}")
                execute_process(
                    COMMAND patchelf --set-rpath "$ORIGIN/../lib" "${webengine_process}"
                    COMMAND_ERROR_IS_FATAL ANY
                )
            endif()
        ]])
    endif()
elseif(DAWN_QMLLS_EXECUTABLE AND NOT ANDROID)
    if(WIN32)
        set(DAWN_QMLLS_INSTALLED_NAME "qmlls.exe")
    else()
        set(DAWN_QMLLS_INSTALLED_NAME "qmlls")
    endif()
    qt_generate_deploy_script(
        TARGET dawn-studio
        OUTPUT_SCRIPT deploy_qmlls_runtime_script
        CONTENT "qt_deploy_runtime_dependencies(EXECUTABLE \"\${QT_DEPLOY_BIN_DIR}/${DAWN_QMLLS_INSTALLED_NAME}\" VERBOSE)"
    )
    install(SCRIPT "${deploy_qmlls_runtime_script}")
endif()
