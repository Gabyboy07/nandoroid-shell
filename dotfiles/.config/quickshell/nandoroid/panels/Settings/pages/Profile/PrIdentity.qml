import "../../../../core"
import "../../../../core/functions" as Functions
import "../../../../services"
import "../../../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    SearchHandler {
        searchString: "Identity"
        aliases: ["Display Name", "Description", "Distro", "Uptime"]
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4 * Appearance.effectiveScale

        RowLayout {
            spacing: 12 * Appearance.effectiveScale
            Layout.bottomMargin: 4 * Appearance.effectiveScale
            MaterialSymbol {
                text: "badge"
                iconSize: 24 * Appearance.effectiveScale
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: "Identity"
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
        }

        // Display Name
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: displayNameRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: displayNameRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: "Display Name"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: "Leave empty to use system real name."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 250 * Appearance.effectiveScale
                    implicitHeight: 48 * Appearance.effectiveScale
                    radius: 12 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3surfaceContainerLow
                    border.width: displayNameInput.activeFocus ? Math.max(1, 2 * Appearance.effectiveScale) : 0
                    border.color: Appearance.colors.colPrimary

                    TextInput {
                        id: displayNameInput
                        anchors.fill: parent
                        anchors.leftMargin: 16 * Appearance.effectiveScale
                        anchors.rightMargin: 16 * Appearance.effectiveScale
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        clip: true
                        text: Config.options.profile.displayName

                        onEditingFinished: {
                            displayNameDebounceTimer.restart()
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: SystemInfo.realName || SystemInfo.username
                            color: Appearance.colors.colSubtext
                            visible: displayNameInput.text === "" && !displayNameInput.activeFocus
                        }
                    }
                }

                Timer {
                    id: displayNameDebounceTimer
                    interval: 800
                    repeat: false
                    onTriggered: {
                        Config.options.profile.displayName = displayNameInput.text
                    }
                }
            }
        }

        // Description Text
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: descRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            forceFirst: false
            forceLast: true
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: descRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: "Description Text"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: "Shown below your display name."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4 * Appearance.effectiveScale

                    Repeater {
                        model: [
                            { label: "Distro", value: "::distro::" },
                            { label: "Uptime", value: "::uptime::" }
                        ]

                        delegate: SegmentedButton {
                            isHighlighted: Config.options.profile.descriptionText === modelData.value
                            buttonText: modelData.label
                            colActive: Appearance.m3colors.m3primary
                            colActiveText: Appearance.m3colors.m3onPrimary
                            colInactive: Appearance.m3colors.m3surfaceContainerLow
                            onClicked: Config.options.profile.descriptionText = modelData.value
                        }
                    }
                }
            }
        }
    }
}
