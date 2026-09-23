#pragma once

#include <QObject>
#include <QString>
#include <QSocketNotifier>
#include <sys/types.h>

class TerminalManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(QString currentDir READ currentDir WRITE setCurrentDir NOTIFY currentDirChanged)

public:
    explicit TerminalManager(QObject *parent = nullptr);
    ~TerminalManager() override;

    bool isRunning() const { return m_running; }
    QString currentDir() const { return m_currentDir; }
    void setCurrentDir(const QString &dir);

public slots:
    void startShell(const QString &workingDir = QString());
    void stopShell();
    void sendInput(const QString &text);
    void sendInputB64(const QString &b64);
    void resizePty(int cols, int rows);
    void interrupt();

signals:
    void dataReceived(const QString &b64Data);
    void runningChanged(bool running);
    void currentDirChanged(const QString &dir);

private slots:
    void onReadyRead();

private:
    void cleanup();

    int m_masterFd = -1;
    pid_t m_childPid = -1;
    QSocketNotifier *m_notifier = nullptr;
    bool m_running = false;
    QString m_currentDir;
};