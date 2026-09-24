#include "webassetmanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLoggingCategory>
#include <QCoreApplication>
#include <QSaveFile>
#include <QStandardPaths>

namespace {
bool copyResource(const QString &resourcePath, const QString &destinationPath)
{
    QFile source(resourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        qWarning() << "Could not read bundled web asset:" << resourcePath;
        return false;
    }

    const QFileInfo existing(destinationPath);
    if (existing.isFile() && existing.size() == source.size())
        return true;

    QSaveFile destination(destinationPath);
    const QByteArray contents = source.readAll();
    if (!destination.open(QIODevice::WriteOnly)
        || destination.write(contents) != contents.size()
        || !destination.commit()) {
        qWarning() << "Could not install web asset:" << destinationPath
                   << destination.errorString();
        return false;
    }
    return true;
}
}

WebAssetManager::WebAssetManager(QObject *parent)
    : QObject(parent)
{
    const QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const QString versionDirectory = QStringLiteral("/web/")
        + QCoreApplication::applicationVersion();
    const QString editorPath = dataPath + versionDirectory + QStringLiteral("/editor");
    const QString terminalPath = dataPath + versionDirectory + QStringLiteral("/terminal");
    if (!QDir().mkpath(editorPath) || !QDir().mkpath(terminalPath)) {
        qWarning() << "Could not create private web asset directories under" << dataPath;
        return;
    }

    const bool editorReady = copyResource(
        QStringLiteral(":/qt/qml/DawnStudio/src/qml/editor/editor.html"),
        editorPath + QStringLiteral("/editor.html"))
        && copyResource(QStringLiteral(":/qt/qml/DawnStudio/src/qml/editor/codemirror6.bundle.js"),
                        editorPath + QStringLiteral("/codemirror6.bundle.js"));
    const bool terminalReady = copyResource(
        QStringLiteral(":/qt/qml/DawnStudio/src/qml/terminal/terminal.html"),
        terminalPath + QStringLiteral("/terminal.html"))
        && copyResource(QStringLiteral(":/qt/qml/DawnStudio/src/qml/terminal/xterm.js"),
                        terminalPath + QStringLiteral("/xterm.js"))
        && copyResource(QStringLiteral(":/qt/qml/DawnStudio/src/qml/terminal/xterm.css"),
                        terminalPath + QStringLiteral("/xterm.css"));

    if (editorReady)
        m_editorUrl = QUrl::fromLocalFile(editorPath + QStringLiteral("/editor.html"));
    if (terminalReady)
        m_terminalUrl = QUrl::fromLocalFile(terminalPath + QStringLiteral("/terminal.html"));
}
