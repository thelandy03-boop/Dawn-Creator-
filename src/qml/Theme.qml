pragma Singleton
import QtQuick

QtObject {
    // Carcasa / chrome
    readonly property color bgHardware:  "#1a1c1e"
    readonly property color bgBar:       "#222528"
    readonly property color bgTab:       "#2a2e32"
    readonly property color bgTabActive: "#131416"
    readonly property color screenBg:    "#0d0e10"

    // Botones 3D
    readonly property color btnTop:      "#3a3e44"
    readonly property color btnBottom:   "#25282c"
    readonly property color btnPressed:  "#15171a"

    // Bordes
    readonly property color borderDark:  "#0a0a0b"
    readonly property color borderLight: "#4a4e54"
    readonly property color borderTab:   "#3d9eff"

    // Texto
    readonly property color text:        "#e0e0e0"
    readonly property color textActive:  "#ffffff"
    readonly property color textMuted:   "#7a8088"
    readonly property color textDim:     "#9aa0a6"

    // Acentos AIDE-style
    readonly property color accent:      "#3d9eff"
    readonly property color accent2:     "#7cb3ff"
    readonly property color ledGreen:    "#5cde7a"
    readonly property color yellow:      "#f0c674"
    readonly property color orange:      "#e89c3c"
    readonly property color red:         "#e06c75"
    readonly property color purple:      "#cba6f7"

    readonly property int radius: 4
    readonly property int barHeight: 44
    readonly property int tabHeight: 36
}
