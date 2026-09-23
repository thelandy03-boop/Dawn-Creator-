#ifndef PROJECTMODEL_H
#define PROJECTMODEL_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class ProjectModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList openFiles READ openFiles NOTIFY openFilesChanged)
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(int count READ count NOTIFY openFilesChanged)

public:
    explicit ProjectModel(QObject *parent = nullptr);

    QVariantList openFiles() const;
    int currentIndex() const;
    void setCurrentIndex(int index);
    int count() const;

    Q_INVOKABLE void openFile(const QString &path, const QString &content);
    Q_INVOKABLE void closeFile(int index);
    Q_INVOKABLE void closeAll();
    Q_INVOKABLE void updateContent(int index, const QString &content);
    Q_INVOKABLE void setModified(int index, bool modified);
    Q_INVOKABLE QVariantMap fileAt(int index) const;
    Q_INVOKABLE int indexOfPath(const QString &path) const;

signals:
    void openFilesChanged();
    void currentIndexChanged();
    void currentFileChanged(const QString &path, const QString &content);

private:
    QVariantList m_openFiles;
    int m_currentIndex = -1;
};

#endif