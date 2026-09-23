#include "filemanager.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QTextStream>
#include <QStringConverter>
#include <QProcess>
#include <QUrl>
#include <QGuiApplication>
#include <QClipboard>

FileManager::FileManager(QObject *parent) : QObject(parent)
{
    m_currentFolder = QDir::homePath();
}

QString FileManager::currentFolder() const { return m_currentFolder; }

QString FileManager::cleanPath(const QString &path)
{
    const QUrl url(path);
    return url.isLocalFile() ? url.toLocalFile() : path;
}

QString FileManager::localFilePath(const QString &path) const
{
    return cleanPath(path);
}

QString FileManager::localFileUrl(const QString &path) const
{
    return QUrl::fromLocalFile(cleanPath(path)).toString();
}

void FileManager::setCurrentFolder(const QString &path)
{
    const QString clean = cleanPath(path);
    if (m_currentFolder == clean) return;
    m_currentFolder = clean;
    emit currentFolderChanged();
}

QString FileManager::projectName() const
{
    if (m_currentFolder.isEmpty()) return "Dawn Studio";
    return QFileInfo(m_currentFolder).fileName();
}

QString FileManager::readFile(const QString &path)
{
    const QString clean = cleanPath(path);

    QFile file(clean);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit error("No se pudo abrir: " + clean);
        return QString();
    }

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    file.close();

    emit fileOpened(clean, content);
    return content;
}

bool FileManager::writeFile(const QString &path, const QString &content)
{
    const QString clean = cleanPath(path);

    QFile file(clean);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit error("No se pudo guardar: " + clean);
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << content;
    file.close();

    emit fileSaved(clean);
    return true;
}

bool FileManager::createFile(const QString &path)
{
    const QString clean = cleanPath(path);
    if (QFile::exists(clean)) {
        emit error("Ya existe: " + clean);
        return false;
    }
    QFile file(clean);
    if (!file.open(QIODevice::WriteOnly)) {
        emit error("No se pudo crear: " + clean);
        return false;
    }
    file.close();
    return true;
}

bool FileManager::createFolder(const QString &path)
{
    const QString clean = cleanPath(path);
    return QDir().mkpath(clean);
}

bool FileManager::deletePath(const QString &path)
{
    const QString clean = cleanPath(path);
    QFileInfo info(clean);
    if (info.isDir())
        return QDir(clean).removeRecursively();
    return QFile::remove(clean);
}

bool FileManager::renamePath(const QString &oldPath, const QString &newPath)
{
    const QString cleanOld = cleanPath(oldPath);
    const QString cleanNew = cleanPath(newPath);

    QFileInfo info(cleanOld);
    if (!info.exists()) {
        emit error("No existe el archivo o carpeta de origen.");
        return false;
    }

    if (QFile::exists(cleanNew)) {
        emit error("El nombre o ruta de destino ya existe.");
        return false;
    }

    bool success = QFile::rename(cleanOld, cleanNew);
    if (!success) {
        emit error("Error al renombrar o mover el elemento.");
    }
    return success;
}

void FileManager::runFile(const QString &path)
{
    const QString clean = cleanPath(path);

    QFileInfo info(clean);
    if (!info.exists() || info.isDir()) {
        emit error("El archivo no existe o es un directorio: " + clean);
        return;
    }

    QString ext = info.suffix().toLower();

    if (ext == "qml") {
        if (!QProcess::startDetached("qml6", QStringList() << clean, info.absolutePath()))
            emit error("No se pudo iniciar qml6. Comprueba que Qt 6 esté instalado y disponible en PATH.");
    } else if (ext == "py") {
        if (!QProcess::startDetached("python3", QStringList() << clean, info.absolutePath()))
            emit error("No se pudo iniciar python3. Comprueba que Python esté instalado y disponible en PATH.");
    } else if (ext == "sh") {
        if (!QProcess::startDetached("bash", QStringList() << clean, info.absolutePath()))
            emit error("No se pudo iniciar bash. Comprueba que Bash esté instalado y disponible en PATH.");
    } else {
        runProject();
    }
}

void FileManager::runProject()
{
    const QString root = cleanPath(m_currentFolder);

    // 1. Buscar primero un ejecutable C++ compilado en build/
    QString buildDir = root + "/build";
    QDir bDir(buildDir);
    if (bDir.exists()) {
        const auto files = bDir.entryInfoList(QDir::Files | QDir::Executable, QDir::Name);
        for (const QFileInfo &info : files) {
            if (info.isExecutable() && !info.fileName().endsWith(".sh") 
                                    && !info.fileName().endsWith(".so")
                                    && !info.fileName().contains("CMake")) {
                if (!QProcess::startDetached(info.absoluteFilePath(), QStringList(), buildDir))
                    emit error("No se pudo iniciar el ejecutable: " + info.absoluteFilePath());
                return;
            }
        }
    }

    // 2. Si es un proyecto CMake sin compilar, solicitar build
    if (QFile::exists(root + "/CMakeLists.txt")) {
        emit error("Proyecto CMake detectado. Compila primero con 'make' en la carpeta build.");
        return;
    }

    // 3. Si es un proyecto puro de UI QML (sin C++), buscar Main.qml
    QStringList qmlMains = {
        root + "/Main.qml",
        root + "/main.qml",
        root + "/src/qml/Main.qml"
    };

    for (const QString &qmlPath : qmlMains) {
        if (QFile::exists(qmlPath)) {
            QFileInfo info(qmlPath);
            if (!QProcess::startDetached("qml6", QStringList() << qmlPath, info.absolutePath()))
                emit error("No se pudo iniciar qml6. Comprueba que Qt 6 esté instalado y disponible en PATH.");
            return;
        }
    }

    emit error("No se encontró un ejecutable en build/ ni un archivo QML ejecutable.");
}

bool FileManager::fileExists(const QString &path)
{
    const QString clean = cleanPath(path);
    return QFile::exists(clean);
}

QVariantList FileManager::listDirectory(const QString &path)
{
    QVariantList items;
    const QString clean = cleanPath(path);
    QDir dir(clean);
    if (!dir.exists()) return items;

    const auto dirs = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &info : dirs) {
        QVariantMap item;
        item["name"] = info.fileName();
        item["path"] = info.absoluteFilePath();
        item["isDir"] = true;
        item["extension"] = "";
        items.append(item);
    }

    const auto files = dir.entryInfoList(QDir::Files, QDir::Name);
    for (const QFileInfo &info : files) {
        QVariantMap item;
        item["name"] = info.fileName();
        item["path"] = info.absoluteFilePath();
        item["isDir"] = false;
        item["extension"] = info.suffix().toLower();
        items.append(item);
    }
    return items;
}

QString FileManager::fileName(const QString &path)
{
    const QString clean = cleanPath(path);
    return QFileInfo(clean).fileName();
}

QString FileManager::fileExtension(const QString &path)
{
    const QString clean = cleanPath(path);
    return QFileInfo(clean).suffix().toLower();
}

QString FileManager::parentDir(const QString &path)
{
    const QString clean = cleanPath(path);
    return QFileInfo(clean).absolutePath();
}

QString FileManager::clipboardTextB64() const
{
    const QString text = QGuiApplication::clipboard()->text(QClipboard::Clipboard);
    return QString::fromLatin1(text.toUtf8().toBase64());
}
