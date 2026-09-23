#ifndef PLUGINMANAGER_H
#define PLUGINMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QString>

class PluginManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList availablePlugins READ availablePlugins NOTIFY pluginsChanged)

public:
    explicit PluginManager(QObject *parent = nullptr);
    QVariantList availablePlugins() const;
    Q_INVOKABLE void loadPlugins(const QString &path);

signals:
    void pluginsChanged();

private:
    QVariantList m_plugins;
};
#endif
