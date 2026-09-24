#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDir>
#include <QtWebView/QtWebView>
#include "../core/pluginmanager.h"
#include "../core/filemanager.h"
#include "../core/projectmodel.h"
#include "../core/terminalmanager.h"
#include "../core/qmlsandbox.h"
#include "../core/qmllanguagemanager.h"
#include "../core/webassetmanager.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QtWebView::initialize();

    QGuiApplication app(argc, argv);
    app.setOrganizationName("Dawn");
    app.setApplicationName("Dawn Studio");
    app.setApplicationVersion(QStringLiteral(DAWN_APP_VERSION));
    QQuickStyle::setStyle("Basic");

    PluginManager pluginManager;
    FileManager fileManager;
    ProjectModel projectModel;
    TerminalManager terminalManager;
    QmlLanguageManager qmlLanguageManager;
    WebAssetManager webAssetManager;

    QQmlApplicationEngine engine;
    QmlSandbox qmlSandbox(&engine);

    QString currentPath = QDir::currentPath();
    if (currentPath.endsWith("/build")) {
        currentPath = QDir(currentPath + "/..").absolutePath();
    }

    QString pluginPath = currentPath + "/plugins";
    pluginManager.loadPlugins(pluginPath);

    fileManager.setCurrentFolder(currentPath);
    terminalManager.startShell(fileManager.currentFolder());

    engine.rootContext()->setContextProperty("PluginManager", &pluginManager);
    engine.rootContext()->setContextProperty("FileManager", &fileManager);
    engine.rootContext()->setContextProperty("ProjectModel", &projectModel);
    engine.rootContext()->setContextProperty("TerminalManager", &terminalManager);
    engine.rootContext()->setContextProperty("QmlSandbox", &qmlSandbox);
    engine.rootContext()->setContextProperty("QmlLanguageManager", &qmlLanguageManager);
    engine.rootContext()->setContextProperty("WebAssets", &webAssetManager);
    engine.rootContext()->setContextProperty("AppVersion", app.applicationVersion());

    engine.addImportPath("qrc:/qt/qml");
    const QUrl url(QStringLiteral("qrc:/qt/qml/DawnStudio/src/qml/Main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    engine.load(url);
    return app.exec();
}
