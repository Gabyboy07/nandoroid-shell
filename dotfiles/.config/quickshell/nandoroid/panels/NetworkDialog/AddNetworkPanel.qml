pragma ComponentBehavior: Bound

import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/**
 * Add Network Panel.
 * Acts as a modal dialog across the entire screen.
 */
Scope {
    id: root

    Loader {
        active: GlobalStates.addNetworkDialogOpen
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData

                readonly property bool isActive: GlobalStates.activeScreen === modelData
                visible: GlobalStates.addNetworkDialogOpen && isActive

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "nandoroid:networkadd"
                WlrLayershell.keyboardFocus: (GlobalStates.addNetworkDialogOpen && isActive) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                WlrLayershell.layer: (GlobalStates.addNetworkDialogOpen && isActive) ? WlrLayer.Overlay : WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore

                // State
                property bool isHidden: false
                property bool showPassword: false

                function closeDialog() {
                    ssidInput.text = "";
                    hiddenPassInput.text = "";
                    isHidden = false;
                    showPassword = false;
                    GlobalStates.addNetworkDialogOpen = false;
                }

                // Close when clicking outside
                MouseArea {
                    anchors.fill: parent
                    onClicked: panelWindow.closeDialog()
                }

                // Esc to close
                Shortcut {
                    sequence: "Escape"
                    onActivated: panelWindow.closeDialog()
                    enabled: panelWindow.visible
                }

                // Scrim
                Rectangle {
                    anchors.fill: parent
                    color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.6)
                    opacity: (GlobalStates.addNetworkDialogOpen && isActive) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // Dialog Content
                Rectangle {
                    id: dialog
                    anchors.centerIn: parent
                    width: Math.min(500 * Appearance.effectiveScale, panelWindow.width * 0.9)
                    implicitHeight: contentCol.implicitHeight + (48 * Appearance.effectiveScale)
                    radius: Appearance.rounding.card
                    color: Appearance.m3colors.m3surfaceContainerHigh

                    MouseArea {
                        anchors.fill: parent
                        // Prevent click-through to the background scrim
                    }

                    // No shadow required for fullscreen modals

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 24 * Appearance.effectiveScale
                        spacing: 20 * Appearance.effectiveScale

                        // Icon
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "network_wifi"
                            iconSize: 32 * Appearance.effectiveScale
                            color: Appearance.colors.colPrimary
                        }
                        
                        // Title
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: I18nService.tr("Add Network")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }
                        
                        // Message
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: I18nService.tr("Enter the details of the network you want to join.")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                        }

                        // Inputs
                        ColumnLayout {
                            spacing: 20 * Appearance.effectiveScale
                            Layout.fillWidth: true

                            // SSID Input
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52 * Appearance.effectiveScale
                                radius: 8 * Appearance.effectiveScale
                                color: "transparent"
                                border.width: ssidInput.input.activeFocus ? Math.max(1, 2 * Appearance.effectiveScale) : Math.max(1, 1 * Appearance.effectiveScale)
                                border.color: ssidInput.input.activeFocus ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outline

                                // Floating Label
                                Rectangle {
                                    x: 12 * Appearance.effectiveScale
                                    y: -8 * Appearance.effectiveScale
                                    width: ssidLabel.width + 8 * Appearance.effectiveScale
                                    height: 16 * Appearance.effectiveScale
                                    color: Appearance.m3colors.m3surfaceContainerHigh
                                    
                                    StyledText {
                                        id: ssidLabel
                                        anchors.centerIn: parent
                                        text: I18nService.tr("Network Name")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: ssidInput.input.activeFocus ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outline
                                    }
                                }

                                StyledTextInput {
                                    id: ssidInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 16 * Appearance.effectiveScale
                                    anchors.rightMargin: 16 * Appearance.effectiveScale
                                    placeholder: I18nService.tr("SSID")
                                    backgroundColor: "transparent"
                                    inputRadius: 0
                                    borderInactiveWidth: 0
                                    showActiveBorder: false
                                    leftMargin: 0
                                    rightMargin: 0
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }
                            }

                            // Password Input
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52 * Appearance.effectiveScale
                                radius: 8 * Appearance.effectiveScale
                                color: "transparent"
                                border.width: hiddenPassInput.input.activeFocus ? Math.max(1, 2 * Appearance.effectiveScale) : Math.max(1, 1 * Appearance.effectiveScale)
                                border.color: hiddenPassInput.input.activeFocus ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outline

                                // Floating Label
                                Rectangle {
                                    x: 12 * Appearance.effectiveScale
                                    y: -8 * Appearance.effectiveScale
                                    width: passLabel.width + 8 * Appearance.effectiveScale
                                    height: 16 * Appearance.effectiveScale
                                    color: Appearance.m3colors.m3surfaceContainerHigh
                                    
                                    StyledText {
                                        id: passLabel
                                        anchors.centerIn: parent
                                        text: I18nService.tr("Password")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: hiddenPassInput.input.activeFocus ? Appearance.m3colors.m3primary : Appearance.m3colors.m3outline
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16 * Appearance.effectiveScale
                                    anchors.rightMargin: 8 * Appearance.effectiveScale
                                    
                                    StyledTextInput {
                                        id: hiddenPassInput
                                        Layout.fillWidth: true
                                        echoMode: panelWindow.showPassword ? TextInput.Normal : TextInput.Password
                                        placeholder: I18nService.tr("Optional")
                                        backgroundColor: "transparent"
                                        inputRadius: 0
                                        borderInactiveWidth: 0
                                        showActiveBorder: false
                                        leftMargin: 0
                                        rightMargin: 0
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                    }

                                    RippleButton {
                                        implicitWidth: 32 * Appearance.effectiveScale
                                        implicitHeight: 32 * Appearance.effectiveScale
                                        buttonRadius: 16 * Appearance.effectiveScale
                                        colBackground: "transparent"
                                        onClicked: panelWindow.showPassword = !panelWindow.showPassword
                                        contentItem: MaterialSymbol {
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: panelWindow.showPassword ? "visibility_off" : "visibility"
                                            iconSize: 20 * Appearance.effectiveScale
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }
                        }

                        // Options (Interactive Hidden Toggle)
                        MouseArea {
                            id: hiddenToggleArea
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32 * Appearance.effectiveScale
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panelWindow.isHidden = !panelWindow.isHidden
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8 * Appearance.effectiveScale
                                
                                RippleButton {
                                    implicitWidth: 32 * Appearance.effectiveScale
                                    implicitHeight: 32 * Appearance.effectiveScale
                                    buttonRadius: 8 * Appearance.effectiveScale
                                    colBackground: "transparent"
                                    onClicked: panelWindow.isHidden = !panelWindow.isHidden
                                    contentItem: MaterialSymbol {
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: panelWindow.isHidden ? "check_box" : "check_box_outline_blank"
                                        iconSize: 20 * Appearance.effectiveScale
                                        color: panelWindow.isHidden ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                    }
                                }
                                
                                StyledText {
                                    text: I18nService.tr("Hidden network")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }

                        // Actions
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 12 * Appearance.effectiveScale
                            spacing: 12 * Appearance.effectiveScale
                            
                            Item { Layout.fillWidth: true }
                            
                            RippleButton {
                                buttonText: I18nService.tr("Cancel")
                                Layout.preferredWidth: 100 * Appearance.effectiveScale
                                Layout.preferredHeight: 40 * Appearance.effectiveScale
                                buttonRadius: Appearance.rounding.button
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: panelWindow.closeDialog()
                            }
                            
                            RippleButton {
                                buttonText: I18nService.tr("Connect")
                                Layout.preferredWidth: 100 * Appearance.effectiveScale
                                Layout.preferredHeight: 40 * Appearance.effectiveScale
                                buttonRadius: Appearance.rounding.button
                                colBackground: Appearance.colors.colPrimary
                                colText: Appearance.colors.colOnPrimary
                                enabled: ssidInput.text.length > 0
                                onClicked: {
                                    Network.connectWithPassword(ssidInput.text, hiddenPassInput.text, panelWindow.isHidden);
                                    panelWindow.closeDialog();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
