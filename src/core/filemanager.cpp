#include "filemanager.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QTextStream>
#include <QStringConverter>
#include <QProcess>

FileManager::FileManager(QObject *parent) : QObject(parent)
{
    m_currentFolder = QDir::homePath();
}

QString FileManager::currentFolder() const { return m_currentFolder; }

void FileManager::setCurrentFolder(const QString &path)
{
    QString clean = path;
    clean.remove("file://");
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
    QString clean = path;
    clean.remove("file://");

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
    QString clean = path;
    clean.remove("file://");

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
    QString clean = path;
    clean.remove("file://");
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
    QString clean = path;
    clean.remove("file://");
    return QDir().mkpath(clean);
}

bool FileManager::deletePath(const QString &path)
{
    QString clean = path;
    clean.remove("file://");
    QFileInfo info(clean);
    if (info.isDir())
        return QDir(clean).removeRecursively();
    return QFile::remove(clean);
}

bool FileManager::renamePath(const QString &oldPath, const QString &newPath)
{
    QString cleanOld = oldPath;
    cleanOld.remove("file://");
    QString cleanNew = newPath;
    cleanNew.remove("file://");

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
    QString clean = path;
    clean.remove("file://");

    QFileInfo info(clean);
    if (!info.exists() || info.isDir()) {
        emit error("El archivo no existe o es un directorio: " + clean);
        return;
    }

    QString ext = info.suffix().toLower();

    if (ext == "qml") {
        QProcess::startDetached("qml6", QStringList() << clean, info.absolutePath());
    } else if (ext == "py") {
        QProcess::startDetached("python3", QStringList() << clean, info.absolutePath());
    } else if (ext == "sh") {
        QProcess::startDetached("bash", QStringList() << clean, info.absolutePath());
    } else {
        runProject();
    }
}

void FileManager::runProject()
{
    QString root = m_currentFolder;
    root.remove("file://");

    // 1. Buscar primero un ejecutable C++ compilado en build/
    QString buildDir = root + "/build";
    QDir bDir(buildDir);
    if (bDir.exists()) {
        const auto files = bDir.entryInfoList(QDir::Files | QDir::Executable, QDir::Name);
        for (const QFileInfo &info : files) {
            if (info.isExecutable() && !info.fileName().endsWith(".sh") 
                                    && !info.fileName().endsWith(".so")
                                    && !info.fileName().contains("CMake")) {
                QProcess::startDetached(info.absoluteFilePath(), QStringList(), buildDir);
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
            QProcess::startDetached("qml6", QStringList() << qmlPath, info.absolutePath());
            return;
        }
    }

    emit error("No se encontró un ejecutable en build/ ni un archivo QML ejecutable.");
}

bool FileManager::fileExists(const QString &path)
{
    QString clean = path;
    clean.remove("file://");
    return QFile::exists(clean);
}

QVariantList FileManager::listDirectory(const QString &path)
{
    QVariantList items;
    QString clean = path;
    clean.remove("file://");
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
    QString clean = path;
    clean.remove("file://");
    return QFileInfo(clean).fileName();
}

QString FileManager::fileExtension(const QString &path)
{
    QString clean = path;
    clean.remove("file://");
    return QFileInfo(clean).suffix().toLower();
}

QString FileManager::parentDir(const QString &path)
{
    QString clean = path;
    clean.remove("file://");
    return QFileInfo(clean).absolutePath();
}