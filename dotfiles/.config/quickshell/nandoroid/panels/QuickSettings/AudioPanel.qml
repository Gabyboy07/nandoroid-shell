import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

/**
 * Functional Audio device selection panel.
 * Shared between Audio Output and Audio Input — configured via `isSink`.
 * Uses real Pipewire data from the Audio service.
 */
Rectangle {
    id: root
    signal dismiss()
    
    property string panelTitle: "Audio Output"
    property string panelIcon: "volume_up"
    property bool isSink: true

    focus: true
    property int navIndex: 0
    property bool inheritedNav: false
    property bool navEngaged: false

    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.panel

    // Block clicks and hovers from leaking through to the items below
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
        onPressed: (mouse) => mouse.accepted = true
    }

    // ── Keyboard navigation ──
    function syncAudioRing() {
        const it = deviceRepeater.itemAt(root.navIndex);
        if (!it) { audioNavRing.visible = false; return; }
        const p = it.mapToItem(root, 0, 0);
        audioNavRing.x = p.x - 4 * Appearance.effectiveScale;
        audioNavRing.y = p.y - 4 * Appearance.effectiveScale;
        audioNavRing.width = it.width + 8 * Appearance.effectiveScale;
        audioNavRing.height = it.height + 8 * Appearance.effectiveScale;
        audioNavRing.radius = Math.min(12 * Appearance.effectiveScale, audioNavRing.height / 2);
        audioNavRing.visible = root.activeFocus && root.navEngaged;
        const cpos = it.mapToItem(audioFlick.contentItem, 0, 0);
        if (cpos.y < audioFlick.contentY + 4 * Appearance.effectiveScale) audioFlick.contentY = Math.max(0, cpos.y - 4 * Appearance.effectiveScale);
        else if (cpos.y + it.height > audioFlick.contentY + audioFlick.height - 4 * Appearance.effectiveScale) audioFlick.contentY = cpos.y + it.height - audioFlick.height + 4 * Appearance.effectiveScale;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true; return; }
        root.navEngaged = true;
        if (event.key === Qt.Key_Up) {
            if (root.navIndex > 0) { root.navIndex--; root.syncAudioRing(); }
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (root.navIndex < deviceRepeater.count - 1) { root.navIndex++; root.syncAudioRing(); }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            const it = deviceRepeater.itemAt(root.navIndex);
            if (it) it.click();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.navEngaged = root.inheritedNav;
        root.forceActiveFocus();
        Qt.callLater(() => root.syncAudioRing());
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16 * Appearance.effectiveScale
        spacing: 12 * Appearance.effectiveScale

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * Appearance.effectiveScale

            RippleButton {
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colLayer2
                onClicked: root.dismiss()
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 20 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3onSurface
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: I18nService.tr(root.panelTitle)
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
            }

            MaterialSymbol {
                text: root.panelIcon
                iconSize: 22 * Appearance.effectiveScale
                color: Appearance.colors.colPrimary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }

        // Scrollable Content
        Flickable {
            id: audioFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: audioContentCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: audioContentCol
                width: audioFlick.width
                spacing: 20 * Appearance.effectiveScale

                // Section: Devices
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8 * Appearance.effectiveScale
                    
                    StyledText {
                        text: I18nService.tr("Devices")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.m3colors.m3outline
                        Layout.leftMargin: 4 * Appearance.effectiveScale
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2 * Appearance.effectiveScale
                        Repeater {
                            id: deviceRepeater
                            model: root.isSink ? Audio.outputDevices : Audio.inputDevices
                            delegate: RippleButton {
                                id: audioDeviceItem
                                required property var modelData
                                width: audioFlick.width
                                implicitHeight: 52 * Appearance.effectiveScale
                                buttonRadius: Appearance.rounding.small
                                
                                readonly property bool isActive: root.isSink 
                                    ? (Audio.sink === modelData)
                                    : (Audio.source === modelData)

                                colBackground: audioDeviceItem.isActive ? Functions.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85) : "transparent"
                                colBackgroundHover: audioDeviceItem.isActive ? Functions.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75) : Appearance.colors.colLayer2
                                
                                onClicked: {
                                    root.navIndex = index
                                    if (root.isSink) Audio.setDefaultSink(audioDeviceItem.modelData);
                                    else Audio.setDefaultSource(audioDeviceItem.modelData);
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12 * Appearance.effectiveScale
                                    anchors.rightMargin: 12 * Appearance.effectiveScale
                                    spacing: 12 * Appearance.effectiveScale

                                    MaterialSymbol {
                                        text: {
                                            if (!root.isSink) return "mic"
                                            const desc = audioDeviceItem.modelData.description.toLowerCase();
                                            if (desc.includes("headset") || desc.includes("headphone")) return "headphones"
                                            if (desc.includes("hdmi") || desc.includes("tv")) return "tv"
                                            return "speaker"
                                        }
                                        iconSize: 20 * Appearance.effectiveScale
                                        fill: audioDeviceItem.isActive ? 1 : 0
                                        color: audioDeviceItem.isActive ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.friendlyDeviceName(audioDeviceItem.modelData)
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.m3colors.m3onSurface
                                        elide: Text.ElideRight
                                    }

                                    MaterialSymbol {
                                        visible: audioDeviceItem.isActive
                                        text: "check_circle"
                                        iconSize: 18 * Appearance.effectiveScale
                                        fill: 1
                                        color: Appearance.colors.colPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                // Section: Applications
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8 * Appearance.effectiveScale
                    visible: (root.isSink ? Audio.streamNodes.length : Audio.micStreamNodes.length) > 0
                    
                    StyledText {
                        text: I18nService.tr("Applications")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.m3colors.m3outline
                        Layout.leftMargin: 4 * Appearance.effectiveScale
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 8 * Appearance.effectiveScale
                        Repeater {
                            model: root.isSink ? Audio.streamNodes : Audio.micStreamNodes
                            delegate: Rectangle {
                                id: streamItem
                                required property var modelData
                                width: audioFlick.width
                                implicitHeight: streamLayout.implicitHeight + (20 * Appearance.effectiveScale) // Dynamic height + margins
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small

                                ColumnLayout {
                                    id: streamLayout
                                    anchors.fill: parent
                                    anchors.margins: 10 * Appearance.effectiveScale
                                    spacing: 4 * Appearance.effectiveScale

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8 * Appearance.effectiveScale
                                        
                                        Item {
                                            width: 22 * Appearance.effectiveScale
                                            height: 22 * Appearance.effectiveScale
                                            
                                            IconImage {
                                                id: appIcon
                                                anchors.fill: parent
                                                source: Quickshell.iconPath(Audio.appNodeIconName(streamItem.modelData), "image-missing")
                                                visible: status === Image.Ready
                                            }

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "settings_input_component"
                                                iconSize: 18 * Appearance.effectiveScale
                                                color: Appearance.m3colors.m3primary
                                                visible: appIcon.status !== Image.Ready
                                            }
                                        }

                                        StyledText {
                                            text: Audio.appNodeDisplayName(streamItem.modelData)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: Appearance.m3colors.m3onSurface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        StyledText {
                                            text: Math.round(streamItem.modelData.audio.volume * 100) + "%"
                                            font.pixelSize: Math.round(10 * Appearance.effectiveScale)
                                            color: Appearance.colors.colSubtext
                                        }
                                    }

                                    StyledSlider {
                                        Layout.fillWidth: true
                                        configuration: StyledSlider.Configuration.M
                                        value: streamItem.modelData.audio.volume
                                        stopIndicatorValues: []
                                        onMoved: Audio.setNodeVolume(streamItem.modelData, value)
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom spacer for better scrolling
                Item { Layout.preferredHeight: 12 * Appearance.effectiveScale }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitWidth: audioDoneText.implicitWidth + (24 * Appearance.effectiveScale)
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Qt.darker(Appearance.colors.colPrimary, 1.12)
                onClicked: root.dismiss()
                StyledText {
                    id: audioDoneText
                    anchors.centerIn: parent
                    text: I18nService.tr("Done")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }

    // ── Keyboard focus ring ──
    Rectangle {
        id: audioNavRing
        visible: false
        z: 999
        enabled: false
        color: "transparent"
        border.width: Math.max(1, 2 * Appearance.effectiveScale)
        border.color: Appearance.m3colors.m3primary
        opacity: 0.9
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
