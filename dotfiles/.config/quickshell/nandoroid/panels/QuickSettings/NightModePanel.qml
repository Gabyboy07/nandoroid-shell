import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts

/**
 * Night Mode detail panel.
 * Shows toggle + color temperature slider.
 */
Rectangle {
    id: root
    signal dismiss()

    focus: true
    property bool inheritedNav: false
    property bool navEngaged: false

    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.panel

    // ── Keyboard navigation ──
    function adjustTemp(delta) {
        const target = Math.max(tempSlider.from, Math.min(tempSlider.to, tempSlider.value + delta));
        Config.options.nightMode.colorTemperature = target;
    }

    function syncNightRing() {
        const p = tempSlider.mapToItem(root, 0, 0);
        nightNavRing.x = p.x - 4 * Appearance.effectiveScale;
        nightNavRing.y = p.y - 4 * Appearance.effectiveScale;
        nightNavRing.width = tempSlider.width + 8 * Appearance.effectiveScale;
        nightNavRing.height = tempSlider.height + 8 * Appearance.effectiveScale;
        nightNavRing.radius = Math.min(12 * Appearance.effectiveScale, nightNavRing.height / 2);
        nightNavRing.visible = root.activeFocus && root.navEngaged;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true; return; }
        root.navEngaged = true;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            Hyprsunset.toggle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.adjustTemp(-100);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.adjustTemp(100);
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.navEngaged = root.inheritedNav;
        root.forceActiveFocus();
        Qt.callLater(() => root.syncNightRing());
    }

    // Block clicks and hovers from leaking through to the items below
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
        onPressed: (mouse) => mouse.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14 * Appearance.effectiveScale
        spacing: 12 * Appearance.effectiveScale

        // ── Header ──
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
                text: I18nService.tr("Night Mode")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
            }

            RippleButton {
                implicitWidth: 56 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Hyprsunset.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                colBackgroundHover: Hyprsunset.active ? Qt.darker(Appearance.colors.colPrimary, 1.12) : Appearance.colors.colLayer2Hover
                onClicked: Hyprsunset.toggle()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "bedtime"
                    iconSize: 20 * Appearance.effectiveScale
                    fill: Hyprsunset.active ? 1 : 0
                    color: Hyprsunset.active ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                }
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }


        // ── Color temperature slider ──
        Column {
            Layout.fillWidth: true
            Layout.topMargin: 8 * Appearance.effectiveScale
            spacing: 6 * Appearance.effectiveScale

            RowLayout {
                width: parent.width
                StyledText {
                    Layout.fillWidth: true
                    text: I18nService.tr("Color Temperature")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3onSurface
                }
                StyledText {
                    text: `${tempSlider.value}K`
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colPrimary
                }
            }

            // Temperature label row (cool ← → warm)
            RowLayout {
                width: parent.width
                StyledText {
                    text: I18nService.tr("Warm")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: I18nService.tr("Cool")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }

            StyledSlider {
                id: tempSlider
                width: parent.width
                from: 1200  // warmest
                to: 6500    // coolest
                stepSize: 100
                value: Config.options.nightMode?.colorTemperature ?? 4000
                configuration: StyledSlider.Configuration.S

                onMoved: {
                    Config.options.nightMode.colorTemperature = value;
                    // Hyprsunset.colorTemperature is bound to this config value,
                    // so onColorTemperatureChanged fires automatically — updating hyprsunset live.
                }
            }
        }



        Item { Layout.fillHeight: true }

        // ── Footer ──
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * Appearance.effectiveScale

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitWidth: doneText.implicitWidth + (24 * Appearance.effectiveScale)
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: height / 2
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Qt.darker(Appearance.colors.colPrimary, 1.1)
                onClicked: root.dismiss()
                StyledText {
                    id: doneText
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
        id: nightNavRing
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
