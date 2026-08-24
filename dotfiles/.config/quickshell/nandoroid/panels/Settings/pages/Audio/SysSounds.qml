import "../../../../core"
import "../../../../services"
import "../../../../widgets"
import "../../../../core/functions" as Functions
import "."
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 4 * Appearance.effectiveScale

    SearchHandler {
        searchString: "Sounds"
        aliases: ["Notification Sound", "Ringtone", "Alarm", "Audio Theme", "Suara", "Notifikasi"]
    }

    RowLayout {
        spacing: 12 * Appearance.effectiveScale
        Layout.bottomMargin: 8 * Appearance.effectiveScale
        MaterialSymbol {
            text: "music_note"
            iconSize: 24 * Appearance.effectiveScale
            color: Appearance.colors.colPrimary
        }
        StyledText {
            text: I18nService.tr("Sounds")
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
        }
    }

    readonly property string notificationSound: (Config.ready && Config.options.sounds) ? Config.options.sounds.notification : ""
    readonly property string ringtoneSound: (Config.ready && Config.options.sounds) ? Config.options.sounds.ringtone : ""
    property string previewing: "" // "notification" | "ringtone" | ""

    function _baseName(path) { return path.split("/").pop() || path; }

    // Resolve .oga/.ogg at runtime for theme defaults (oxygen ships only .ogg)
    function previewCommand(kind) {
        const custom = kind === "notification" ? root.notificationSound : root.ringtoneSound;
        if (custom !== "") return ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", custom];
        const name = kind === "notification" ? "message-new-instant" : "alarm-clock-elapsed";
        const base = `/usr/share/sounds/${Audio.audioTheme}/stereo/${name}`;
        return ["bash", "-c", `f='${base}.oga'; [ -f "$f" ] || f='${base}.ogg'; exec ffplay -nodisp -autoexit -loglevel quiet "$f"`];
    }

    // Toggle preview: play once, or stop the running one so sounds never stack
    function togglePreview(kind) {
        if (root.previewing === kind) {
            previewProc.running = false;
            root.previewing = "";
            return;
        }
        root.previewing = kind;
        previewProc.command = root.previewCommand(kind);
        previewProc.running = true;
    }

    Process {
        id: previewProc
        command: []
        onExited: root.previewing = ""
    }

    // ── Sound Theme Card ──
    SegmentedWrapper {
        id: themeCard
        Layout.fillWidth: true
        implicitHeight: themeRow.implicitHeight + (24 * Appearance.effectiveScale)
        orientation: Qt.Vertical
        maxRadius: 20 * Appearance.effectiveScale
        color: Appearance.m3colors.m3surfaceContainerHigh

        // Card-wide click toggles the dropdown (same pattern as SysLanguage)
        RippleButton {
            id: themeClickArea
            anchors.fill: parent
            colBackground: Appearance.m3colors.m3surfaceContainerHigh
            colBackgroundHover: Appearance.m3colors.m3surfaceContainerHigh
            buttonRadius: 0
            topLeftRadius: themeCard.rTopLeft
            topRightRadius: themeCard.rTopRight
            bottomLeftRadius: themeCard.rBottomLeft
            bottomRightRadius: themeCard.rBottomRight

            property real comboClosedAt: 0

            onClicked: {
                if (Date.now() - comboClosedAt < 250) return;
                themeCombo.isOpened = !themeCombo.isOpened;
            }

            Connections {
                target: themeCombo
                function onIsOpenedChanged() {
                    if (!themeCombo.isOpened) themeClickArea.comboClosedAt = Date.now();
                }
            }

            StyledToolTip {
                extraVisibleCondition: themeClickArea.hovered || themeClickArea.realHovered
                text: I18nService.tr("System sounds source (/usr/share/sounds)")
            }
        }

        RowLayout {
            id: themeRow
            anchors.fill: parent
            anchors {
                leftMargin: 16 * Appearance.effectiveScale
                rightMargin: 16 * Appearance.effectiveScale
                topMargin: 12 * Appearance.effectiveScale
                bottomMargin: 12 * Appearance.effectiveScale
            }
            spacing: 16 * Appearance.effectiveScale

            MaterialSymbol { Layout.alignment: Qt.AlignVCenter; text: "palette"; iconSize: 24 * Appearance.effectiveScale; color: Appearance.colors.colPrimary }

            StyledText {
                text: I18nService.tr("Sound Theme")
                color: Appearance.colors.colOnLayer1
                Layout.fillWidth: true
            }

            StyledComboBox {
                id: themeCombo
                Layout.preferredWidth: 220 * Appearance.effectiveScale
                Layout.alignment: Qt.AlignVCenter
                bgRadius: height / 2
                searchable: false
                placeholder: ""
                model: themeListProc.output
                text: (Config.ready && Config.options.sounds) ? Config.options.sounds.theme : "freedesktop"
                onAccepted: (val) => {
                    if (Config.ready && Config.options.sounds) Config.options.sounds.theme = val;
                }
            }
        }
    }

    // ── Notification Sound Card ──
    SegmentedWrapper {
        Layout.fillWidth: true
        implicitHeight: notifRow.implicitHeight + (24 * Appearance.effectiveScale)
        orientation: Qt.Vertical
        maxRadius: 20 * Appearance.effectiveScale
        color: Appearance.m3colors.m3surfaceContainerHigh

        RowLayout {
            id: notifRow
            anchors.fill: parent
            anchors {
                leftMargin: 16 * Appearance.effectiveScale
                rightMargin: 16 * Appearance.effectiveScale
                topMargin: 12 * Appearance.effectiveScale
                bottomMargin: 12 * Appearance.effectiveScale
            }
            spacing: 16 * Appearance.effectiveScale

            MaterialSymbol { Layout.alignment: Qt.AlignVCenter; text: "notifications"; iconSize: 24 * Appearance.effectiveScale; color: Appearance.colors.colPrimary }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                StyledText {
                    text: I18nService.tr("Notification Sound")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.notificationSound !== "" ? root._baseName(root.notificationSound) : I18nService.tr("Theme default")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            M3IconButton {
                iconName: root.previewing === "notification" ? "stop" : "play_arrow"
                iconSize: 20 * Appearance.effectiveScale
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                color: Appearance.colors.colOnPrimary
                onClicked: root.togglePreview("notification")
            }

            M3IconButton {
                iconName: "folder_open"
                iconSize: 20 * Appearance.effectiveScale
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                color: Appearance.colors.colOnPrimary
                onClicked: soundPickerProc.open("notification")
            }

            M3IconButton {
                visible: root.notificationSound !== ""
                iconName: "restart_alt"
                iconSize: 20 * Appearance.effectiveScale
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: "transparent"
                color: Appearance.colors.colError
                onClicked: if (Config.ready) Config.options.sounds.notification = ""
            }
        }
    }

    // ── Ringtone / Alarm Sound Card ──
    SegmentedWrapper {
        Layout.fillWidth: true
        implicitHeight: ringRow.implicitHeight + (24 * Appearance.effectiveScale)
        orientation: Qt.Vertical
        maxRadius: 20 * Appearance.effectiveScale
        color: Appearance.m3colors.m3surfaceContainerHigh

        RowLayout {
            id: ringRow
            anchors.fill: parent
            anchors {
                leftMargin: 16 * Appearance.effectiveScale
                rightMargin: 16 * Appearance.effectiveScale
                topMargin: 12 * Appearance.effectiveScale
                bottomMargin: 12 * Appearance.effectiveScale
            }
            spacing: 16 * Appearance.effectiveScale

            MaterialSymbol { Layout.alignment: Qt.AlignVCenter; text: "alarm"; iconSize: 24 * Appearance.effectiveScale; color: Appearance.colors.colPrimary }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                StyledText {
                    text: I18nService.tr("Ringtone & Alarm")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.ringtoneSound !== "" ? root._baseName(root.ringtoneSound) : I18nService.tr("Theme default")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            M3IconButton {
                iconName: root.previewing === "ringtone" ? "stop" : "play_arrow"
                iconSize: 20 * Appearance.effectiveScale
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                color: Appearance.colors.colOnPrimary
                onClicked: root.togglePreview("ringtone")
            }

            M3IconButton {
                iconName: "folder_open"
                iconSize: 20 * Appearance.effectiveScale
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                color: Appearance.colors.colOnPrimary
                onClicked: soundPickerProc.open("ringtone")
            }

            M3IconButton {
                visible: root.ringtoneSound !== ""
                iconName: "restart_alt"
                iconSize: 20 * Appearance.effectiveScale
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: "transparent"
                color: Appearance.colors.colError
                onClicked: if (Config.ready) Config.options.sounds.ringtone = ""
            }
        }
    }

    // ── File picker (zenity) ──
    Process {
        id: soundPickerProc
        property string target: "notification"
        function open(which) {
            soundPickerProc.target = which;
            soundPickerProc.running = true;
        }
        command: [
            "zenity", "--file-selection", "--title=Select Sound",
            "--file-filter=Audio | *.oga *.ogg *.wav *.mp3 *.flac *.m4a",
            "--file-filter=All files | *"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim();
                if (path === "" || !Config.ready || !Config.options.sounds) return;
                if (soundPickerProc.target === "ringtone") Config.options.sounds.ringtone = path;
                else Config.options.sounds.notification = path;
            }
        }
    }

    // ── Available sound themes ──
    Process {
        id: themeListProc
        property var output: ["freedesktop"]
        // NOTE: plain string (not template literal) — ${d} must reach bash verbatim
        command: ["bash", "-c", "for d in /usr/share/sounds/*/; do [ -d \"${d}stereo\" ] && basename \"$d\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(l => l.trim()).filter(l => l !== "");
                if (lines.length > 0) themeListProc.output = lines;
            }
        }
    }
}
