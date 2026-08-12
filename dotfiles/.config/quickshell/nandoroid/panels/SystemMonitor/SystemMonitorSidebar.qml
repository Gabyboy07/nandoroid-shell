import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"

Rectangle {
    id: root
    
    property bool expanded: true
    
    Layout.fillHeight: true
    Layout.preferredWidth: expanded ? (220 * Appearance.effectiveScale) : (80 * Appearance.effectiveScale)
    Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Layout.fillWidth: false
    color: Appearance.colors.colLayer0
    radius: 20 * Appearance.effectiveScale
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12 * Appearance.effectiveScale
        spacing: 16 * Appearance.effectiveScale
        
        // Navigation Items
        Item {
            id: navItemsWrapper
            Layout.fillWidth: true
            implicitHeight: navItemsColumn.implicitHeight

            ColumnLayout {
                id: navItemsColumn
                anchors.fill: parent
                spacing: 8 * Appearance.effectiveScale
                
                Repeater {
                    model: [
                        { name: I18nService.tr("Performance"), icon: "monitoring", stackIndex: 0 },
                        { name: I18nService.tr("Battery"), icon: "battery_charging_full", stackIndex: 1, visible: Battery.available },
                        { name: I18nService.tr("Processes"), icon: "list", stackIndex: 2 }
                    ]
                    
                    delegate: MouseArea {
                        id: navBtn
                        visible: modelData.visible !== false
                        Layout.fillWidth: true
                        implicitHeight: root.expanded ? 56 * Appearance.effectiveScale : 64 * Appearance.effectiveScale
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.systemMonitorIndex = modelData.stackIndex

                        readonly property bool isActive: GlobalStates.systemMonitorIndex === modelData.stackIndex
                        
                        // Highlight Background
                        Rectangle {
                            id: itemBackground
                            anchors.left: parent.left
                            anchors.top: parent.top
                            
                            width: root.expanded ? (52 * Appearance.effectiveScale + itemText.implicitWidth + 24 * Appearance.effectiveScale) : 56 * Appearance.effectiveScale
                            height: root.expanded ? 56 * Appearance.effectiveScale : 32 * Appearance.effectiveScale
                            radius: 100 // Pill shape
                            
                            color: isActive ? Appearance.m3colors.m3secondaryContainer : (navBtn.containsMouse ? Appearance.colors.colLayer0Hover : "transparent")
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                        
                        Item {
                            id: iconContainer
                            width: 56 * Appearance.effectiveScale
                            height: root.expanded ? 56 * Appearance.effectiveScale : 32 * Appearance.effectiveScale
                            anchors.left: parent.left
                            anchors.top: parent.top
                            
                            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                iconSize: 24 * Appearance.effectiveScale
                                color: isActive ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                        
                        StyledText {
                            id: itemText
                            text: modelData.name
                            font.pixelSize: root.expanded ? Math.round(14 * Appearance.effectiveScale) : Math.round(12 * Appearance.effectiveScale)
                            font.weight: Font.Normal
                            color: isActive ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            states: [
                                State {
                                    name: "expanded"
                                    when: root.expanded
                                    AnchorChanges {
                                        target: itemText
                                        anchors.horizontalCenter: undefined
                                        anchors.top: undefined
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    PropertyChanges {
                                        target: itemText
                                        anchors.leftMargin: 52 * Appearance.effectiveScale
                                        anchors.topMargin: 0
                                    }
                                },
                                State {
                                    name: "collapsed"
                                    when: !root.expanded
                                    AnchorChanges {
                                        target: itemText
                                        anchors.left: undefined
                                        anchors.verticalCenter: undefined
                                        anchors.horizontalCenter: iconContainer.horizontalCenter
                                        anchors.top: iconContainer.bottom
                                    }
                                    PropertyChanges {
                                        target: itemText
                                        anchors.topMargin: 4 * Appearance.effectiveScale
                                        anchors.leftMargin: 0
                                    }
                                }
                            ]
                            
                            transitions: Transition {
                                AnchorAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Bottom Profile info (Using universal widget)
        UserProfile {
            compact: !root.expanded
            Layout.fillWidth: true
            onClicked: {
                GlobalStates.systemMonitorOpen = false
                GlobalStates.settingsPageIndex = 8
                GlobalStates.activateSettings()
            }
        }
    }
}
