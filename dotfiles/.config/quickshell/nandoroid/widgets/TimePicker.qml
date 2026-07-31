pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import "../core"
import "../widgets"

Item {
    id: root

    property string currentTimeStr: ""
    property bool is24Hour: false

    signal timeSelected(string timeStr)
    signal cancelled()

    // 0 = Dial, 1 = Keyboard/Input
    property int selectMode: 0
    // 0 = Hour, 1 = Minute
    property int activeField: 0

    property int selectedHour: 7
    property int selectedMinute: 0
    property string amPm: "AM"

    readonly property real dialSize: 256 * Appearance.effectiveScale
    readonly property real dialCenter: 128 * Appearance.effectiveScale
    readonly property real knobRadius: 24 * Appearance.effectiveScale
    readonly property real dialRadius: dialCenter - knobRadius

    // Target Knob Angle (0..360)
    readonly property real knobAngleDeg: root.activeField === 0 ?
        ((root.selectedHour % 12) * 30) :
        (root.selectedMinute * 6)

    // Shortest-path continuous rotation angle
    property real handRotation: 0

    onKnobAngleDegChanged: root.updateShortestRotation()
    onActiveFieldChanged: root.updateShortestRotation()

    function updateShortestRotation() {
        let current = root.handRotation
        let currentNorm = (current % 360 + 360) % 360
        let target = root.knobAngleDeg
        let diff = (target - currentNorm + 540) % 360 - 180
        root.handRotation = current + diff
    }

    // Calculated Knob Center Position
    readonly property real knobAngleRad: (handRotation - 90) * Math.PI / 180
    readonly property real currentKnobX: dialCenter + dialRadius * Math.cos(knobAngleRad)
    readonly property real currentKnobY: dialCenter + dialRadius * Math.sin(knobAngleRad)

    implicitWidth: Math.max(300 * Appearance.effectiveScale, 364 * Appearance.effectiveScale)
    implicitHeight: contentCol.implicitHeight

    Component.onCompleted: root.parseInitialTime()

    onCurrentTimeStrChanged: root.parseInitialTime()

    function parseInitialTime() {
        if (!root.currentTimeStr || root.currentTimeStr.trim() === "") {
            const d = new Date()
            let h = d.getHours()
            let m = d.getMinutes()
            if (!root.is24Hour) {
                root.amPm = h >= 12 ? "PM" : "AM"
                h = h % 12
                if (h === 0) h = 12
            }
            root.selectedHour = h
            root.selectedMinute = m
            root.handRotation = root.knobAngleDeg
            return
        }

        let str = root.currentTimeStr.trim()
        let isPm = false
        if (str.toUpperCase().endsWith("PM")) {
            isPm = true
            str = str.substring(0, str.length - 2).trim()
        } else if (str.toUpperCase().endsWith("AM")) {
            isPm = false
            str = str.substring(0, str.length - 2).trim()
        }

        // Support both ':' and '.' as time separator (e.g. "17.05" or "17:05")
        const cleanStr = str.replace('.', ':')
        const parts = cleanStr.split(":")
        if (parts.length >= 2) {
            let h = parseInt(parts[0], 10) || 0
            let m = parseInt(parts[1], 10) || 0
            if (!root.is24Hour) {
                if (isPm) {
                    if (h < 12) h += 0
                } else {
                    if (h >= 12) {
                        isPm = true
                        if (h > 12) h -= 12
                    } else if (h === 0) {
                        h = 12
                    }
                }
                root.amPm = isPm ? "PM" : "AM"
            }
            root.selectedHour = h
            root.selectedMinute = Math.min(59, Math.max(0, m))
            root.handRotation = root.knobAngleDeg
        }
    }

    function getFormattedTime() {
        let h = root.selectedHour
        let m = String(root.selectedMinute).padStart(2, '0')
        if (!root.is24Hour) {
            if (root.amPm === "PM" && h < 12) h += 12
            else if (root.amPm === "AM" && h === 12) h = 0
        }
        let hStr = String(h).padStart(2, '0')
        return hStr + ":" + m
    }

    function confirm() {
        root.timeSelected(root.getFormattedTime())
    }

    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.card
        color: Appearance.m3colors.m3surfaceContainerHigh
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        spacing: 0

        // Header Title
        StyledText {
            text: root.selectMode === 0 ? "Select time" : "Enter time"
            Layout.leftMargin: 24 * Appearance.effectiveScale
            Layout.topMargin: 24 * Appearance.effectiveScale
            Layout.bottomMargin: 24 * Appearance.effectiveScale
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.colors.colSubtext
        }

        // Time Display Area (Hours : Minutes + AM/PM)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: root.selectMode === 0 ? 28 * Appearance.effectiveScale : 20 * Appearance.effectiveScale
            spacing: 12 * Appearance.effectiveScale

            // Hour Box
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 6 * Appearance.effectiveScale
                Rectangle {
                    implicitWidth: 96 * Appearance.effectiveScale
                    implicitHeight: 80 * Appearance.effectiveScale
                    radius: 12 * Appearance.effectiveScale
                    color: root.activeField === 0 ? Appearance.m3colors.m3primaryContainer : Appearance.colors.colLayer2
                    border.width: (root.selectMode === 1 && root.activeField === 0) ? 2 * Appearance.effectiveScale : 0
                    border.color: Appearance.colors.colPrimary

                    StyledTextInput {
                        id: hourInput
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: String(root.selectedHour).padStart(2, '0')
                        font.pixelSize: Math.round(48 * Appearance.effectiveScale)
                        font.weight: Font.Normal
                        color: root.activeField === 0 ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colOnLayer1
                        readOnly: root.selectMode === 0
                        inputMask: "99"
                        backgroundColor: "transparent"
                        inputRadius: 0
                        borderInactiveWidth: 0
                        showActiveBorder: false
                        leftMargin: 0
                        rightMargin: 0

                        onTextChanged: {
                            if (root.selectMode === 1 && input.activeFocus) {
                                let val = parseInt(text, 10)
                                if (!isNaN(val)) {
                                    if (root.is24Hour) {
                                        root.selectedHour = Math.min(23, Math.max(0, val))
                                    } else {
                                        root.selectedHour = Math.min(12, Math.max(1, val))
                                    }
                                }
                            }
                        }

                        Connections {
                            target: hourInput.input
                            function onActiveFocusChanged() {
                                if (hourInput.input.activeFocus) root.activeField = 0
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectMode === 0
                        onClicked: root.activeField = 0
                    }
                }
                StyledText {
                    visible: root.selectMode === 1
                    text: "Hour"
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 4 * Appearance.effectiveScale
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // Colon Separator
            StyledText {
                text: ":"
                font.pixelSize: Math.round(48 * Appearance.effectiveScale)
                font.weight: Font.Normal
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 12 * Appearance.effectiveScale
            }

            // Minute Box
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 6 * Appearance.effectiveScale
                Rectangle {
                    implicitWidth: 96 * Appearance.effectiveScale
                    implicitHeight: 80 * Appearance.effectiveScale
                    radius: 12 * Appearance.effectiveScale
                    color: root.activeField === 1 ? Appearance.m3colors.m3primaryContainer : Appearance.colors.colLayer2
                    border.width: (root.selectMode === 1 && root.activeField === 1) ? 2 * Appearance.effectiveScale : 0
                    border.color: Appearance.colors.colPrimary

                    StyledTextInput {
                        id: minuteInput
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: String(root.selectedMinute).padStart(2, '0')
                        font.pixelSize: Math.round(48 * Appearance.effectiveScale)
                        font.weight: Font.Normal
                        color: root.activeField === 1 ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colOnLayer1
                        readOnly: root.selectMode === 0
                        inputMask: "99"
                        backgroundColor: "transparent"
                        inputRadius: 0
                        borderInactiveWidth: 0
                        showActiveBorder: false
                        leftMargin: 0
                        rightMargin: 0

                        onTextChanged: {
                            if (root.selectMode === 1 && input.activeFocus) {
                                let val = parseInt(text, 10)
                                if (!isNaN(val)) {
                                    root.selectedMinute = Math.min(59, Math.max(0, val))
                                }
                            }
                        }

                        Connections {
                            target: minuteInput.input
                            function onActiveFocusChanged() {
                                if (minuteInput.input.activeFocus) root.activeField = 1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectMode === 0
                        onClicked: root.activeField = 1
                    }
                }
                StyledText {
                    visible: root.selectMode === 1
                    text: "Minute"
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 4 * Appearance.effectiveScale
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // AM/PM Vertical Segmented Toggle Button
            Rectangle {
                visible: !root.is24Hour
                Layout.alignment: Qt.AlignTop
                implicitWidth: 52 * Appearance.effectiveScale
                implicitHeight: 80 * Appearance.effectiveScale
                radius: 12 * Appearance.effectiveScale
                color: Appearance.colors.colLayer2
                border.width: 1 * Appearance.effectiveScale
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // AM Button
                    Rectangle {
                        id: amRect
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        topLeftRadius: 11 * Appearance.effectiveScale
                        topRightRadius: 11 * Appearance.effectiveScale
                        bottomLeftRadius: 0
                        bottomRightRadius: 0

                        readonly property bool isSelected: root.amPm === "AM"
                        readonly property bool isHovered: amMouseArea.containsMouse

                        color: isSelected ? Appearance.m3colors.m3tertiaryContainer :
                            (isHovered ? Appearance.colors.colLayer2Hover : "transparent")

                        MouseArea {
                            id: amMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.amPm = "AM"
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: "AM"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: parent.isSelected ? Appearance.m3colors.m3onTertiaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1 * Appearance.effectiveScale
                        color: Appearance.colors.colOutlineVariant
                    }

                    // PM Button
                    Rectangle {
                        id: pmRect
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        topLeftRadius: 0
                        topRightRadius: 0
                        bottomLeftRadius: 11 * Appearance.effectiveScale
                        bottomRightRadius: 11 * Appearance.effectiveScale

                        readonly property bool isSelected: root.amPm === "PM"
                        readonly property bool isHovered: pmMouseArea.containsMouse

                        color: isSelected ? Appearance.m3colors.m3tertiaryContainer :
                            (isHovered ? Appearance.colors.colLayer2Hover : "transparent")

                        MouseArea {
                            id: pmMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.amPm = "PM"
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: "PM"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: parent.isSelected ? Appearance.m3colors.m3onTertiaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        // Clock Dial View (Mode 0)
        Item {
            visible: root.selectMode === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 24 * Appearance.effectiveScale
            implicitWidth: root.dialSize
            implicitHeight: root.dialSize

            // Dial Circle Background
            Rectangle {
                id: dialBackground
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.colLayer2

                MouseArea {
                    id: dialMouseArea
                    anchors.fill: parent
                    preventStealing: true

                    function handleMouse(mx, my, isRelease) {
                        const cx = width / 2
                        const cy = height / 2
                        const dx = mx - cx
                        const dy = my - cy

                        let rad = Math.atan2(dy, dx)
                        let deg = rad * 180 / Math.PI
                        if (deg < 0) deg += 360
                        let topDeg = (deg + 90) % 360

                        if (root.activeField === 0) {
                            let h = Math.round(topDeg / 30)
                            if (h === 0) h = 12
                            root.selectedHour = h
                            if (isRelease) {
                                root.activeField = 1
                            }
                        } else {
                            let m = Math.round(topDeg / 6) % 60
                            root.selectedMinute = m
                        }
                    }

                    onPressed: mouse => handleMouse(mouse.x, mouse.y, false)
                    onPositionChanged: mouse => handleMouse(mouse.x, mouse.y, false)
                    onReleased: mouse => handleMouse(mouse.x, mouse.y, true)
                }

                // Center Pin
                Rectangle {
                    width: 6 * Appearance.effectiveScale
                    height: 6 * Appearance.effectiveScale
                    radius: width / 2
                    color: Appearance.colors.colPrimary
                    anchors.centerIn: parent
                    z: 5
                }

                // ── LAYER 1: Base Dial Numbers (Gray Text) ──
                Repeater {
                    model: 12

                    delegate: Item {
                        required property int index
                        readonly property int val: root.activeField === 0 ? (index === 0 ? 12 : index) : (index * 5)
                        readonly property string displayStr: root.activeField === 0 ? val.toString() : String(val).padStart(2, '0')

                        readonly property real angleRad: (index * 30 - 90) * Math.PI / 180
                        readonly property real numX: root.dialCenter + root.dialRadius * Math.cos(angleRad)
                        readonly property real numY: root.dialCenter + root.dialRadius * Math.sin(angleRad)

                        x: numX - width / 2
                        y: numY - height / 2
                        width: root.knobRadius * 2
                        height: root.knobRadius * 2
                        z: 2

                        StyledText {
                            anchors.centerIn: parent
                            text: parent.displayStr
                            font.pixelSize: Math.round(16 * Appearance.effectiveScale)
                            font.weight: Font.Normal
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                // ── LAYER 2: Hand Indicator & Primary Knob Disc ──
                Item {
                    id: handIndicator
                    anchors.centerIn: parent
                    width: 0
                    height: 0
                    z: 3

                    rotation: root.handRotation

                    Behavior on rotation {
                        enabled: !dialMouseArea.pressed
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    // Anti-aliased Smooth Vector Line for Hand Indicator
                    Shape {
                        anchors.centerIn: parent
                        width: 0
                        height: 0
                        antialiasing: true

                        ShapePath {
                            strokeColor: Appearance.colors.colPrimary
                            strokeWidth: 2 * Appearance.effectiveScale
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathLine { x: 0; y: 0 }
                            PathLine { x: 0; y: -root.dialRadius }
                        }
                    }

                    // Highlight Knob Disc (48px primary circle)
                    Rectangle {
                        x: -root.knobRadius
                        y: -root.dialRadius - root.knobRadius
                        width: root.knobRadius * 2
                        height: root.knobRadius * 2
                        radius: root.knobRadius
                        color: Appearance.colors.colPrimary
                        antialiasing: true
                    }
                }

                // ── LAYER 3: Circular Clipped Contrast Overlay (Half-and-Half Split Effect) ──
                Item {
                    id: knobClippedContainer
                    x: root.currentKnobX - root.knobRadius
                    y: root.currentKnobY - root.knobRadius
                    width: root.knobRadius * 2
                    height: root.knobRadius * 2
                    z: 4

                    Item {
                        id: contrastContent
                        anchors.fill: parent
                        visible: false

                        Repeater {
                            model: 12

                            delegate: Item {
                                required property int index
                                readonly property int val: root.activeField === 0 ? (index === 0 ? 12 : index) : (index * 5)
                                readonly property string displayStr: root.activeField === 0 ? val.toString() : String(val).padStart(2, '0')

                                readonly property real angleRad: (index * 30 - 90) * Math.PI / 180
                                readonly property real numX: root.dialCenter + root.dialRadius * Math.cos(angleRad)
                                readonly property real numY: root.dialCenter + root.dialRadius * Math.sin(angleRad)

                                x: (numX - root.currentKnobX + root.knobRadius) - width / 2
                                y: (numY - root.currentKnobY + root.knobRadius) - height / 2
                                width: root.knobRadius * 2
                                height: root.knobRadius * 2

                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.displayStr
                                    font.pixelSize: Math.round(16 * Appearance.effectiveScale)
                                    font.weight: Font.Normal
                                    color: Appearance.m3colors.m3onPrimary
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: contrastMask
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: contrastContent
                        maskSource: contrastMask
                    }
                }
            }
        }

        // Bottom Action Bar (Toggle icon + Cancel / OK buttons)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24 * Appearance.effectiveScale
            Layout.rightMargin: 24 * Appearance.effectiveScale
            Layout.bottomMargin: 24 * Appearance.effectiveScale
            Layout.topMargin: 12 * Appearance.effectiveScale
            spacing: 8 * Appearance.effectiveScale

            // Switch Mode Button (Keyboard <-> Clock Dial)
            RippleButton {
                implicitWidth: 40 * Appearance.effectiveScale
                implicitHeight: 40 * Appearance.effectiveScale
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: {
                    root.selectMode = root.selectMode === 0 ? 1 : 0
                    if (root.selectMode === 1) {
                        hourInput.forceActiveFocus()
                    }
                }
                contentItem: MaterialSymbol {
                    text: root.selectMode === 0 ? "keyboard" : "schedule"
                    iconSize: 22 * Appearance.effectiveScale
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }

            Item { Layout.fillWidth: true }

            // Cancel Button
            RippleButton {
                implicitHeight: 40 * Appearance.effectiveScale
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.cancelled()
                contentItem: StyledText {
                    text: "Cancel"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colPrimary
                }
            }

            // OK Button
            RippleButton {
                implicitHeight: 40 * Appearance.effectiveScale
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.confirm()
                contentItem: StyledText {
                    text: "OK"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colPrimary
                }
            }
        }
    }
}
