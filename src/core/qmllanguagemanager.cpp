#include "qmllanguagemanager.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QLibraryInfo>
#include <QStandardPaths>
#include <QUrl>
#include <QCoreApplication>

QmlLanguageManager::QmlLanguageManager(QObject *parent) : QObject(parent)
{
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &QmlLanguageManager::readOutput);
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        if (m_process.error() == QProcess::FailedToStart)
            setStatus(QStringLiteral("No se pudo iniciar qmlls; revisa DAWN_QMLLS_PATH y Qt 6.8+."));
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int, QProcess::ExitStatus) {
        m_initialized = false;
        if (!m_status.startsWith(QStringLiteral("qmlls no encontrado")))
            setStatus(QStringLiteral("qmlls se cerró; reinicia Dawn para volver a conectar"));
    });
}

void QmlLanguageManager::setStatus(const QString &value)
{
    if (m_status == value) return;
    m_status = value;
    emit statusChanged();
}

QString QmlLanguageManager::documentUri(const QString &path) const
{
    return QUrl::fromLocalFile(QFileInfo(path).absoluteFilePath()).toString(QUrl::FullyEncoded);
}

void QmlLanguageManager::start(const QString &workspacePath)
{
    if (m_process.state() != QProcess::NotRunning) return;
    m_workspacePath = QDir(workspacePath).absolutePath();
    m_buffer.clear();
    m_initialized = false;
    const QString bundledName =
#ifdef Q_OS_WIN
        QStringLiteral("qmlls.exe");
#else
        QStringLiteral("qmlls");
#endif
    const QString bundledServer = QCoreApplication::applicationDirPath() + QLatin1Char('/') + bundledName;
    QString executable = QFileInfo(bundledServer).isExecutable() ? bundledServer : QString();
    if (executable.isEmpty()) executable = qEnvironmentVariable("DAWN_QMLLS_PATH");
    if (executable.isEmpty()) executable = QStandardPaths::findExecutable(QStringLiteral("qmlls"));
    if (executable.isEmpty()) {
        const QString qtCandidate = QLibraryInfo::path(QLibraryInfo::BinariesPath) + QStringLiteral("/qmlls");
        if (QFileInfo::exists(qtCandidate)) executable = qtCandidate;
    }
    if (executable.isEmpty()) {
        setStatus(QStringLiteral("qmlls no encontrado. Instálalo con Qt 6.8+ o define DAWN_QMLLS_PATH."));
        return;
    }
    m_process.setProgram(executable);
    m_process.setArguments({});
    m_process.setWorkingDirectory(m_workspacePath);
    m_process.start();
    if (!m_process.waitForStarted(300)) {
        setStatus(QStringLiteral("No se pudo iniciar qmlls; revisa DAWN_QMLLS_PATH y Qt 6.8+."));
        return;
    }
    setStatus(QStringLiteral("Conectando con qmlls…"));
    QJsonObject capabilities{
        {QStringLiteral("textDocument"), QJsonObject{
            {QStringLiteral("synchronization"), QJsonObject{{QStringLiteral("didSave"), true}}},
            {QStringLiteral("completion"), QJsonObject{{QStringLiteral("completionItem"), QJsonObject{{QStringLiteral("snippetSupport"), true}}}}},
            {QStringLiteral("hover"), QJsonObject{{QStringLiteral("contentFormat"), QJsonArray{QStringLiteral("markdown"), QStringLiteral("plaintext")}}}}
        }}
    };
    QJsonObject params{
        {QStringLiteral("processId"), static_cast<qint64>(QCoreApplication::applicationPid())},
        {QStringLiteral("rootUri"), QUrl::fromLocalFile(m_workspacePath).toString(QUrl::FullyEncoded)},
        {QStringLiteral("capabilities"), capabilities},
        {QStringLiteral("workspaceFolders"), QJsonArray{QJsonObject{
            {QStringLiteral("uri"), QUrl::fromLocalFile(m_workspacePath).toString(QUrl::FullyEncoded)},
            {QStringLiteral("name"), QFileInfo(m_workspacePath).fileName()}
        }}}
    };
    m_initializeId = m_nextId++;
    sendRequest(QStringLiteral("initialize"), params, m_initializeId);
}

void QmlLanguageManager::sendMessage(const QJsonObject &message)
{
    if (m_process.state() == QProcess::NotRunning) return;
    const QByteArray body = QJsonDocument(message).toJson(QJsonDocument::Compact);
    m_process.write("Content-Length: " + QByteArray::number(body.size()) + "\r\n\r\n" + body);
}

