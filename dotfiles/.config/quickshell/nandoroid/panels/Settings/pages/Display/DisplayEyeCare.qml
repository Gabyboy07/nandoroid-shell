import "../../../../core"
import "../../../../services"
import "../../../../widgets"
import "../../../../core/functions" as Functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

ColumnLayout {
            Layout.fillWidth: true
            spacing: 4 * Appearance.effectiveScale

            RowLayout {
                spacing: 12 * Appearance.effectiveScale
                Layout.bottomMargin: 8 * Appearance.effectiveScale
                MaterialSymbol {
                    text: "bedtime"
                    iconSize: 24 * Appearance.effectiveScale
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: I18nService.tr("Eye Care")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }

            SegmentedWrapper {
                Layout.fillWidth: true
                implicitHeight: nightRow.implicitHeight + (40 * Appearance.effectiveScale)
                orientation: Qt.Vertical
                color: Appearance.m3colors.m3surfaceContainerHigh
                smallRadius: 8 * Appearance.effectiveScale
                fullRadius: 20 * Appearance.effectiveScale
                
                RowLayout {
                    id: nightRow
                    anchors.fill: parent
                    anchors.margins: 20 * Appearance.effectiveScale
                    spacing: 20 * Appearance.effectiveScale
                    
                    ColumnLayout {
                        spacing: 2 * Appearance.effectiveScale
                        StyledText {
                            text: I18nService.tr("Night Light")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: I18nService.tr("Reduce eye strain by displaying warmer colors.")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                    
                    Item { Layout.fillWidth: true }

                    AndroidToggle {
                        checked: Hyprsunset.active
                        onToggled: Hyprsunset.toggle()
                    }
                }
            }

            SegmentedWrapper {
                Layout.fillWidth: true
                implicitHeight: colorTempRow.implicitHeight + (40 * Appearance.effectiveScale)
                orientation: Qt.Vertical
                color: Appearance.m3colors.m3surfaceContainerHigh
                smallRadius: 8 * Appearance.effectiveScale
                fullRadius: 20 * Appearance.effectiveScale
                
                opacity: Hyprsunset.active ? 1.0 : 0.4
                enabled: Hyprsunset.active

                RowLayout {
                    id: colorTempRow
                    anchors.fill: parent
                    anchors.margins: 20 * Appearance.effectiveScale
                    spacing: 20 * Appearance.effectiveScale

                    StyledText {
                        text: I18nService.tr("Color Temperature")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledStepper {
                        Layout.alignment: Qt.AlignVCenter
                        from: 1200
                        to: 6500
                        stepSize: 100
                        decimals: 0
                        suffix: "K"
                        value: (Config.options && Config.options.nightMode) ? Config.options.nightMode.colorTemperature : 4000
                        onValueChanged: {
                            if (Config.ready && Config.options.nightMode) {
                                Config.options.nightMode.colorTemperature = value;
                            }
                        }
                    }
                }
        }
    }
