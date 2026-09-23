#pragma once

#include <QObject>
#include <QProcess>
#include <QByteArray>
#include <QJsonObject>
#include <QString>

class QmlLanguageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public:
    explicit QmlLanguageManager(QObject *parent = nullptr);
    QString status() const { return m_status; }

    Q_INVOKABLE void start(const QString &workspacePath);
    Q_INVOKABLE void openDocument(const QString &path, const QString &text, int version);
    Q_INVOKABLE void changeDocument(const QString &path, const QString &text, int version);
    Q_INVOKABLE void closeDocument(const QString &path);
    Q_INVOKABLE void requestCompletion(const QString &path, int line, int character, int requestId);
    Q_INVOKABLE void requestHover(const QString &path, int line, int character, int requestId);

signals:
    void statusChanged();
    void notificationReceived(const QString &method, const QJsonObject &params);
    void responseReceived(int requestId, const QJsonObject &result, const QJsonObject &error);

private:
    void setStatus(const QString &status);
    void sendMessage(const QJsonObject &message);
    void sendRequest(const QString &method, const QJsonObject &params, int id);
    void readOutput();
    void handleMessage(const QJsonObject &message);
    QString documentUri(const QString &path) const;

    QProcess m_process;
    QByteArray m_buffer;
    QString m_status = QStringLiteral("qmlls no iniciado");
    int m_nextId = 1;
    int m_initializeId = -1;
    bool m_initialized = false;
    QString m_workspacePath;
};
