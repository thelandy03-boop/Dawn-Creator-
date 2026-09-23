#include "pluginmanager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

PluginManager::PluginManager(QObject *parent) : QObject(parent) {}

QVariantList PluginManager::availablePlugins() const { return m_plugins; }

void PluginManager::loadPlugins(const QString &path) {
    m_plugins.clear();
    QDir dir(path);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    for (const QString &folder : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile file(dir.absoluteFilePath(folder + "/manifest.json"));
        if (file.open(QIODevice::ReadOnly)) {
            QJsonObject obj = QJsonDocument::fromJson(file.readAll()).object();
            QVariantMap plugin;
            plugin["name"] = obj["name"].toString();
            plugin["description"] = obj["description"].toString();
            plugin["version"] = obj["version"].toString();
            plugin["entryPoint"] = dir.absoluteFilePath(folder + "/" + obj["entryPoint"].toString());
            m_plugins.append(plugin);
        }
    }
    emit pluginsChanged();
}
