#include "terminalmanager.h"
#include <QDebug>
#include <QDir>
#include <pty.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <cstdlib>

TerminalManager::TerminalManager(QObject *parent)
    : QObject(parent)
{
    m_currentDir = QDir::homePath();
}

TerminalManager::~TerminalManager()
{
    stopShell();
}

void TerminalManager::setCurrentDir(const QString &dir)
{
    if (m_currentDir != dir) {
        m_currentDir = dir;
        emit currentDirChanged(m_currentDir);
    }
}

void TerminalManager::startShell(const QString &workingDir)
{
    if (m_running) {
        return;
    }

    QString targetDir = workingDir.isEmpty() ? m_currentDir : workingDir;
    if (!QDir(targetDir).exists()) {
        targetDir = QDir::homePath();
    }

    struct winsize ws;
    ws.ws_col = 80;
    ws.ws_row = 24;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;

    m_childPid = forkpty(&m_masterFd, nullptr, nullptr, &ws);

    if (m_childPid < 0) {
        qWarning() << "[TerminalManager] forkpty falló:" << strerror(errno);
        return;
    }

    if (m_childPid == 0) {
        // PROCESO HIJO
        chdir(targetDir.toUtf8().constData());

        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);
        setenv("LANG", "C.UTF-8", 1);
        setenv("LC_ALL", "C.UTF-8", 1);

        const char *shell = getenv("SHELL");
        if (!shell || access(shell, X_OK) != 0) {
            shell = "/bin/bash";
            if (access(shell, X_OK) != 0) {
                shell = "/bin/sh";
            }
        }

        execlp(shell, shell, "-i", nullptr);
        _exit(1);
    }

    // PROCESO PADRE
    int flags = fcntl(m_masterFd, F_GETFL, 0);
    fcntl(m_masterFd, F_SETFL, flags | O_NONBLOCK);

    m_notifier = new QSocketNotifier(m_masterFd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &TerminalManager::onReadyRead);

    m_running = true;
    emit runningChanged(m_running);
    qDebug() << "[TerminalManager] Shell PTY iniciado (PID:" << m_childPid << ") en" << targetDir;
}

void TerminalManager::stopShell()
{
    if (!m_running) return;

    if (m_childPid > 0) {
        kill(m_childPid, SIGHUP);
        int status;
        waitpid(m_childPid, &status, WNOHANG);
        m_childPid = -1;
    }

    cleanup();
}

void TerminalManager::cleanup()
{
    if (m_notifier) {
        m_notifier->setEnabled(false);
        m_notifier->deleteLater();
        m_notifier = nullptr;
    }

    if (m_masterFd >= 0) {
        close(m_masterFd);
        m_masterFd = -1;
    }

    if (m_running) {
        m_running = false;
        emit runningChanged(false);
        qDebug() << "[TerminalManager] Shell PTY cerrado.";
    }
}

void TerminalManager::onReadyRead()
{
    if (m_masterFd < 0) return;

    char buffer[4096];
    while (true) {
        ssize_t bytesRead = ::read(m_masterFd, buffer, sizeof(buffer));
        if (bytesRead > 0) {
            QByteArray data(buffer, static_cast<int>(bytesRead));
            emit dataReceived(QString::fromLatin1(data.toBase64()));
        } else {
            if (bytesRead < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                break; // No hay más datos por ahora
            }
            // EOF o error del proceso
            cleanup();
            break;
        }
    }
}

void TerminalManager::sendInput(const QString &text)
{
    if (m_masterFd < 0) return;
    QByteArray raw = text.toUtf8();
    ::write(m_masterFd, raw.constData(), raw.size());
}

void TerminalManager::sendInputB64(const QString &b64)
{
    if (m_masterFd < 0) return;
    QByteArray raw = QByteArray::fromBase64(b64.toLatin1());
    ::write(m_masterFd, raw.constData(), raw.size());
}

void TerminalManager::resizePty(int cols, int rows)
{
    if (m_masterFd < 0) return;
    struct winsize ws;
    ws.ws_col = static_cast<unsigned short>(cols);
    ws.ws_row = static_cast<unsigned short>(rows);
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;
    ioctl(m_masterFd, TIOCSWINSZ, &ws);
}

void TerminalManager::interrupt()
{
    if (m_masterFd >= 0) {
        char c = 0x03; // Ctrl+C
        ::write(m_masterFd, &c, 1);
    }
}