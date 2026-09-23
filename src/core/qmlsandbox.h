#ifndef QMLSANDBOX_H
#define QMLSANDBOX_H

#include <QObject>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QVariantMap>

class QmlSandbox : public QObject
{
    Q_OBJECT
public:
    explicit QmlSandbox(QQmlEngine *engine, QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap compileAndCreate(const QString &code, const QString &baseUrlStr, QQuickItem *targetParent);

private:
    QQmlEngine *m_engine = nullptr;
};

#endif // QMLSANDBOX_H