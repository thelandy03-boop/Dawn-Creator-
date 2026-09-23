#ifndef FILEMANAGER_H
#define FILEMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class FileManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentFolder READ currentFolder WRITE setCurrentFolder NOTIFY currentFolderChanged)
    Q_PROPERTY(QString projectName READ projectName NOTIFY currentFolderChanged)

public:
    explicit FileManager(QObject *parent = nullptr);

    QString currentFolder() const;
    void setCurrentFolder(const QString &path);
    QString projectName() const;

    Q_INVOKABLE QString readFile(const QString &path);
    Q_INVOKABLE bool writeFile(const QString &path, const QString &content);
    Q_INVOKABLE bool createFile(const QString &path);
    Q_INVOKABLE bool createFolder(const QString &path);
    Q_INVOKABLE bool deletePath(const QString &path);
    Q_INVOKABLE bool renamePath(const QString &oldPath, const QString &newPath);
    Q_INVOKABLE void runFile(const QString &path);
    Q_INVOKABLE void runProject();
    Q_INVOKABLE bool fileExists(const QString &path);
    Q_INVOKABLE QVariantList listDirectory(const QString &path);
    Q_INVOKABLE QString fileName(const QString &path);
    Q_INVOKABLE QString fileExtension(const QString &path);
    Q_INVOKABLE QString parentDir(const QString &path);

signals:
    void currentFolderChanged();
    void error(const QString &message);
    void fileOpened(const QString &path, const QString &content);
    void fileSaved(const QString &path);

private:
    QString m_currentFolder;
};

#endif // FILEMANAGER_H