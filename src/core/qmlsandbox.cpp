#include "qmlsandbox.h"
#include "filemanager.h"
#include "projectmodel.h"
#include "terminalmanager.h"
#include "pluginmanager.h"

#include <QQmlComponent>
#include <QQuickItem>
#include <QRegularExpression>
#include <QDebug>

QmlSandbox::QmlSandbox(QQmlEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine)
{
}

QVariantMap QmlSandbox::compileAndCreate(const QString &rawCode, const QString &baseUrlStr, QQuickItem *targetParent)
{
    QVariantMap resultMap;
    resultMap["item"] = QVariant::fromValue<QQuickItem*>(nullptr);
    resultMap["rootObj"] = QVariant::fromValue<QObject*>(nullptr);
    resultMap["error"] = "";

    if (!m_engine || !targetParent) {
        resultMap["error"] = QStringLiteral("Motor o contenedor no válido.");
        return resultMap;
    }

    // 1. Limpieza de elementos gráficos previos
    const auto oldChildren = targetParent->childItems();
    for (QQuickItem *child : oldChildren) {
        child->setParentItem(nullptr);
        child->deleteLater();
    }

    // 2. Limpieza de la caché de componentes de Qt
    m_engine->clearComponentCache();

    QString code = rawCode.trimmed();
    if (code.isEmpty()) {
        resultMap["error"] = QStringLiteral("Código vacío.");
        return resultMap;
    }

    bool isWindow = code.contains("ApplicationWindow") || code.contains("Window");

    // Transformación precisa de ApplicationWindow / Window a Rectangle
    static QRegularExpression appWinWithBrace(R"(ApplicationWindow\s*\{)");
    static QRegularExpression winWithBrace(R"(Window\s*\{)");
    static QRegularExpression appWinRegex(R"(ApplicationWindow\b)");
    static QRegularExpression winRegex(R"(Window\b)");

    QString dummyProps = "Rectangle {\n"
                         "    property var title\n"
                         "    property var minimumWidth\n"
                         "    property var minimumHeight\n"
                         "    property var maximumWidth\n"
                         "    property var maximumHeight\n"
                         "    property var menuBar\n"
                         "    property var header\n"
                         "    property var footer\n";

    if (code.contains(appWinWithBrace)) {
        code.replace(appWinWithBrace, dummyProps);
    } else {
        code.replace(appWinRegex, QStringLiteral("Rectangle"));
    }

    if (code.contains(winWithBrace)) {
        code.replace(winWithBrace, dummyProps);
    } else {
        code.replace(winRegex, QStringLiteral("Rectangle"));
    }

    QQmlContext *sandboxContext = new QQmlContext(m_engine->rootContext());
    sandboxContext->setContextProperty(QStringLiteral("isSandbox"), true);

    QUrl baseUrl(baseUrlStr.isEmpty() ? QStringLiteral("qrc:/qt/qml/DawnStudio/src/qml/LiveDynamic.qml") : baseUrlStr);
    QQmlComponent component(m_engine);
    component.setData(code.toUtf8(), baseUrl);

    if (component.isError()) {
        resultMap["error"] = component.errorString();
        delete sandboxContext;
        return resultMap;
    }

    QObject *createdObj = component.create(sandboxContext);
    if (!createdObj) {
        resultMap["error"] = QStringLiteral("No se pudo instanciar el objeto QML.");
        delete sandboxContext;
        return resultMap;
    }

    sandboxContext->setParent(createdObj);

    QQuickItem *resultItem = qobject_cast<QQuickItem*>(createdObj);
    if (!resultItem) {
        resultMap["error"] = QStringLiteral("El elemento raíz no es un componente visual válido.");
        delete createdObj;
        return resultMap;
    }

    resultItem->setParentItem(targetParent);

    if (isWindow) {
        // En modo Proyecto (Main.qml), la UI ocupa el 100% del panel lateral sin escala diminuta
        resultItem->setWidth(targetParent->width());
        resultItem->setHeight(targetParent->height());
        resultItem->setScale(1.0);
        resultItem->setX(0);
        resultItem->setY(0);
    } else {
        // En modo Archivo (componentes sueltos como AppTopBar), escala proporcionalmente si es más ancho
        qreal itemW = (resultItem->implicitWidth() > 0) ? resultItem->implicitWidth() : resultItem->width();
        qreal itemH = (resultItem->implicitHeight() > 0) ? resultItem->implicitHeight() : resultItem->height();

        if (itemW <= 0) itemW = 680;
        if (itemH <= 0) itemH = targetParent->height();

        resultItem->setWidth(itemW);
        resultItem->setHeight(itemH);

        qreal parentW = targetParent->width();
        if (parentW > 0 && itemW > parentW) {
            qreal scaleFactor = parentW / itemW;
            resultItem->setScale(scaleFactor);
            resultItem->setTransformOrigin(QQuickItem::TopLeft);
            resultItem->setX(0);
            resultItem->setY(0);
        } else {
            resultItem->setScale(1.0);
            resultItem->setX(0);
            resultItem->setY(0);
        }
    }

    resultMap["item"] = QVariant::fromValue<QQuickItem*>(resultItem);
    resultMap["rootObj"] = QVariant::fromValue<QObject*>(createdObj);
    return resultMap;
}