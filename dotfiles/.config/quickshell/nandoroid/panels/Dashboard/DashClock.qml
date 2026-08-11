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

        // ── Top Tab Bar ──
        Item {
            Layout.fillWidth: true
            height: 64 * Appearance.effectiveScale

            // Bottom border for the entire tab bar
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1 * Appearance.effectiveScale
                color: Appearance.m3colors.m3surfaceVariant
                opacity: 0.5
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: [
                        { name: I18nService.tr("Pomodoro"), icon: "alarm" },
                        { name: I18nService.tr("Stopwatch"), icon: "timer" },
                        { name: I18nService.tr("Timer"), icon: "hourglass_bottom" }
                    ]
                    
                    delegate: RippleButton {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        buttonRadius: 0
                        topLeftRadius: index === 0 ? Appearance.rounding.normal : 0
                        topRightRadius: index === 2 ? Appearance.rounding.normal : 0
                        
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer0Hover
                        colRipple: Appearance.colors.colLayer0Active
                        onClicked: root.currentTab = index
                        
                        readonly property bool isActive: root.currentTab === index

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6 * Appearance.effectiveScale
                            
                            Item { Layout.fillHeight: true } // spacer
                            
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                iconSize: 24 * Appearance.effectiveScale
                                color: isActive ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                font.pixelSize: 12 * Appearance.effectiveScale
                                font.weight: Font.Medium
                                color: isActive ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            
                            Item { Layout.fillHeight: true; Layout.preferredHeight: 4 * Appearance.effectiveScale } // spacer
                        }

                        // Active Indicator
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: isActive ? 48 * Appearance.effectiveScale : 0
                            height: 3 * Appearance.effectiveScale
                            
                            topLeftRadius: 3 * Appearance.effectiveScale
                            topRightRadius: 3 * Appearance.effectiveScale
                            bottomLeftRadius: 0
                            bottomRightRadius: 0
                            
                            color: Appearance.m3colors.m3primary
                            
                            Behavior on width { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial } }
                        }

                    }
                }
            }
        }

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
    }
}
