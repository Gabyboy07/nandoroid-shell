import "../../../../core"
import "../../../../services"
import "../../../../widgets"
import "../../../../core/functions" as Functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 0

    SearchHandler { searchString: "Search Engine" }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4 * Appearance.effectiveScale

        RowLayout {
            spacing: 12 * Appearance.effectiveScale
            Layout.bottomMargin: 8 * Appearance.effectiveScale
            MaterialSymbol {
                text: "search"
                iconSize: 24 * Appearance.effectiveScale
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: I18nService.tr("Search & Launcher")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
        }

        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: mathRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: mathRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("Math Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to trigger mathematical evaluations.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: mathInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.mathPrefix : "="
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.mathPrefix = text; }
                }
            }
        }

        // 2. Web Search Prefix Card
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: webRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: webRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("Web Search Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to trigger a Google search.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: webInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.webPrefix : "!"
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.webPrefix = text; }
                }
            }
        }

        // 3. Emoji Prefix Card
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: emojiRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: emojiRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("Emoji Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to search and copy emojis.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: emojiInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.emojiPrefix : ":"
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.emojiPrefix = text; }
                }
            }
        }

        // 4. Clipboard Prefix Card
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: clipRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: clipRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("Clipboard Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to search clipboard history.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: clipInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.clipboardPrefix : ";"
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.clipboardPrefix = text; }
                }
            }
        }

        // 5. File Search Prefix Card
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: fileRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: fileRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("File Search Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to trigger local file searching.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: fileInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.filePrefix : "?"
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.filePrefix = text; }
                }
            }
        }

        // 6. Command Prefix Card
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: cmdRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: cmdRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("Command Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to trigger shell commands and quick actions.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: cmdInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.commandPrefix : ">"
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.commandPrefix = text; }
                }
            }
        }

        // 7. Settings Search Prefix Card
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: settingsRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: settingsRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("Settings Search Prefix")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prefix to search and jump to a setting.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                StyledTextInput {
                    id: settingsInput
                    width: 120 * Appearance.effectiveScale
                    height: 48 * Appearance.effectiveScale
                    horizontalAlignment: TextInput.AlignHCenter
                    text: (Config.ready && Config.options.search) ? Config.options.search.settingsPrefix : "<"
                    onEditingFinished: { if (Config.ready && Config.options.search) Config.options.search.settingsPrefix = text; }
                }
            }
        }

        // 8. App Usage Tracking Toggle
        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: usageRow.implicitHeight + 40 * Appearance.effectiveScale
            orientation: Qt.Vertical
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: usageRow
                anchors.fill: parent
                anchors.margins: 20 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                ColumnLayout {
                    spacing: 2 * Appearance.effectiveScale
                    StyledText {
                        text: I18nService.tr("App Usage Tracking")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: I18nService.tr("Prioritize frequently used apps in search results.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                Item { Layout.fillWidth: true }
                
                AndroidToggle {
                    checked: (Config.ready && Config.options.search) ? Config.options.search.enableUsageTracking : true
                    onToggled: { if (Config.ready && Config.options.search) Config.options.search.enableUsageTracking = checked; }
                }
            }
        }
    }
}

