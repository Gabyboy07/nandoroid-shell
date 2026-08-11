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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Persistent Config Button
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 0
            Layout.bottomMargin: 24 * Appearance.effectiveScale
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: sidebarFlickable
                anchors.fill: parent
                contentHeight: mainLayout.implicitHeight
                clip: true
                ScrollBar.vertical: StyledScrollBar {}
                
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: scrollMask
                }

            ColumnLayout {
                id: mainLayout
                width: parent.width
                anchors.left: parent.left
                anchors.right: parent.right
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
                        
                        onIsActiveChanged: {
                            if (isActive) {
                                Qt.callLater(() => {
                                    if (!sidebarFlickable.contentItem) return;
                                    let pos = btn.mapToItem(sidebarFlickable.contentItem, 0, 0);
                                    let itemY = pos.y;
                                    let itemHeight = btn.height;
                                    
                                    let safeTop = sidebarFlickable.contentY + 56 * Appearance.effectiveScale;
                                    let safeBottom = sidebarFlickable.contentY + sidebarFlickable.height - 56 * Appearance.effectiveScale;
                                    
                                    if (itemY < safeTop) {
                                        sidebarFlickable.contentY = Math.max(0, itemY - 68 * Appearance.effectiveScale);
                                    } else if (itemY + itemHeight > safeBottom) {
                                        sidebarFlickable.contentY = Math.min(
                                            Math.max(0, sidebarFlickable.contentHeight - sidebarFlickable.height), 
                                            itemY + itemHeight - sidebarFlickable.height + 68 * Appearance.effectiveScale
                                        );
                                    }
                                });
                            }
                        }
                        
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
                                : Appearance.m3colors.m3onSurfaceVariant
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: pillBg.bottom
                            anchors.topMargin: 4 * Appearance.effectiveScale // Close to pill
                            text: modelData.name
                            font.pixelSize: Math.round(12 * Appearance.effectiveScale)
                            font.weight: Font.Medium
                            color: isActive 
                                ? Appearance.m3colors.m3onSurface
                                : Appearance.m3colors.m3onSurfaceVariant
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

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 24 * Appearance.effectiveScale
                }
            }
        }

            // ── Scroll Mask ──
            LinearGradient {
                id: scrollMask
                anchors.fill: sidebarFlickable
                visible: false
                start: Qt.point(0, 0)
                end: Qt.point(0, height)
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: sidebarFlickable.atYBeginning ? "white" : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    GradientStop {
                        position: Math.min(1.0, (56 * Appearance.effectiveScale) / Math.max(1, scrollMask.height))
                        color: "white"
                    }
                    GradientStop {
                        position: Math.max(0.0, 1.0 - ((56 * Appearance.effectiveScale) / Math.max(1, scrollMask.height)))
                        color: "white"
                    }
                    GradientStop {
                        position: 1.0
                        color: sidebarFlickable.atYEnd ? "white" : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}
