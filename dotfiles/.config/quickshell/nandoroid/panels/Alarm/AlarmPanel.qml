import "../../core"
import "../../services"
import "../../widgets"
import "../../core/functions" as Functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Android-style alarm card — top-center floating panel.
 * Shows a big live clock, the alarm message, and Snooze/Stop pill buttons.
 * Visible while AlarmService is ringing; DND-proof (own layer, no
 * involvement of the notification pipeline).
 */
Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    // Follows Config timeStyle; 12-hour shows plain digits without AM/PM text (Android style).
    // Qt only renders "hh" as 12-hour when the format contains ap/AP — so compute it manually.
    function formatClock(d) {
        const is24 = (Config.ready && Config.options.time) ? Config.options.time.timeStyle === "24H" : true;
        if (is24) return Qt.formatTime(d, "HH:mm");
        let h = d.getHours() % 12;
        if (h === 0) h = 12;
        return String(h).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    }

    // Change notifier so currentTime re-syncs when the time style config changes
    readonly property string timeStyle: (Config.ready && Config.options.time) ? Config.options.time.timeStyle : "24H"
    property string currentTime: formatClock(new Date())
    onTimeStyleChanged: currentTime = formatClock(new Date())

    Timer {
        interval: 1000
        repeat: true
        running: AlarmService.ringing
        onTriggered: root.currentTime = root.formatClock(new Date())
    }

    // Sync immediately when the alarm starts ringing (initial value may be stale)
    Connections {
        target: AlarmService
        function onRingingChanged() {
            if (AlarmService.ringing) root.currentTime = root.formatClock(new Date());
        }
    }

    PanelWindow {
        id: window
        visible: AlarmService.ringing

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "nandoroid:alarm"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }

        screen: root.focusedScreen
        Connections {
            target: root
            function onFocusedScreenChanged() { window.screen = root.focusedScreen; }
        }

        // Only the card is interactive
        mask: Region { item: alarmCard }

        // While ringing, clicks on the alarm card must NOT count as
        // "clicking outside" for HyprlandFocusGrab (which would close panels)
        Component.onDestruction: GlobalFocusGrab.removePersistent(window)

        implicitWidth: alarmCard.implicitWidth + (40 * Appearance.effectiveScale)
        implicitHeight: alarmCard.implicitHeight + (40 * Appearance.effectiveScale)

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addPersistent(window);
                alarmCard.opacity = 0;
                alarmSlide.y = -24 * Appearance.effectiveScale;
                alarmCard.scale = 0.95;
                entryAnim.restart();
            } else {
                GlobalFocusGrab.removePersistent(window);
            }
        }

        ParallelAnimation {
            id: entryAnim
            NumberAnimation { target: alarmCard; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuint }
            NumberAnimation { target: alarmSlide; property: "y"; from: -24 * Appearance.effectiveScale; to: 0; duration: 400; easing.type: Easing.OutQuint }
            NumberAnimation { target: alarmCard; property: "scale"; from: 0.95; to: 1; duration: 400; easing.type: Easing.OutBack }
        }

        // --- Alarm card ---
        Rectangle {
            id: alarmCard
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: ((Config.options?.statusBar?.height ?? 40) * Appearance.effectiveScale) + (16 * Appearance.effectiveScale)
            }
            transform: Translate { id: alarmSlide }

            implicitWidth: 440 * Appearance.effectiveScale
            implicitHeight: cardColumn.implicitHeight + (48 * Appearance.effectiveScale)
            radius: Appearance.rounding.large * 1.5
            color: Appearance.colors.colLayer1

            StyledRectangularShadow { target: alarmCard; z: -1 }

            // Block click-through
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: cardColumn
                anchors.fill: parent
                anchors.margins: 24 * Appearance.effectiveScale
                spacing: 4 * Appearance.effectiveScale

                Item { Layout.fillHeight: true }

                StyledText {
                    text: root.currentTime
                    Layout.alignment: Qt.AlignHCenter
                    font.family: Appearance.font.family.main
                    font.pixelSize: Math.round(64 * Appearance.effectiveScale)
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: AlarmService.message !== "" ? AlarmService.message : I18nService.tr("Alarm")
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    font.pixelSize: Math.round(15 * Appearance.effectiveScale)
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.preferredHeight: 8 * Appearance.effectiveScale }

                // --- Snooze / Stop buttons (M3 button large: 96h, 48h-padding, 24 text, 2 gap) ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2 * Appearance.effectiveScale

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 96 * Appearance.effectiveScale
                        buttonRadius: 48 * Appearance.effectiveScale
                        colBackground: Appearance.m3colors.m3secondaryContainer
                        colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSecondaryContainer, 0.12)
                        onClicked: AlarmService.snooze()

                        StyledText {
                            anchors.centerIn: parent
                            text: I18nService.tr("Snooze")
                            font.pixelSize: 24 * Appearance.effectiveScale
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 96 * Appearance.effectiveScale
                        buttonRadius: 48 * Appearance.effectiveScale
                        colBackground: Appearance.m3colors.m3tertiaryContainer
                        colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.12)
                        onClicked: AlarmService.stop()

                        StyledText {
                            anchors.centerIn: parent
                            text: I18nService.tr("Stop")
                            font.pixelSize: 24 * Appearance.effectiveScale
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onTertiaryContainer
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
