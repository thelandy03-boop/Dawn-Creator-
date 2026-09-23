# Dawn Studio

Dawn Studio is a Qt 6 / QML workspace for editing QML interfaces and previewing plugins.

## Editor bundle

The code editor uses CodeMirror 6. Its dependencies are bundled locally, so Node.js is only needed when changing the editor or its extensions; the built Dawn Studio app does not download editor code at runtime.

To rebuild the bundle after changing `src/qml/editor/codemirror6-entry.js`:

```sh
cd src/qml/editor
npm ci
npm run build
```

The generated `codemirror6.bundle.js` is included as a Qt resource. Third-party license notices are in `src/qml/editor/THIRD_PARTY_NOTICES.md`.

## QML language support

Dawn connects the editor to Qt's `qmlls` language server for QML diagnostics, code completion, and hover documentation. The server is optional: the editor shows its connection state in the status bar and keeps syntax highlighting available when it is missing.

Build Dawn with a redistributable Qt 6.8 SDK. CMake rejects other Qt minor versions and its install step deploys Qt's runtime libraries and imported QML modules beside the app, so end users do not need to install Qt separately. Create the distributable folder with `cmake --install build --prefix dist` after a Release build, then package that folder for the target desktop OS. The Qt SDK used to create releases must support relocatable deployment; some Linux distribution Qt packages are intended only for system installation and cannot be bundled by this step.

`qmlls` is a separate development tool. The packager can include it with `-DDAWN_QMLLS_EXECUTABLE=/path/to/qmlls`; Dawn then uses the bundled copy and deploys its Qt runtime dependencies. If it is not bundled, install Qt 6.8's QML Language Server or set `DAWN_QMLLS_PATH`. This repository currently targets Linux desktop; Windows, macOS, Android, and iOS need their own builds and packaging workflows before those users can install Dawn.
