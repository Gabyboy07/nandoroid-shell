import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../core"
import "../../core/functions" as Functions
import "../../widgets"
import "../../services"

Item {
    id: root

    property string inputDigits: ""
    
    // Convert current inputDigits (e.g. "1234" -> 12m 34s) to string "HHh MMm SSs"
    readonly property string inputDisplay: {
        if (TimerService.active) return "";
        let padded = inputDigits.padStart(6, '0');
        let h = padded.substring(0, 2);
        let m = padded.substring(2, 4);
        let s = padded.substring(4, 6);
        return h + "h " + m + "m " + s + "s";
    }
    
    function parseInputToSeconds() {
        let padded = inputDigits.padStart(6, '0');
        let h = parseInt(padded.substring(0, 2)) || 0;
        let m = parseInt(padded.substring(2, 4)) || 0;
        let s = parseInt(padded.substring(4, 6)) || 0;
        return (h * 3600) + (m * 60) + s;
    }

    function appendDigit(d) {
        if (inputDigits.length < 6) {
            if (inputDigits === "" && (d === "0" || d === "00")) return;
            inputDigits += d;
            if (inputDigits.length > 6) inputDigits = inputDigits.substring(inputDigits.length - 6);
        }
    }

    function backspace() {
        if (inputDigits.length > 0) {
            inputDigits = inputDigits.substring(0, inputDigits.length - 1);
        }
    }

    // ── INPUT PAGE ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16 * Appearance.effectiveScale
        visible: !TimerService.active && TimerService.remainingMs === TimerService.setSeconds * 1000 && !TimerService.overflowing
        
        Item { Layout.fillHeight: true }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.inputDisplay
            font.pixelSize: 32 * Appearance.effectiveScale
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
        }

        Item { Layout.fillHeight: true }

        // Numpad
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            columnSpacing: 12 * Appearance.effectiveScale
            rowSpacing: 12 * Appearance.effectiveScale

            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "DEL"]
                delegate: RippleButton {
                    implicitWidth: 72 * Appearance.effectiveScale
                    implicitHeight: 40 * Appearance.effectiveScale
                    buttonRadius: 20 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainerHigh
                    
                    onClicked: {
                        if (modelData === "DEL") backspace();
                        else appendDigit(modelData);
                    }

                    contentItem: Item {
                        anchors.fill: parent
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: modelData === "DEL"
                            text: "backspace"
                            iconSize: 20 * Appearance.effectiveScale
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: modelData !== "DEL"
                            text: modelData
                            font.pixelSize: 18 * Appearance.effectiveScale
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Start Button
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 72 * Appearance.effectiveScale
            implicitHeight: 40 * Appearance.effectiveScale
            buttonRadius: 20 * Appearance.effectiveScale
            colBackground: Appearance.m3colors.m3primary
            
            onClicked: {
                let secs = parseInputToSeconds();
                if (secs > 0) {
                    TimerService.setDuration(secs);
                    TimerService.start();
                    root.inputDigits = "";
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "play_arrow"
                iconSize: 24 * Appearance.effectiveScale
                color: Appearance.m3colors.m3onPrimary
            }
        }
    }

    // ── RUNNING / PAUSED PAGE ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16 * Appearance.effectiveScale
        visible: TimerService.active || TimerService.remainingMs !== TimerService.setSeconds * 1000 || TimerService.overflowing

        Item { Layout.fillHeight: true }

        // Arc Ring
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 200 * Appearance.effectiveScale
            implicitHeight: 200 * Appearance.effectiveScale

            Canvas {
                id: bgRing
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const cx = width / 2, cy = height / 2;
                    const r = Math.min(cx, cy) - 10 * Appearance.effectiveScale;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.strokeStyle = Appearance.m3colors.m3surfaceVariant;
                    ctx.lineWidth = 10 * Appearance.effectiveScale;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }
                Connections {
                    target: Appearance
                    function onM3colorsChanged() { bgRing.requestPaint(); }
                }
            }

            Canvas {
                id: arcCanvas
                anchors.fill: parent
                readonly property real progress: TimerService.progress
                onProgressChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (progress <= 0) return;

                    const cx = width / 2, cy = height / 2;
                    const r = Math.min(cx, cy) - 10 * Appearance.effectiveScale;
                    const start = -Math.PI / 2;
                    const end = start + progress * Math.PI * 2;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, end);
                    ctx.strokeStyle = TimerService.isNegative ? Appearance.m3colors.m3error : Appearance.m3colors.m3primary;
                    ctx.lineWidth = 10 * Appearance.effectiveScale;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }
                Connections {
                    target: Appearance
                    function onM3colorsChanged() { arcCanvas.requestPaint(); }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4 * Appearance.effectiveScale

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.timeString
                    font.pixelSize: 48 * Appearance.effectiveScale
                    font.weight: Font.DemiBold
                    font.family: Appearance.font.family.numbers
                    font.features: { "tnum": 1 }
                    color: TimerService.isNegative ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Controls
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 16 * Appearance.effectiveScale

            // +1:00 Button (Optional)
            RippleButton {
                implicitWidth: 104 * Appearance.effectiveScale
                implicitHeight: 64 * Appearance.effectiveScale
                buttonRadius: 32 * Appearance.effectiveScale
                colBackground: Appearance.m3colors.m3surfaceContainerHigh
                onClicked: TimerService.addMinute()

                StyledText {
                    anchors.centerIn: parent
                    text: "+1:00"
                    font.pixelSize: 16 * Appearance.effectiveScale
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
            }

            // Stop / Delete
            RippleButton {
                implicitWidth: 64 * Appearance.effectiveScale
                implicitHeight: 64 * Appearance.effectiveScale
                buttonRadius: 32 * Appearance.effectiveScale
                colBackground: Appearance.m3colors.m3surfaceContainerHigh
                onClicked: TimerService.stop()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "stop"
                    iconSize: 24 * Appearance.effectiveScale
                    color: Appearance.colors.colOnLayer1
                }
            }

            // Pause / Resume
            RippleButton {
                implicitWidth: 104 * Appearance.effectiveScale
                implicitHeight: 64 * Appearance.effectiveScale
                buttonRadius: 32 * Appearance.effectiveScale
                colBackground: TimerService.active ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3primary
                
                onClicked: {
                    if (TimerService.active) {
                        TimerService.pause();
                    } else {
                        TimerService.start();
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: TimerService.active ? "pause" : "play_arrow"
                    iconSize: 24 * Appearance.effectiveScale
                    color: TimerService.active ? Appearance.colors.colOnLayer1 : Appearance.m3colors.m3onPrimary
                }
            }
        }
    }
}
