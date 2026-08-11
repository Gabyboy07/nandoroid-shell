import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * Navigation sidebar for the Settings panel.
 * Uses a NavigationRail style common in modern Android apps.
 */
Rectangle {
    id: root
    implicitWidth: 80 * Appearance.effectiveScale // Fixed width for rail
    color: Appearance.colors.colLayer0
    
    property int currentIndex: 0
    signal pageSelected(int index)

    Flickable {
        anchors.fill: parent
        contentHeight: mainLayout.implicitHeight + 24 * Appearance.effectiveScale
        clip: true
        ScrollBar.vertical: StyledScrollBar {}

        ColumnLayout {
            id: mainLayout
            width: parent.width
            anchors.margins: 12 * Appearance.effectiveScale
            anchors.topMargin: 24 * Appearance.effectiveScale
            spacing: 24 * Appearance.effectiveScale

            // Config button (FAB style)
            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 56 * Appearance.effectiveScale
                implicitHeight: 56 * Appearance.effectiveScale
                buttonRadius: 16 * Appearance.effectiveScale // Squircle / FAB shape
                colBackground: Appearance.m3colors.m3primaryContainer
                colBackgroundHover: Functions.ColorUtils.mix(Appearance.m3colors.m3primaryContainer, Appearance.m3colors.m3onPrimaryContainer, 0.9)
                colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onPrimaryContainer, 0.15)
                
                onClicked: {
                    let path = Directories.shellConfigPath;
                    if (!Qt.openUrlExternally("file://" + path)) {
                        Quickshell.execDetached(["xdg-open", path]);
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "edit" // Config icon
                    iconSize: 24 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3onPrimaryContainer
                }

                StyledToolTip { text: I18nService.tr("Open config file"); extraVisibleCondition: parent.hovered || parent.realHovered }
            }

            // Navigation Items
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12 * Appearance.effectiveScale

                Repeater {
                    model: [
                        { name: I18nService.tr("Network"), icon: "wifi" },
                        { name: I18nService.tr("Bluetooth"), icon: "bluetooth" },
                        { name: I18nService.tr("Audio"), icon: "volume_up" },
                        { name: I18nService.tr("Display"), icon: "monitor" },
                        { name: I18nService.tr("Customize"), icon: "palette" },
                        { name: I18nService.tr("Widgets"), icon: "widgets" },
                        { name: I18nService.tr("System"), icon: "settings_applications" },
                        { name: I18nService.tr("Services"), icon: "cloud" },
                        { name: I18nService.tr("Profile"), icon: "person" },
                        { name: I18nService.tr("About"), icon: "info" }
                    ]

                    delegate: Item {
                        id: btn
                        Layout.fillWidth: true
                        implicitHeight: 56 * Appearance.effectiveScale // Taller to fit icon + text
                        
                        readonly property bool isActive: root.currentIndex === index
                        
                        // Active pill background
                        Rectangle {
                            id: pillBg
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 4 * Appearance.effectiveScale // Center block in 56px height
                            width: 56 * Appearance.effectiveScale
                            height: 32 * Appearance.effectiveScale
                            radius: height / 2
                            color: isActive 
                                ? Appearance.m3colors.m3secondaryContainer 
                                : (btnMouse.containsMouse ? Appearance.colors.colLayer0Hover : "transparent")
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MaterialSymbol {
                            anchors.centerIn: pillBg
                            text: modelData.icon
                            iconSize: 24 * Appearance.effectiveScale
                            color: isActive 
                                ? Appearance.m3colors.m3onSecondaryContainer 
                                : Appearance.colors.colOnLayer0
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: pillBg.bottom
                            anchors.topMargin: 4 * Appearance.effectiveScale // Close to pill
                            text: modelData.name
                            font.pixelSize: Math.round(12 * Appearance.effectiveScale)
                            font.weight: isActive ? Font.DemiBold : Font.Medium
                            color: isActive 
                                ? Appearance.m3colors.m3onSurface
                                : Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pageSelected(index)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
