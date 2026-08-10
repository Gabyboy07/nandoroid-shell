import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../core/functions" as Functions
import "../../widgets"
import "../../services"

Rectangle {
    id: root
    color: Appearance.m3colors.m3surfaceContainer
    radius: Appearance.rounding.normal
    clip: true

    property int currentTab: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Content Area ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                anchors.fill: parent
                active: root.currentTab === 0
                visible: active
                sourceComponent: PomodoroView {}
            }

            Loader {
                anchors.fill: parent
                active: root.currentTab === 1
                visible: active
                sourceComponent: StopwatchView {}
            }

            Loader {
                anchors.fill: parent
                active: root.currentTab === 2
                visible: active
                sourceComponent: TimerView {}
            }
        }

        // ── Bottom Navbar ──
        Item {
            Layout.fillWidth: true
            height: 64 * Appearance.effectiveScale

            Rectangle {
                anchors.fill: parent
                color: Appearance.m3colors.m3surfaceContainerHigh
                radius: Appearance.rounding.normal
            }
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerHigh
            }

            RowLayout {
                anchors.fill: parent
                spacing: 8 * Appearance.effectiveScale

                Repeater {
                    model: [
                        { name: I18nService.tr("Pomodoro"), icon: "alarm" },
                        { name: I18nService.tr("Stopwatch"), icon: "timer" },
                        { name: I18nService.tr("Timer"), icon: "hourglass_bottom" }
                    ]
                    
                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        readonly property bool isActive: root.currentTab === index

                        // Active pill background
                        Rectangle {
                            width: 64 * Appearance.effectiveScale
                            height: 32 * Appearance.effectiveScale
                            anchors.top: parent.top
                            anchors.topMargin: 8 * Appearance.effectiveScale
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: height / 2
                            color: isActive ? Appearance.m3colors.m3secondaryContainer : "transparent"
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4 * Appearance.effectiveScale
                            
                            Item { Layout.fillHeight: true } // spacer
                            
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                iconSize: 24 * Appearance.effectiveScale
                                color: isActive ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                font.pixelSize: 12 * Appearance.effectiveScale
                                font.weight: Font.Medium
                                color: isActive ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                            }
                            
                            Item { Layout.fillHeight: true } // spacer
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = index
                        }
                    }
                }
            }
        }
    }
}
