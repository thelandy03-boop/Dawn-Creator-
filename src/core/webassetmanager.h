#pragma once

#include <QObject>
#include <QUrl>

class WebAssetManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl editorUrl READ editorUrl CONSTANT)
    Q_PROPERTY(QUrl terminalUrl READ terminalUrl CONSTANT)

public:
    explicit WebAssetManager(QObject *parent = nullptr);
    QUrl editorUrl() const { return m_editorUrl; }
    QUrl terminalUrl() const { return m_terminalUrl; }

private:
    QUrl m_editorUrl;
    QUrl m_terminalUrl;
};
