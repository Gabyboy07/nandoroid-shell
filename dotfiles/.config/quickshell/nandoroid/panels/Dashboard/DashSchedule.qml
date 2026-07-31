import "../../core"
import "../../widgets"
import "../../services"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * Dashboard Tab 2: Schedule / Calendar Maker
 * Local JSON storage, recurring events.
 */
Item {
    id: root

    // ── State ──
    property string selectedId: ""
    property string formTitle: ""
    function _formatDateObj(d) {
        if (!d) return ""
        let y = d.getFullYear(), m = d.getMonth() + 1, day = d.getDate()
        const ys = String(y).padStart(4, '0')
        const ms = String(m).padStart(2, '0')
        const ds = String(day).padStart(2, '0')
        let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY"
        if (style === "YMD") return ys + "/" + ms + "/" + ds
        if (style === "MDY") return ms + "/" + ds + "/" + ys
        return ds + "/" + ms + "/" + ys
    }

    function _formatDateByConfig(dStr) {
        if (!dStr) return ""
        let parts = dStr.trim().split(/[-/]/).map(Number)
        if (parts.length < 3 || parts.some(isNaN)) return dStr
        let y, m, d
        if (parts[0] > 1000) { y = parts[0]; m = parts[1]; d = parts[2] }
        else if (parts[2] > 1000) {
            let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY"
            if (style === "MDY") { m = parts[0]; d = parts[1]; y = parts[2] }
            else { d = parts[0]; m = parts[1]; y = parts[2] }
        } else return dStr

        const ys = String(y).padStart(4, '0')
        const ms = String(m).padStart(2, '0')
        const ds = String(d).padStart(2, '0')
        let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY"
        if (style === "YMD") return ys + "/" + ms + "/" + ds
        if (style === "MDY") return ms + "/" + ds + "/" + ys
        return ds + "/" + ms + "/" + ys
    }

    function _defaultDateStr() {
        return _formatDateObj(new Date())
    }

    property string formDate: _defaultDateStr()
    property string formTime: "00:00"
    property string formEndTime: "01:00"
    property string formRecurrence: "once" // once | daily | weekly | monthly
    property string formEndDate: ""
    property string formDescription: ""
    property bool formFocus: false

    property int _multiDayDiff: {
        if (!formEndDate.trim() || formEndDate === formDate) return 0;
        const s = new Date(formDate + "T00:00:00");
        const e = new Date(formEndDate + "T00:00:00");
        return Math.round((e - s) / 86400000);
    }

    onFormEndDateChanged: {
        if (_multiDayDiff > 0 && formRecurrence !== "once")
            formRecurrence = "once";
    }

    property bool formDatesValid: {
        if (!root.formEndDate.trim()) return true;
        if (root.formEndDate < root.formDate) return false;
        if (root.formEndDate > root.formDate) return true;
        return root.formEndTime > root.formTime;
    }
    property string _datePickerTarget: ""

    function clearForm() {
        const now = new Date();
        let nextH = (now.getHours() + 1) % 24;
        let date = new Date(now);
        if (nextH <= now.getHours()) date.setDate(date.getDate() + 1);

        const nextHStr = String(nextH).padStart(2, '0') + ":00";
        const endH = (nextH + 1) % 24;
        const endHStr = String(endH).padStart(2, '0') + ":00";

        let endDate = new Date(date);
        if (endH <= nextH) endDate.setDate(endDate.getDate() + 1);

        formTitle = "";
        formDate = _formatDateObj(date);
        formTime = nextHStr;
        formEndTime = endHStr;
        formEndDate = _formatDateObj(endDate);
        formDescription = ""; formFocus = false
    }

    function deleteEvent(id) {
        ScheduleService.deleteEvent(id)
        if (selectedId === id) { selectedId = ""; clearForm() }
    }

    // Auto-save debounce for existing events
    Timer {
        id: autoSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!root.selectedId || !root.formTitle.trim()) return
            const descVal = root.formDescription.trim() ? root.formDescription.trim() : undefined
            const endDateVal = root.formEndDate.trim() && root.formEndDate !== root.formDate ? root.formEndDate.trim() : undefined
            ScheduleService.updateEvent(root.selectedId, {
                title: root.formTitle, 
                date: root.formDate, 
                time: root.formTime, 
                endTime: root.formEndTime,
                endDate: endDateVal,
                recurrence: root.formRecurrence, 
                description: descVal,
                focus: root.formFocus
            })
        }
    }

    function saveEvent() {
        if (!formTitle.trim()) return
        const descVal = formDescription.trim() ? formDescription.trim() : undefined
        const endDateVal = formEndDate.trim() && formEndDate !== formDate ? formEndDate.trim() : undefined
        if (selectedId) {
            ScheduleService.updateEvent(selectedId, { 
                title: formTitle, 
                date: formDate, 
                time: formTime, 
                endTime: formEndTime,
                endDate: endDateVal,
                recurrence: formRecurrence, 
                description: descVal,
                focus: formFocus
            })
        } else {
            const newEv = { 
                id: Date.now().toString(36), 
                title: formTitle, 
                date: formDate, 
                time: formTime, 
                endTime: formEndTime,
                endDate: endDateVal,
                recurrence: formRecurrence, 
                description: descVal, 
                focus: formFocus,
                lastFired: "" 
            }
            ScheduleService.addEvent(newEv)
        }
        selectedId = ""
        clearForm()
    }

    // ── Layout ──
    RowLayout {
        id: layoutRow
        anchors.fill: parent
        spacing: 12 * Appearance.effectiveScale

        // ── Event List (fixed width) ──
        ColumnLayout {
            id: schedSidebar
            Layout.preferredWidth: 200 * Appearance.effectiveScale
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            spacing: 8 * Appearance.effectiveScale

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 40 * Appearance.effectiveScale
                buttonRadius: 20 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                onClicked: { root.selectedId = ""; root.clearForm() }
                RowLayout {
                    anchors.centerIn: parent; spacing: 6 * Appearance.effectiveScale
                    MaterialSymbol { text: "add"; iconSize: 18 * Appearance.effectiveScale; color: Appearance.colors.colOnPrimary }
                    StyledText { text: "New Event"; color: Appearance.colors.colOnPrimary; font.weight: Font.Medium }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                clip: true

                ListView {
                    id: eventList
                    anchors.fill: parent
                    anchors.margins: 6 * Appearance.effectiveScale
                    spacing: 4 * Appearance.effectiveScale
                    model: ScheduleService.events.slice().sort((a, b) =>
                            (a.date + a.time).localeCompare(b.date + b.time))

                    delegate: Item {
                        required property var modelData
                        width: eventList.width
                        height: 48 * Appearance.effectiveScale

                        readonly property bool isSelected: root.selectedId === modelData.id
                        readonly property bool isHovered: delegateMouse.containsMouse
                        readonly property bool inDeleteZone: delegateMouse.containsMouse && delegateMouse._mx > width - 36 * Appearance.effectiveScale

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: isSelected
                                ? Appearance.colors.colPrimaryContainer
                                : (isHovered ? Appearance.m3colors.m3surfaceContainerHigh : "transparent")

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12 * Appearance.effectiveScale
                                anchors.rightMargin: 8 * Appearance.effectiveScale

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2 * Appearance.effectiveScale

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4 * Appearance.effectiveScale
                                        StyledText {
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.Medium
                                            color: isSelected
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : Appearance.colors.colOnLayer1
                                            Layout.fillWidth: true
                                        }
                                        MaterialSymbol {
                                            visible: modelData.focus || false
                                            text: "do_not_disturb_on"
                                            iconSize: 14 * Appearance.effectiveScale
                                            color: isSelected
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : Appearance.colors.colPrimary
                                        }
                                    }

                                    StyledText {
                                        text: {
                                            const r = modelData.recurrence
                                            const ed = modelData.endDate && modelData.endDate !== modelData.date ? " · End " + modelData.endDate : ""
                                            if (r === "daily") return "Daily" + ed
                                            if (r === "weekly") {
                                                const d = new Date(modelData.date + "T00:00:00")
                                                const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                                                return "Every " + days[d.getDay()] + ed
                                            }
                                            if (r === "monthly") {
                                                const d = new Date(modelData.date + "T00:00:00")
                                                const day = d.getDate()
                                                const suffix = day % 10 === 1 && day !== 11 ? "st" : day % 10 === 2 && day !== 12 ? "nd" : day % 10 === 3 && day !== 13 ? "rd" : "th"
                                                return "Every " + day + suffix + ed
                                            }
                                            let t = modelData.date + " " + modelData.time
                                            if (modelData.endTime) t += " - " + modelData.endTime
                                            return t + ed
                                        }
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                        Layout.fillWidth: true
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 24 * Appearance.effectiveScale
                                    implicitHeight: 24 * Appearance.effectiveScale
                                    radius: Appearance.rounding.small
                                    color: inDeleteZone ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconSize: 16 * Appearance.effectiveScale
                                        color: inDeleteZone ? Appearance.colors.colError : Appearance.colors.colSubtext
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: delegateMouse
                            property real _mx: 0
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => { _mx = mouse.x }
                            onClicked: (mouse) => {
                                if (mouse.x > parent.width - 36 * Appearance.effectiveScale) {
                                    root.deleteEvent(modelData.id)
                                    return
                                }

                                root.selectedId = ""
                                root.formTitle = modelData.title
                                root.formDate = root._formatDateByConfig(modelData.date)
                                root.formTime = modelData.time
                                root.formEndTime = modelData.endTime || ""
                                root.formEndDate = root._formatDateByConfig(modelData.endDate || "")
                                root.formRecurrence = modelData.recurrence
                                root.formDescription = modelData.description || ""
                                root.formFocus = modelData.focus || false
                                root.selectedId = modelData.id
                            }
                        }
                    }

                    ScrollBar.vertical: StyledScrollBar {}
                }
            }
        }

        // ── Event Editor ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12 * Appearance.effectiveScale

            // Header row with Focus toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * Appearance.effectiveScale
                StyledText {
                    text: root.selectedId ? "Edit Event" : "New Event"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 8 * Appearance.effectiveScale
                    MaterialSymbol {
                        text: "do_not_disturb_on"
                        iconSize: 18 * Appearance.effectiveScale
                        color: root.formFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: "Focus Mode"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.formFocus ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }
                    AndroidToggle {
                        checked: root.formFocus
                        color: checked ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHigh
                        onToggled: {
                            root.formFocus = !root.formFocus
                            if (root.selectedId) autoSaveTimer.restart()
                        }
                    }
                }
            }

            // Title field
            StyledTextInput {
                id: titleField
                Layout.fillWidth: true
                implicitHeight: 44 * Appearance.effectiveScale
                inputRadius: Appearance.rounding.small / Appearance.effectiveScale
                backgroundColor: Appearance.m3colors.m3surfaceContainer
                placeholder: "Event title..."
                text: root.formTitle
                onTextChanged: { root.formTitle = text; if(root.selectedId && titleField.input.activeFocus) autoSaveTimer.restart() }
            }

            // Start row: Start label + Start Date + Start Time
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                StyledText {
                    text: "Start"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 36 * Appearance.effectiveScale
                }

                Rectangle {
                    id: dateFieldRect
                    Layout.fillWidth: true; implicitHeight: 44 * Appearance.effectiveScale
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    border.color: dateField.input.activeFocus || root._datePickerTarget === "start" ? Appearance.colors.colPrimary : "transparent"
                    border.width: 2 * Appearance.effectiveScale
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10 * Appearance.effectiveScale; spacing: 6 * Appearance.effectiveScale
                        MaterialSymbol { text: "calendar_today"; iconSize: 16 * Appearance.effectiveScale; color: Appearance.colors.colSubtext }
                        StyledTextInput {
                            id: dateField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.formDate
                            placeholder: Config.ready && Config.options.time && Config.options.time.dateStyle === "YMD" ? "YYYY/MM/DD" : (Config.ready && Config.options.time && Config.options.time.dateStyle === "MDY" ? "MM/DD/YYYY" : "DD/MM/YYYY")
                            backgroundColor: "transparent"
                            inputRadius: 0
                            borderInactiveWidth: 0
                            showActiveBorder: false
                            leftMargin: 0
                            rightMargin: 0
                            property int _lastLen: 0
                            onTextChanged: {
                                if (dateField.input.activeFocus) {
                                    let isDeleting = text.length < _lastLen
                                    _lastLen = text.length
                                    let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY"
                                    let digits = text.replace(/\D/g, '').substring(0, 8)
                                    let formatted = text
                                    if (style === "YMD") {
                                        if (digits.length > 4 && digits.length <= 6) formatted = digits.substring(0, 4) + "/" + digits.substring(4)
                                        else if (digits.length > 6) formatted = digits.substring(0, 4) + "/" + digits.substring(4, 6) + "/" + digits.substring(6)
                                        else formatted = digits
                                    } else {
                                        if (digits.length > 2 && digits.length <= 4) formatted = digits.substring(0, 2) + "/" + digits.substring(2)
                                        else if (digits.length > 4) formatted = digits.substring(0, 2) + "/" + digits.substring(2, 4) + "/" + digits.substring(4)
                                        else formatted = digits
                                    }
                                    if (isDeleting && text.endsWith("/")) formatted = formatted.substring(0, formatted.length - 1)
                                    if (formatted !== text) text = formatted
                                }
                                root.formDate = text
                                if (root.selectedId && dateField.input.activeFocus) autoSaveTimer.restart()
                            }
                        }
                        RippleButton {
                            implicitWidth: 28 * Appearance.effectiveScale
                            implicitHeight: 28 * Appearance.effectiveScale
                            buttonRadius: 14 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: root.openDatePicker()
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "date_range"
                                iconSize: 16 * Appearance.effectiveScale
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44 * Appearance.effectiveScale
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    border.color: timeField.input.activeFocus || root._timePickerTarget === "start" ? Appearance.colors.colPrimary : "transparent"
                    border.width: 2 * Appearance.effectiveScale
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10 * Appearance.effectiveScale; spacing: 6 * Appearance.effectiveScale
                        MaterialSymbol { text: "schedule"; iconSize: 16 * Appearance.effectiveScale; color: Appearance.colors.colSubtext }
                        StyledTextInput {
                            id: timeField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.formTime
                            inputMask: "99:99"
                            backgroundColor: "transparent"
                            inputRadius: 0
                            borderInactiveWidth: 0
                            showActiveBorder: false
                            leftMargin: 0
                            rightMargin: 0
                            onTextChanged: { root.formTime = text; if(root.selectedId && timeField.input.activeFocus) autoSaveTimer.restart() }
                        }
                        RippleButton {
                            implicitWidth: 28 * Appearance.effectiveScale
                            implicitHeight: 28 * Appearance.effectiveScale
                            buttonRadius: 14 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: root.openStartTimePicker()
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "access_time"
                                iconSize: 16 * Appearance.effectiveScale
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            // End row: End label + End Date + End Time
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                StyledText {
                    text: "End"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 36 * Appearance.effectiveScale
                }

                Rectangle {
                    id: endDateFieldRect
                    Layout.fillWidth: true; implicitHeight: 44 * Appearance.effectiveScale
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    border.color: endDateField.input.activeFocus || root._datePickerTarget === "end" ? Appearance.colors.colPrimary : "transparent"
                    border.width: 2 * Appearance.effectiveScale
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10 * Appearance.effectiveScale; spacing: 6 * Appearance.effectiveScale
                        MaterialSymbol { text: "calendar_month"; iconSize: 16 * Appearance.effectiveScale; color: Appearance.colors.colSubtext }
                        StyledTextInput {
                            id: endDateField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.formEndDate
                            placeholder: Config.ready && Config.options.time && Config.options.time.dateStyle === "YMD" ? "YYYY/MM/DD" : (Config.ready && Config.options.time && Config.options.time.dateStyle === "MDY" ? "MM/DD/YYYY" : "DD/MM/YYYY")
                            backgroundColor: "transparent"
                            inputRadius: 0
                            borderInactiveWidth: 0
                            showActiveBorder: false
                            leftMargin: 0
                            rightMargin: 0
                            property int _lastLen: 0
                            onTextChanged: {
                                if (endDateField.input.activeFocus) {
                                    let isDeleting = text.length < _lastLen
                                    _lastLen = text.length
                                    let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY"
                                    let digits = text.replace(/\D/g, '').substring(0, 8)
                                    let formatted = text
                                    if (style === "YMD") {
                                        if (digits.length > 4 && digits.length <= 6) formatted = digits.substring(0, 4) + "/" + digits.substring(4)
                                        else if (digits.length > 6) formatted = digits.substring(0, 4) + "/" + digits.substring(4, 6) + "/" + digits.substring(6)
                                        else formatted = digits
                                    } else {
                                        if (digits.length > 2 && digits.length <= 4) formatted = digits.substring(0, 2) + "/" + digits.substring(2)
                                        else if (digits.length > 4) formatted = digits.substring(0, 2) + "/" + digits.substring(2, 4) + "/" + digits.substring(4)
                                        else formatted = digits
                                    }
                                    if (isDeleting && text.endsWith("/")) formatted = formatted.substring(0, formatted.length - 1)
                                    if (formatted !== text) text = formatted
                                }
                                root.formEndDate = text
                                if (root.selectedId && endDateField.input.activeFocus) autoSaveTimer.restart()
                            }
                        }
                        RippleButton {
                            implicitWidth: 28 * Appearance.effectiveScale
                            implicitHeight: 28 * Appearance.effectiveScale
                            buttonRadius: 14 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: root.openEndDatePicker()
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "date_range"
                                iconSize: 16 * Appearance.effectiveScale
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44 * Appearance.effectiveScale
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    border.color: endTimeField.input.activeFocus || root._timePickerTarget === "end" ? Appearance.colors.colPrimary : "transparent"
                    border.width: 2 * Appearance.effectiveScale
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10 * Appearance.effectiveScale; spacing: 6 * Appearance.effectiveScale
                        MaterialSymbol { text: "event_busy"; iconSize: 16 * Appearance.effectiveScale; color: Appearance.colors.colSubtext }
                        StyledTextInput {
                            id: endTimeField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.formEndTime
                            inputMask: "99:99"
                            backgroundColor: "transparent"
                            inputRadius: 0
                            borderInactiveWidth: 0
                            showActiveBorder: false
                            leftMargin: 0
                            rightMargin: 0
                            onTextChanged: { root.formEndTime = text; if(root.selectedId && endTimeField.input.activeFocus) autoSaveTimer.restart() }
                        }
                        RippleButton {
                            implicitWidth: 28 * Appearance.effectiveScale
                            implicitHeight: 28 * Appearance.effectiveScale
                            buttonRadius: 14 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: root.openEndTimePicker()
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "access_time"
                                iconSize: 16 * Appearance.effectiveScale
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: root.formEndDate.trim() && !root.formDatesValid
                text: "End must be later than start"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colError
            }

            // Description field — fills all remaining vertical space
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainer
                border.color: descArea.activeFocus ? Appearance.colors.colPrimary : "transparent"
                border.width: 2 * Appearance.effectiveScale
                clip: true

                Flickable {
                    id: descFlickable
                    anchors.fill: parent
                    anchors.margins: 12 * Appearance.effectiveScale
                    contentHeight: descArea.height
                    clip: true

                    TextEdit {
                        id: descArea
                        width: descFlickable.width
                        height: Math.max(implicitHeight, descFlickable.height)
                        text: root.formDescription
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        wrapMode: TextEdit.Wrap
                        onTextChanged: { root.formDescription = text; if(root.selectedId && descArea.activeFocus) autoSaveTimer.restart() }

                        onCursorRectangleChanged: {
                            const margin = 20 * Appearance.effectiveScale;
                            if (cursorRectangle.y < descFlickable.contentY)
                                descFlickable.contentY = cursorRectangle.y;
                            else if (cursorRectangle.y + cursorRectangle.height + margin > descFlickable.contentY + descFlickable.height)
                                descFlickable.contentY = cursorRectangle.y + cursorRectangle.height - descFlickable.height + margin;
                        }

                        StyledText {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            text: "Description (optional)..."
                            color: Appearance.colors.colSubtext
                            visible: !descArea.text && !descArea.activeFocus
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.Wrap
                        }
                    }

                    ScrollBar.vertical: StyledScrollBar {}
                }
            }

            // Recurrence selector
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * Appearance.effectiveScale
                StyledText { text: "Repeat"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6 * Appearance.effectiveScale
                    Repeater {
                        model: ["once", "daily", "weekly", "monthly"]
                        delegate: RippleButton {
                            required property string modelData
                            readonly property bool _hidden: root._multiDayDiff > 0 && modelData !== "once"
                            Layout.fillWidth: true
                            opacity: _hidden ? 0 : 1
                            enabled: !_hidden
                            implicitHeight: 32 * Appearance.effectiveScale
                            buttonRadius: 16 * Appearance.effectiveScale
                            colBackground: root.formRecurrence === modelData
                                ? Appearance.colors.colPrimary
                                : Appearance.m3colors.m3surfaceContainer
                            colBackgroundHover: root.formRecurrence === modelData
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colLayer2
                            onClicked: {
                                root.formRecurrence = modelData
                                if (root.selectedId) autoSaveTimer.restart()
                            }
                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.formRecurrence === modelData
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }

            // Save button
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 44 * Appearance.effectiveScale
                buttonRadius: 22 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                enabled: root.formTitle.trim().length > 0 && root.formDatesValid
                opacity: enabled ? 1 : 0.5
                onClicked: root.saveEvent()
                RowLayout {
                    anchors.centerIn: parent; spacing: 6 * Appearance.effectiveScale
                    MaterialSymbol { text: "save"; iconSize: 18 * Appearance.effectiveScale; color: Appearance.colors.colOnPrimary }
                    StyledText { text: root.selectedId ? "Update Event" : "Add Event"; font.weight: Font.Medium; color: Appearance.colors.colOnPrimary }
                }
            }
        }
    }

    // ── Date picker ──
    function openDatePicker() {
        root._datePickerTarget = "start"
        GlobalStates.datePickerCurrentDate = root.formDate
        GlobalStates.datePickerOnSelected = function(dateStr) {
            root._datePickerTarget = ""
            root.formDate = dateStr
            if (root.selectedId) autoSaveTimer.restart()
        }
        GlobalStates.datePickerOnCancelled = function() { root._datePickerTarget = "" }
        GlobalStates.datePickerOpen = true
    }

    function openEndDatePicker() {
        root._datePickerTarget = "end"
        GlobalStates.datePickerCurrentDate = root.formEndDate || root.formDate
        GlobalStates.datePickerOnSelected = function(dateStr) {
            root._datePickerTarget = ""
            root.formEndDate = dateStr
            if (root.selectedId) autoSaveTimer.restart()
        }
        GlobalStates.datePickerOnCancelled = function() { root._datePickerTarget = "" }
        GlobalStates.datePickerOpen = true
    }

    // ── Time picker ──
    property string _timePickerTarget: ""

    function openStartTimePicker() {
        root._timePickerTarget = "start"
        GlobalStates.openTimePicker(
            root.formTime || "00:00",
            function(timeStr) {
                root._timePickerTarget = ""
                root.formTime = timeStr
                if (root.selectedId) autoSaveTimer.restart()
            },
            function() { root._timePickerTarget = "" }
        )
    }

    function openEndTimePicker() {
        root._timePickerTarget = "end"
        GlobalStates.openTimePicker(
            root.formEndTime || "01:00",
            function(timeStr) {
                root._timePickerTarget = ""
                root.formEndTime = timeStr
                if (root.selectedId) autoSaveTimer.restart()
            },
            function() { root._timePickerTarget = "" }
        )
    }

    Component.onCompleted: clearForm()
}
