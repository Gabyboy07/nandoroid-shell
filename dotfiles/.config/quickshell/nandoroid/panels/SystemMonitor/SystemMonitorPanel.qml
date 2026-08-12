import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"

import "pages"

/**
 * High-fidelity System Monitor Panel for NAnDoroid.
 * Features:
 * - Real-time performance graphs (CPU, RAM, Network, Disk)
 * - Process management with right-click menu
 * - GPU statistics
 * - Navigation sidebar
 */
Scope {
    id: rootScope

    FloatingWindow {
        id: panelWindow
        
        visible: GlobalStates.systemMonitorOpen
        color: "transparent"

        title: "System Monitor"

        // Default native window size
        implicitWidth: Math.min(1100 * Appearance.effectiveScale, Appearance.sizes.screen.width * 0.75)
        implicitHeight: Math.min(820 * Appearance.effectiveScale, Appearance.sizes.screen.height * 0.85)

        // Main Panel Background
        StyledRectangularShadow {
            target: root
            radius: root.radius
            color: Functions.ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.2)
        }

            Rectangle {
                id: root
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.panel
                clip: true

                property bool sidebarExpanded: true

                focus: visible
                Keys.onEscapePressed: GlobalStates.systemMonitorOpen = false

            // Stop click propagation to backdrop
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }


            // Auto-fallback if battery is removed/unavailable
            Connections {
                target: Battery
                function onAvailableChanged() {
                    if (!Battery.available && GlobalStates.systemMonitorIndex === 1) {
                        GlobalStates.systemMonitorIndex = 0;
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12 * Appearance.effectiveScale
                spacing: 12 * Appearance.effectiveScale

                // ── Global Header ──
                Item {
                    id: headerWrapper
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52 * Appearance.effectiveScale // Reduced from 64

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20 * Appearance.effectiveScale
                        anchors.rightMargin: 12 * Appearance.effectiveScale
                        spacing: 20 * Appearance.effectiveScale

                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 36 * Appearance.effectiveScale
                            implicitHeight: 36 * Appearance.effectiveScale
                            buttonRadius: 18 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: root.sidebarExpanded = !root.sidebarExpanded
                            
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.sidebarExpanded ? "menu_open" : "menu"
                                iconSize: 22 * Appearance.effectiveScale
                                color: Appearance.colors.colOnLayer0
                            }
                        }

                        Item { Layout.fillWidth: true } // Spacer

                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 36 * Appearance.effectiveScale
                            implicitHeight: 36 * Appearance.effectiveScale
                            buttonRadius: 18 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: GlobalStates.systemMonitorOpen = false
                            
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 22 * Appearance.effectiveScale
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                // ── Main Content Area (Sidebar + Pages) ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12 * Appearance.effectiveScale
                    
                    // Side Navigation (Matching SettingsSidebar style)
                    SystemMonitorSidebar {
                        expanded: root.sidebarExpanded
                    }
                
                // Main Content Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.colors.colLayer1
                    radius: 20 * Appearance.effectiveScale
                    clip: true
                    
                    Item {
                        anchors.fill: parent

                        Loader {
                            anchors.fill: parent
                            active: GlobalStates.systemMonitorIndex === 0
                            visible: active
                            asynchronous: true
                            sourceComponent: Component { PerformancePage {} }
                        }
                        Loader {
                            anchors.fill: parent
                            active: GlobalStates.systemMonitorIndex === 1 && Battery.available
                            visible: active
                            asynchronous: true
                            sourceComponent: Component { BatteryPage {} }
                        }
                        Loader {
                            anchors.fill: parent
                            active: GlobalStates.systemMonitorIndex === 2
                            visible: active
                            asynchronous: true
                            sourceComponent: Component { ProcessesPage {} }
                        }
                    }
                } // End Main Content RowLayout
            } // End Global ColumnLayout
        } // End Main Panel Background Rectangle
    } // End FloatingWindow
} // End Scope
}
