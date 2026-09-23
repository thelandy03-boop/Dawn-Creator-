#include "projectmodel.h"
#include <QFileInfo>

ProjectModel::ProjectModel(QObject *parent) : QObject(parent) {}

QVariantList ProjectModel::openFiles() const { return m_openFiles; }
int ProjectModel::currentIndex() const { return m_currentIndex; }
int ProjectModel::count() const { return m_openFiles.size(); }

void ProjectModel::setCurrentIndex(int index)
{
    if (index < -1 || index >= m_openFiles.size()) return;
    if (m_currentIndex == index) return;
    m_currentIndex = index;
    emit currentIndexChanged();

    if (m_currentIndex >= 0) {
        QVariantMap f = m_openFiles[m_currentIndex].toMap();
        emit currentFileChanged(f["path"].toString(), f["content"].toString());
    }
}

void ProjectModel::openFile(const QString &path, const QString &content)
{
    // Si ya está abierto, solo activarlo
    int existing = indexOfPath(path);
    if (existing >= 0) {
        setCurrentIndex(existing);
        return;
    }

    QFileInfo info(path);
    QVariantMap file;
    file["path"] = path;
    file["name"] = info.fileName();
    file["content"] = content;
    file["modified"] = false;
    file["extension"] = info.suffix().toLower();

    m_openFiles.append(file);
    emit openFilesChanged();
    setCurrentIndex(m_openFiles.size() - 1);
}

void ProjectModel::closeFile(int index)
{
    if (index < 0 || index >= m_openFiles.size()) return;
    m_openFiles.removeAt(index);
    emit openFilesChanged();

    if (m_openFiles.isEmpty()) {
        m_currentIndex = -1;
        emit currentIndexChanged();
        return;
    }

    if (m_currentIndex >= m_openFiles.size())
        setCurrentIndex(m_openFiles.size() - 1);
    else
        emit currentIndexChanged();
}

void ProjectModel::closeAll()
{
    m_openFiles.clear();
    m_currentIndex = -1;
    emit openFilesChanged();
    emit currentIndexChanged();
}

void ProjectModel::updateContent(int index, const QString &content)
{
    if (index < 0 || index >= m_openFiles.size()) return;
    QVariantMap file = m_openFiles[index].toMap();
    file["content"] = content;
    file["modified"] = true;
    m_openFiles[index] = file;
    emit openFilesChanged();
}

void ProjectModel::setModified(int index, bool modified)
{
    if (index < 0 || index >= m_openFiles.size()) return;
    QVariantMap file = m_openFiles[index].toMap();
    file["modified"] = modified;
    m_openFiles[index] = file;
    emit openFilesChanged();
}

QVariantMap ProjectModel::fileAt(int index) const
{
    if (index < 0 || index >= m_openFiles.size()) return {};
    return m_openFiles[index].toMap();
}

int ProjectModel::indexOfPath(const QString &path) const
{
    for (int i = 0; i < m_openFiles.size(); ++i) {
        if (m_openFiles[i].toMap()["path"].toString() == path)
            return i;
    }
    return -1;
}