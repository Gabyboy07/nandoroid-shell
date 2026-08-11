pragma ComponentBehavior: Bound

import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    Loader {
        active: DialogService.active
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData
                
                readonly property bool isActive: GlobalStates.activeScreen === modelData
                visible: DialogService.active && isActive

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "nandoroid:dialog"
                WlrLayershell.keyboardFocus: (DialogService.active && isActive) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                WlrLayershell.layer: (DialogService.active && isActive) ? WlrLayer.Overlay : WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore

                Component.onCompleted: GlobalFocusGrab.addDismissable(panelWindow)
                Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)

                Connections {
                    target: GlobalFocusGrab
                    function onDismissed() {
                        DialogService.cancel()
                    }
                }

                // ── Scrim ──
                Rectangle {
                    anchors.fill: parent
                    color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.6)
                    opacity: (DialogService.active && isActive) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // ── Auth Dialog ──
                Rectangle {
                    id: dialog
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48 * Appearance.effectiveScale, 450 * Appearance.effectiveScale)
                    implicitHeight: contentCol.implicitHeight + (48 * Appearance.effectiveScale)
                    radius: Appearance.rounding.card
                    color: Appearance.m3colors.m3surfaceContainerHigh
                    
                    StyledRectangularShadow {
                        target: dialog
                        z: -1
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 24 * Appearance.effectiveScale
                        spacing: 20 * Appearance.effectiveScale

                        // Icon
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: DialogService.iconText
                            iconSize: 32 * Appearance.effectiveScale
                            color: DialogService.isDestructive ? Appearance.colors.colError : Appearance.colors.colPrimary
                            visible: text !== ""
                        }

                        // Title
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: DialogService.titleText
                            font.pixelSize: Appearance.font.pixelSize.large || 18 * Appearance.effectiveScale
                            font.weight: 600
                            color: Appearance.colors.colOnLayer1
                            wrapMode: Text.Wrap
                        }

                        // Message
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: DialogService.messageText
                            font.pixelSize: Appearance.font.pixelSize.normal || 14 * Appearance.effectiveScale
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                            lineHeight: 1.4
                        }
                        
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4 * Appearance.effectiveScale
                        }

                        // Buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12 * Appearance.effectiveScale

                            Item { Layout.fillWidth: true } // spacer

                            RippleButton {
                                Layout.preferredWidth: implicitWidth > 100 * Appearance.effectiveScale ? implicitWidth : 100 * Appearance.effectiveScale
                                Layout.preferredHeight: 40 * Appearance.effectiveScale
                                buttonRadius: Appearance.rounding.button
                                buttonText: DialogService.cancelText
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: DialogService.cancel()
                            }

                            RippleButton {
                                Layout.preferredWidth: implicitWidth > 100 * Appearance.effectiveScale ? implicitWidth : 100 * Appearance.effectiveScale
                                Layout.preferredHeight: 40 * Appearance.effectiveScale
                                buttonRadius: Appearance.rounding.button
                                buttonText: DialogService.confirmText
                                colBackground: DialogService.isDestructive ? Appearance.colors.colError : Appearance.colors.colPrimary
                                colText: DialogService.isDestructive ? Appearance.colors.colOnError : Appearance.colors.colOnPrimary
                                onClicked: DialogService.submit()
                            }
                        }
                    }

                    // Key Handling
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            DialogService.cancel();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            DialogService.submit();
                            event.accepted = true;
                        }
                    }
                    
                    // Focus handling
                    onVisibleChanged: {
                        if (visible) {
                            forceActiveFocus()
                        }
                    }
                }
            }
        }
    }
}
