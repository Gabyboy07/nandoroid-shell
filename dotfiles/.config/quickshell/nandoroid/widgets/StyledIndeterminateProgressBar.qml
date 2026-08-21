import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls
import "../core"

ProgressBar {
    id: root
    
    // Allows customizing the accent color, defaults to primary color
    property color barColor: Appearance.m3colors.m3primary
    
    // Control running/visible state
    property bool running: true
    
    visible: running
    indeterminate: running
    Material.accent: barColor
}