void QmlLanguageManager::sendRequest(const QString &method, const QJsonObject &params, int id)
{
    sendMessage({{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                 {QStringLiteral("id"), id}, {QStringLiteral("method"), method},
                 {QStringLiteral("params"), params}});
}

void QmlLanguageManager::readOutput()
{
    m_buffer += m_process.readAllStandardOutput();
    while (true) {
        const int headerEnd = m_buffer.indexOf("\r\n\r\n");
        if (headerEnd < 0) return;
        int contentLength = -1;
        const QList<QByteArray> headers = m_buffer.left(headerEnd).split('\n');
        for (QByteArray header : headers) {
            header = header.trimmed();
            if (header.toLower().startsWith("content-length:"))
                contentLength = header.mid(header.indexOf(':') + 1).trimmed().toInt();
        }
        if (contentLength < 0) { m_buffer.remove(0, headerEnd + 4); continue; }
        if (m_buffer.size() < headerEnd + 4 + contentLength) return;
        const QByteArray body = m_buffer.mid(headerEnd + 4, contentLength);
        m_buffer.remove(0, headerEnd + 4 + contentLength);
        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(body, &parseError);
        if (parseError.error == QJsonParseError::NoError && doc.isObject()) handleMessage(doc.object());
    }
}

void QmlLanguageManager::handleMessage(const QJsonObject &message)
{
    if (message.contains(QStringLiteral("method"))) {
        const QString method = message.value(QStringLiteral("method")).toString();
        const QJsonObject params = message.value(QStringLiteral("params")).toObject();
        if (message.contains(QStringLiteral("id"))) {
            QJsonValue result = QJsonValue::Null;
            if (method == QStringLiteral("workspace/configuration"))
                result = QJsonArray{};
            else if (method == QStringLiteral("client/registerCapability") || method == QStringLiteral("window/workDoneProgress/create"))
                result = QJsonObject{};
            sendMessage({{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                         {QStringLiteral("id"), message.value(QStringLiteral("id"))},
                         {QStringLiteral("result"), result}});
            return;
        }
        if (method == QStringLiteral("window/logMessage") || method == QStringLiteral("window/showMessage")) {
            if (params.value(QStringLiteral("type")).toInt() >= 2)
                setStatus(params.value(QStringLiteral("message")).toString());
        }
        emit notificationReceived(method, params);
        return;
    }
    const int id = message.value(QStringLiteral("id")).toInt(-1);
    const QJsonObject error = message.value(QStringLiteral("error")).toObject();
    const QJsonValue result = message.value(QStringLiteral("result"));
    if (id == m_initializeId) {
        if (!error.isEmpty()) {
            setStatus(QStringLiteral("qmlls rechazó la inicialización: ") + error.value(QStringLiteral("message")).toString());
            return;
        }
        sendMessage({{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                     {QStringLiteral("method"), QStringLiteral("initialized")},
                     {QStringLiteral("params"), QJsonObject{}}});
        m_initialized = true;
        setStatus(QStringLiteral("qmlls conectado"));
        return;
    }
    QJsonObject resultObject;
    if (result.isObject()) resultObject = result.toObject();
    else if (result.isArray()) resultObject.insert(QStringLiteral("items"), result.toArray());
    else if (!result.isUndefined() && !result.isNull()) resultObject.insert(QStringLiteral("value"), result);
    emit responseReceived(id, resultObject, error);
}

void QmlLanguageManager::openDocument(const QString &path, const QString &text, int version)
{
    if (!m_initialized || path.isEmpty()) return;
    sendMessage({{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                 {QStringLiteral("method"), QStringLiteral("textDocument/didOpen")},
                 {QStringLiteral("params"), QJsonObject{
                    {QStringLiteral("textDocument"), QJsonObject{
                        {QStringLiteral("uri"), documentUri(path)}, {QStringLiteral("languageId"), QStringLiteral("qml")},
                        {QStringLiteral("version"), version}, {QStringLiteral("text"), text}}}}}});
}

void QmlLanguageManager::changeDocument(const QString &path, const QString &text, int version)
{
    if (!m_initialized || path.isEmpty()) return;
    sendMessage({{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                 {QStringLiteral("method"), QStringLiteral("textDocument/didChange")},
                 {QStringLiteral("params"), QJsonObject{
                    {QStringLiteral("textDocument"), QJsonObject{{QStringLiteral("uri"), documentUri(path)}, {QStringLiteral("version"), version}}},
                    {QStringLiteral("contentChanges"), QJsonArray{QJsonObject{{QStringLiteral("text"), text}}}}}}});
}

void QmlLanguageManager::closeDocument(const QString &path)
{
    if (!m_initialized || path.isEmpty()) return;
    sendMessage({{QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
                 {QStringLiteral("method"), QStringLiteral("textDocument/didClose")},
                 {QStringLiteral("params"), QJsonObject{{QStringLiteral("textDocument"), QJsonObject{{QStringLiteral("uri"), documentUri(path)}}}}}});
}

void QmlLanguageManager::requestCompletion(const QString &path, int line, int character, int requestId)
{
    if (!m_initialized) return;
    sendRequest(QStringLiteral("textDocument/completion"), QJsonObject{
        {QStringLiteral("textDocument"), QJsonObject{{QStringLiteral("uri"), documentUri(path)}}},
        {QStringLiteral("position"), QJsonObject{{QStringLiteral("line"), line}, {QStringLiteral("character"), character}}}}, requestId);
}

void QmlLanguageManager::requestHover(const QString &path, int line, int character, int requestId)
{
    if (!m_initialized) return;
    sendRequest(QStringLiteral("textDocument/hover"), QJsonObject{
        {QStringLiteral("textDocument"), QJsonObject{{QStringLiteral("uri"), documentUri(path)}}},
        {QStringLiteral("position"), QJsonObject{{QStringLiteral("line"), line}, {QStringLiteral("character"), character}}}}, requestId);
}
