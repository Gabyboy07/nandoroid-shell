import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Dashboard Tab 1: Schedule
 * "Today" timeline (Google Calendar style) with a floating "+" action.
 * Page 0 = day timeline, Page 1 = event editor (CRUD form).
 */
Item {
    id: root

    // ── Navigation state ──
    property string _view: "timeline"
    // "timeline" | "editor"
    property string _editingId: ""
    property int dayOffset: 0 // 0 = today
    // ── Timeline metrics ──
    readonly property real hourHeight: 40 * Appearance.effectiveScale
    readonly property real gutterWidth: 46 * Appearance.effectiveScale
    readonly property real minBlockHeight: 22 * Appearance.effectiveScale
    readonly property real timelineContentHeight: 24 * root.hourHeight
    // Current-time fraction for the "now" line (refreshed while visible)
    property real nowFrac: 0
    readonly property string _dayDate: root._canonical(root._dateForOffset(root.dayOffset))
    readonly property string _dayLabel: {
        const d = root._dateForOffset(root.dayOffset);
        if (root.dayOffset === 0)
            return I18nService.tr("Today");

        if (root.dayOffset === 1)
            return I18nService.tr("Tomorrow");

        if (root.dayOffset === -1)
            return I18nService.tr("Yesterday");

        const days = [I18nService.tr("Sunday"), I18nService.tr("Monday"), I18nService.tr("Tuesday"), I18nService.tr("Wednesday"), I18nService.tr("Thursday"), I18nService.tr("Friday"), I18nService.tr("Saturday")];
        const months = [I18nService.tr("Jan"), I18nService.tr("Feb"), I18nService.tr("Mar"), I18nService.tr("Apr"), I18nService.tr("May"), I18nService.tr("Jun"), I18nService.tr("Jul"), I18nService.tr("Aug"), I18nService.tr("Sep"), I18nService.tr("Oct"), I18nService.tr("Nov"), I18nService.tr("Dec")];
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()];
    }
    // ── Events for the selected day ──
    // Recurrence matching delegated to ScheduleService.eventOccursOn — single source of truth.
    readonly property var dayEvents: {
        const day = root._dayDate;
        const list = ScheduleService.events.filter(ev => ScheduleService.eventOccursOn(ev, day));
        list.sort((a, b) => (a.time || "00:00").localeCompare(b.time || "00:00"));
        return list;
    }
    // Column layout for overlapping events (Google Calendar style).
    // Returns [{ ev, col, colCount }] sorted by time.
    readonly property var dayLayout: {
        const events = root.dayEvents;
        const result = [];
        if (events.length === 0)
            return result;

        // Group overlapping events into clusters
        const clusters = [];
        let current = [];
        for (let ev of events) {
            const overlapsCluster = current.some((c) => {
                return root._overlaps(ev, c);
            });
            if (overlapsCluster) {
                current.push(ev);
            } else {
                if (current.length)
                    clusters.push(current);

                current = [ev];
            }
        }
        if (current.length)
            clusters.push(current);

        // Greedy column assignment within each cluster; all events in the
        // cluster share the final column count (uniform width).
        for (let cluster of clusters) {
            const colEnds = []; // endFrac per column
            const placed = [];
            for (let ev of cluster) {
                const es = root._blockStartFrac(ev);
                const ee = root._blockEndFrac(ev);
                let col = 0;
                while (col < colEnds.length && es < colEnds[col])col++
                if (col === colEnds.length)
                    colEnds.push(0);

                colEnds[col] = Math.max(colEnds[col], ee);
                placed.push({
                    "ev": ev,
                    "col": col
                });
            }
            const colCount = colEnds.length;
            for (let p of placed) result.push({
                "ev": p.ev,
                "col": p.col,
                "colCount": colCount
            })
        }
        return result;
    }
    // ── Editor form state ──
    property string formTitle: ""
    property string formDate: _defaultDateStr()
    property string formTime: "00:00"
    property string formEndTime: "01:00"
    property string formRecurrence: "once" // once | daily | weekly | monthly
    property string formEndDate: ""
    property string formDescription: ""
    property bool formFocus: false
    property int _multiDayDiff: {
        if (!formEndDate.trim() || formEndDate === formDate)
            return 0;

        const s = root._parseDateObj(formDate);
        const e = root._parseDateObj(formEndDate);
        if (!s || !e)
            return 0;

        return Math.round((e - s) / 8.64e+07);
    }
    property bool formDatesValid: {
        if (!root.formEndDate.trim())
            return true;

        const s = root._parseDateObj(root.formDate);
        const e = root._parseDateObj(root.formEndDate);
        if (!s || !e)
            return false;

        if (e.getTime() < s.getTime())
            return false;

        if (e.getTime() > s.getTime())
            return true;

        const t = (str) => {
            const p = String(str || "").split(":").map(Number);
            return p.length >= 2 && !isNaN(p[0]) && !isNaN(p[1]) ? p[0] * 60 + p[1] : 0;
        };
        return t(root.formEndTime) > t(root.formTime);
    }
    // ── Date/time pickers ──
    property string _datePickerTarget: ""
    property string _timePickerTarget: ""

    function _nowFrac() {
        const now = DateTime.now;
        return (now.getHours() + now.getMinutes() / 60) / 24;
    }

    // ── Date helpers ──
    function _canonical(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, '0') + "-" + String(d.getDate()).padStart(2, '0');
    }

    function _dateForOffset(offset) {
        const d = new Date();
        d.setDate(d.getDate() + offset);
        return d;
    }

    function _hourLabel(h) {
        const style = Config.ready && Config.options.time ? Config.options.time.timeStyle : "24H";
        if (style === "24H")
            return String(h).padStart(2, "0") + ":00";

        const ap = h >= 12 ? "PM" : "AM";
        const h12 = h % 12 || 12;
        return h12 + " " + ap;
    }

    function _formatDateObj(d) {
        if (!d)
            return "";

        let y = d.getFullYear(), m = d.getMonth() + 1, day = d.getDate();
        const ys = String(y).padStart(4, '0');
        const ms = String(m).padStart(2, '0');
        const ds = String(day).padStart(2, '0');
        let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY";
        if (style === "YMD")
            return ys + "/" + ms + "/" + ds;

        if (style === "MDY")
            return ms + "/" + ds + "/" + ys;

        return ds + "/" + ms + "/" + ys;
    }

    function _parseDateObj(dStr) {
        if (!dStr)
            return null;

        const parts = String(dStr).trim().split(/[-/]/).map(Number);
        if (parts.length < 3 || parts.some(isNaN))
            return null;

        let y, m, d;
        if (parts[0] > 1000) {
            y = parts[0];
            m = parts[1];
            d = parts[2];
        } else if (parts[2] > 1000) {
            const style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY";
            if (style === "MDY") {
                m = parts[0];
                d = parts[1];
                y = parts[2];
            } else {
                d = parts[0];
                m = parts[1];
                y = parts[2];
            }
        } else {
            return null;
        }
        const dt = new Date(y, m - 1, d);
        return isNaN(dt.getTime()) ? null : dt;
    }

    function _formatDateByConfig(dStr) {
        if (!dStr)
            return "";

        let parts = dStr.trim().split(/[-/]/).map(Number);
        if (parts.length < 3 || parts.some(isNaN))
            return dStr;

        let y, m, d;
        if (parts[0] > 1000) {
            y = parts[0];
            m = parts[1];
            d = parts[2];
        } else if (parts[2] > 1000) {
            let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY";
            if (style === "MDY") {
                m = parts[0];
                d = parts[1];
                y = parts[2];
            } else {
                d = parts[0];
                m = parts[1];
                y = parts[2];
            }
        } else {
            return dStr;
        }
        const ys = String(y).padStart(4, '0');
        const ms = String(m).padStart(2, '0');
        const ds = String(d).padStart(2, '0');
        let style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY";
        if (style === "YMD")
            return ys + "/" + ms + "/" + ds;

        if (style === "MDY")
            return ms + "/" + ds + "/" + ys;

        return ds + "/" + ms + "/" + ys;
    }

    function _displayTime(timeStr) {
        if (!timeStr)
            return timeStr;

        const parts = String(timeStr).split(":");
        if (parts.length < 2)
            return timeStr;

        const h = parseInt(parts[0], 10);
        if (isNaN(h))
            return timeStr;

        const m = parts[1];
        const rest = parts.length > 2 ? ":" + parts.slice(2).join(":") : "";
        const style = Config.ready && Config.options.time ? Config.options.time.timeStyle : "24H";
        if (style === "24H")
            return String(h).padStart(2, "0") + ":" + m + rest;

        const upper = style === "12H_PM";
        const ap = h >= 12 ? (upper ? "PM" : "pm") : (upper ? "AM" : "am");
        const h12 = h % 12 || 12;
        return String(h12).padStart(2, "0") + ":" + m + rest + " " + ap;
    }

    function _displayDate(dStr) {
        if (!dStr)
            return dStr;

        const style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY";
        const parts = String(dStr).trim().split(/[-/]/).map(Number);
        if (parts.length < 3 || parts.some(isNaN))
            return dStr;

        let y, m, d;
        if (parts[0] > 1000) {
            y = parts[0];
            m = parts[1];
            d = parts[2];
        } else if (style === "MDY") {
            m = parts[0];
            d = parts[1];
            y = parts[2];
        } else {
            d = parts[0];
            m = parts[1];
            y = parts[2];
        }
        if (!y || !m || !d)
            return dStr;

        const days = [I18nService.tr("Sun"), I18nService.tr("Mon"), I18nService.tr("Tue"), I18nService.tr("Wed"), I18nService.tr("Thu"), I18nService.tr("Fri"), I18nService.tr("Sat")];
        return days[new Date(y, m - 1, d).getDay()] + ", " + dStr;
    }

    function _defaultDateStr() {
        return _formatDateObj(new Date());
    }

    function _recurrenceLabel(code) {
        switch (code) {
        case "once":
            return I18nService.tr("Once");
        case "daily":
            return I18nService.tr("Daily");
        case "weekly":
            return I18nService.tr("Weekly");
        case "monthly":
            return I18nService.tr("Monthly");
        default:
            return code;
        }
    }

    function _timeFrac(t) {
        const p = String(t || "").split(":");
        if (p.length < 2 || isNaN(+p[0]) || isNaN(+p[1]))
            return null;

        return (+p[0] + +p[1] / 60) / 24;
    }

    function _isMultiDay(ev) {
        return ev.recurrence === "once" && ev.endDate && ev.endDate !== ev.date;
    }

    function _blockStartFrac(ev) {
        const multi = root._isMultiDay(ev);
        if (multi && root._dayDate !== ev.date)
            return 0;

        return root._timeFrac(ev.time) ?? 0;
    }

    function _blockEndFrac(ev) {
        const multi = root._isMultiDay(ev);
        const start = root._timeFrac(ev.time) ?? 0;
        if (multi) {
            const first = root._dayDate === ev.date;
            const last = root._dayDate === ev.endDate;
            if (first && !last)
                return 1;

            if (last && !first)
                return root._timeFrac(ev.endTime) ?? 1;

        }
        const end = root._timeFrac(ev.endTime);
        if (end === null)
            return Math.min(1, start + 1 / 24);

        if (end > start)
            return end;

        return 1;
    }

    function _overlaps(a, b) {
        const as = root._blockStartFrac(a), ae = root._blockEndFrac(a);
        const bs = root._blockStartFrac(b), be = root._blockEndFrac(b);
        if (ae <= bs || be <= as)
            return false;

        return true;
    }

    function scrollToDayStart() {
        if (root.dayOffset !== 0) {
            timelineFlickable.contentY = 0;
            return ;
        }
        root.nowFrac = root._nowFrac();
        const target = root.nowFrac * root.timelineContentHeight;
        const maxScroll = Math.max(0, root.timelineContentHeight - timelineFlickable.height);
        timelineFlickable.contentY = Math.max(0, Math.min(maxScroll, target - timelineFlickable.height / 2));
    }

    // ── View switching ──
    function openEditorNew() {
        root._editingId = "";
        root.clearForm();
        root._view = "editor";
    }

    function openEditorEdit(id) {
        const ev = ScheduleService.events.find((e) => {
            return e.id === id;
        });
        if (!ev)
            return ;

        root._editingId = id;
        root.formTitle = ev.title;
        root.formDate = root._formatDateByConfig(ev.date);
        root.formTime = ev.time;
        root.formEndTime = ev.endTime || "";
        root.formEndDate = root._formatDateByConfig(ev.endDate || "");
        root.formRecurrence = ev.recurrence;
        root.formDescription = ev.description || "";
        root.formFocus = ev.focus || false;
        root._view = "editor";
    }

    function backToTimeline() {
        if (autoSaveTimer.running)
            autoSaveTimer.stop();

        root._editingId = "";
        root._view = "timeline";
    }

    function deleteEditingEvent() {
        if (!root._editingId)
            return ;

        ScheduleService.deleteEvent(root._editingId);
        root._editingId = "";
        root._view = "timeline";
    }

    function clearForm() {
        const now = new Date();
        let nextH = (now.getHours() + 1) % 24;
        let date = new Date(now);
        if (nextH <= now.getHours())
            date.setDate(date.getDate() + 1);

        const nextHStr = String(nextH).padStart(2, '0') + ":00";
        const endH = (nextH + 1) % 24;
        const endHStr = String(endH).padStart(2, '0') + ":00";
        let endDate = new Date(date);
        if (endH <= nextH)
            endDate.setDate(endDate.getDate() + 1);

        formTitle = "";
        formDate = _formatDateObj(date);
        formTime = nextHStr;
        formEndTime = endHStr;
        formEndDate = _formatDateObj(endDate);
        formDescription = "";
        formFocus = false;
    }

    function saveEvent() {
        if (!formTitle.trim())
            return ;

        const descVal = formDescription.trim() ? formDescription.trim() : undefined;
        const dateVal = GlobalStates.toCanonicalDateStr(formDate) || formDate;
        const endDateVal = formEndDate.trim() && formEndDate !== formDate ? (GlobalStates.toCanonicalDateStr(formEndDate) || formEndDate) : undefined;
        if (_editingId) {
            ScheduleService.updateEvent(_editingId, {
                "title": formTitle,
                "date": dateVal,
                "time": formTime,
                "endTime": formEndTime,
                "endDate": endDateVal,
                "recurrence": formRecurrence,
                "description": descVal,
                "focus": formFocus
            });
        } else {
            const newEv = {
                "id": Date.now().toString(36),
                "title": formTitle,
                "date": dateVal,
                "time": formTime,
                "endTime": formEndTime,
                "endDate": endDateVal,
                "recurrence": formRecurrence,
                "description": descVal,
                "focus": formFocus,
                "lastFired": ""
            };
            ScheduleService.addEvent(newEv);
        }
        root._editingId = "";
        root.clearForm();
        root._view = "timeline";
    }

    function openDatePicker() {
        root._datePickerTarget = "start";
        GlobalStates.datePickerCurrentDate = root.formDate;
        GlobalStates.datePickerOnSelected = function(dateStr) {
            root._datePickerTarget = "";
            root.formDate = dateStr;
            if (root._editingId)
                autoSaveTimer.restart();

        };
        GlobalStates.datePickerOnCancelled = function() {
            root._datePickerTarget = "";
        };
        GlobalStates.datePickerOpen = true;
    }

    function openEndDatePicker() {
        root._datePickerTarget = "end";
        GlobalStates.datePickerCurrentDate = root.formEndDate || root.formDate;
        GlobalStates.datePickerOnSelected = function(dateStr) {
            root._datePickerTarget = "";
            root.formEndDate = dateStr;
            if (root._editingId)
                autoSaveTimer.restart();

        };
        GlobalStates.datePickerOnCancelled = function() {
            root._datePickerTarget = "";
        };
        GlobalStates.datePickerOpen = true;
    }

    function openStartTimePicker() {
        root._timePickerTarget = "start";
        GlobalStates.openTimePicker(root.formTime || "00:00", function(timeStr) {
            root._timePickerTarget = "";
            root.formTime = timeStr;
            if (root._editingId)
                autoSaveTimer.restart();

        }, function() {
            root._timePickerTarget = "";
        }, Config.ready && Config.options.time ? Config.options.time.timeStyle === "24H" : false);
    }

    function openEndTimePicker() {
        root._timePickerTarget = "end";
        GlobalStates.openTimePicker(root.formEndTime || "01:00", function(timeStr) {
            root._timePickerTarget = "";
            root.formEndTime = timeStr;
            if (root._editingId)
                autoSaveTimer.restart();

        }, function() {
            root._timePickerTarget = "";
        }, Config.ready && Config.options.time ? Config.options.time.timeStyle === "24H" : false);
    }

    onDayOffsetChanged: Qt.callLater(() => {
        return scrollToDayStart();
    })
    onFormEndDateChanged: {
        if (_multiDayDiff > 0 && formRecurrence !== "once")
            formRecurrence = "once";

    }
    Component.onCompleted: {
        clearForm();
        root.nowFrac = root._nowFrac();
        Qt.callLater(() => {
            return scrollToDayStart();
        });
        recenterTimer.start();
    }

    Timer {
        interval: 30000
        running: root._view === "timeline" && root.dayOffset === 0 && GlobalStates.dashboardOpen
        repeat: true
        onTriggered: root.nowFrac = root._nowFrac()
    }

    // Recenter once layout/panel animation has settled so the target hour
    // is centered within the timeline area (not the whole panel).
    Timer {
        id: recenterTimer

        interval: 400
        repeat: false
        onTriggered: root.scrollToDayStart()
    }

    // Auto-save debounce for existing events
    Timer {
        id: autoSaveTimer

        interval: 500
        repeat: false
        onTriggered: {
            if (!root._editingId || !root.formTitle.trim())
                return ;

            const descVal = root.formDescription.trim() ? root.formDescription.trim() : undefined;
            const dateVal = GlobalStates.toCanonicalDateStr(root.formDate) || root.formDate;
            const endDateVal = root.formEndDate.trim() && root.formEndDate !== root.formDate ? (GlobalStates.toCanonicalDateStr(root.formEndDate) || root.formEndDate) : undefined;
            ScheduleService.updateEvent(root._editingId, {
                "title": root.formTitle,
                "date": dateVal,
                "time": root.formTime,
                "endTime": root.formEndTime,
                "endDate": endDateVal,
                "recurrence": root.formRecurrence,
                "description": descVal,
                "focus": root.formFocus
            });
        }
    }

    // ══════════════════════════════════════════════════
    //  PAGE 0: TODAY TIMELINE
    // ══════════════════════════════════════════════════
    Item {
        id: timelineView

        anchors.fill: parent
        visible: root._view === "timeline"

        Rectangle {
            id: timelineIsland

            anchors.fill: parent
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10 * Appearance.effectiveScale
                spacing: 8 * Appearance.effectiveScale

                // ── Day navigation header ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * Appearance.effectiveScale

                    // Interactive day label — click returns to today
                    Item {
                        id: labelSlot

                        implicitWidth: labelText.width + 18 * Appearance.effectiveScale
                        implicitHeight: 32 * Appearance.effectiveScale

                        Rectangle {
                            id: labelPill

                            anchors.fill: parent
                            radius: 16 * Appearance.effectiveScale
                            visible: root.dayOffset !== 0
                            color: labelMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                        StyledText {
                            id: labelText

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 9 * Appearance.effectiveScale
                            text: root._dayLabel
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.m3colors.m3onSurface
                        }

                        MouseArea {
                            id: labelMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.dayOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.dayOffset !== 0)
                                    root.dayOffset = 0;

                            }
                        }

                        StyledToolTip {
                            x: labelText.x + (labelText.width - width) / 2
                            y: 34 * Appearance.effectiveScale
                            text: I18nService.tr("Back to today")
                            alternativeVisibleCondition: labelMouse.containsMouse && root.dayOffset !== 0
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 32 * Appearance.effectiveScale
                    }

                    // Navigation group: ‹ ›
                    RowLayout {
                        spacing: 4 * Appearance.effectiveScale

                        RippleButton {
                            implicitWidth: 32 * Appearance.effectiveScale
                            implicitHeight: 32 * Appearance.effectiveScale
                            buttonRadius: 16 * Appearance.effectiveScale
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: root.dayOffset -= 1

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                iconSize: 20 * Appearance.effectiveScale
                                color: Appearance.m3colors.m3onSurface
                            }

                            StyledToolTip {
                                text: I18nService.tr("Previous day")
                            }

                        }

                        RippleButton {
                            implicitWidth: 32 * Appearance.effectiveScale
                            implicitHeight: 32 * Appearance.effectiveScale
                            buttonRadius: 16 * Appearance.effectiveScale
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: root.dayOffset += 1

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                iconSize: 20 * Appearance.effectiveScale
                                color: Appearance.m3colors.m3onSurface
                            }

                            StyledToolTip {
                                text: I18nService.tr("Next day")
                            }

                        }

                    }

                }

                // ── Hour grid timeline ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true

                    Flickable {
                        id: timelineFlickable

                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: root.timelineContentHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Item {
                            width: timelineFlickable.width
                            height: root.timelineContentHeight

                            // Horizontal grid lines
                            Repeater {
                                model: 25

                                delegate: Rectangle {
                                    required property int index

                                    x: 0
                                    y: index * root.hourHeight
                                    width: parent.width
                                    height: 1
                                    color: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSurface, 0.06)
                                }

                            }

                            // Hour label gutter
                            Column {
                                x: 0
                                y: 0
                                width: root.gutterWidth

                                Repeater {
                                    model: 24

                                    delegate: Item {
                                        required property int index

                                        width: root.gutterWidth
                                        height: root.hourHeight

                                        StyledText {
                                            anchors.topMargin: 2 * Appearance.effectiveScale
                                            anchors.rightMargin: 8 * Appearance.effectiveScale
                                            text: root._hourLabel(index)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                            horizontalAlignment: Text.AlignRight

                                            anchors {
                                                top: parent.top
                                                left: parent.left
                                                right: parent.right
                                            }

                                        }

                                    }

                                }

                            }

                            // Event blocks
                            Item {
                                x: root.gutterWidth + 4 * Appearance.effectiveScale
                                y: 0
                                width: parent.width - x - 4 * Appearance.effectiveScale
                                height: parent.height

                                Repeater {
                                    model: root.dayLayout

                                    delegate: Item {
                                        required property var modelData
                                        readonly property var ev: modelData.ev
                                        readonly property real startFrac: root._blockStartFrac(ev)
                                        readonly property real endFrac: root._blockEndFrac(ev)

                                        x: modelData.col / modelData.colCount * parent.width
                                        y: startFrac * root.timelineContentHeight
                                        width: parent.width / modelData.colCount
                                        height: Math.max(root.minBlockHeight, (endFrac - startFrac) * root.timelineContentHeight)

                                        Rectangle {
                                            radius: Appearance.rounding.small
                                            color: ev.focus ? Appearance.m3colors.m3tertiaryContainer : Appearance.colors.colLayer3
                                            clip: true

                                            anchors {
                                                fill: parent
                                                topMargin: 1 * Appearance.effectiveScale
                                                bottomMargin: 3 * Appearance.effectiveScale
                                                leftMargin: 1 * Appearance.effectiveScale
                                                rightMargin: 4 * Appearance.effectiveScale
                                            }

                                            // Text pinned to the top like Google Calendar
                                            Item {
                                                property bool isCompact: parent.height <= (root.hourHeight * 1.05)
                                                property string timeStr: root._displayTime(ev.time) + (ev.endTime && ev.endTime !== ev.time ? " - " + root._displayTime(ev.endTime) : "")

                                                anchors {
                                                    fill: parent
                                                    topMargin: isCompact ? 0 : (6 * Appearance.effectiveScale)
                                                    leftMargin: 10 * Appearance.effectiveScale
                                                    rightMargin: 8 * Appearance.effectiveScale
                                                }

                                                RowLayout {
                                                    visible: parent.isCompact
                                                    anchors {
                                                        verticalCenter: parent.verticalCenter
                                                        left: parent.left
                                                    }
                                                    width: Math.min(implicitWidth, parent.width)
                                                    spacing: 4 * Appearance.effectiveScale

                                                    StyledText {
                                                        text: ev.title
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: ev.focus ? Appearance.m3colors.m3onTertiaryContainer : Appearance.m3colors.m3onSurface
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    StyledText {
                                                        visible: parent.parent.timeStr !== ""
                                                        text: "·"
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: ev.focus ? Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.75) : Appearance.colors.colSubtext
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }

                                                    StyledText {
                                                        visible: parent.parent.timeStr !== ""
                                                        text: parent.parent.timeStr
                                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                                        color: ev.focus ? Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.75) : Appearance.colors.colSubtext
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                }

                                                StyledText {
                                                    id: pillTitle
                                                    visible: !parent.isCompact
                                                    text: ev.title
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    font.weight: Font.Medium
                                                    color: ev.focus ? Appearance.m3colors.m3onTertiaryContainer : Appearance.m3colors.m3onSurface
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                    anchors {
                                                        top: parent.top
                                                        left: parent.left
                                                        right: parent.right
                                                    }
                                                }

                                                StyledText {
                                                    visible: !parent.isCompact
                                                    text: parent.timeStr
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: ev.focus ? Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.75) : Appearance.colors.colSubtext
                                                    elide: Text.ElideRight
                                                    anchors {
                                                        top: pillTitle.bottom
                                                        topMargin: 1 * Appearance.effectiveScale
                                                        left: parent.left
                                                        right: parent.right
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openEditorEdit(ev.id)
                                            }

                                        }

                                    }

                                }

                            }

                            // Current time indicator (today only)
                            Item {
                                visible: root.dayOffset === 0
                                x: 0
                                y: root.nowFrac * root.timelineContentHeight - 1 * Appearance.effectiveScale
                                width: parent.width
                                height: 2 * Appearance.effectiveScale

                                Rectangle {
                                    x: root.gutterWidth + 5 * Appearance.effectiveScale
                                    y: 0
                                    width: parent.width - x
                                    height: parent.height
                                    radius: 1 * Appearance.effectiveScale
                                    color: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSurface, 0.85)
                                }

                                Rectangle {
                                    width: 10 * Appearance.effectiveScale
                                    height: 10 * Appearance.effectiveScale
                                    radius: 5 * Appearance.effectiveScale
                                    color: Appearance.m3colors.m3onSurface
                                    x: root.gutterWidth - 5 * Appearance.effectiveScale
                                    y: -4 * Appearance.effectiveScale
                                }

                            }

                        }

                        ScrollBar.vertical: StyledScrollBar {
                        }

                    }

                    // ── Empty state overlay ──
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8 * Appearance.effectiveScale
                        visible: root.dayEvents.length === 0
                        opacity: visible ? 1 : 0

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "event_busy"
                            iconSize: 40 * Appearance.effectiveScale
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.dayOffset === 0 ? I18nService.tr("No schedule for today") : I18nService.tr("No schedule for this day")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onSurface
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: I18nService.tr("Tap + to add an event")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }

                        }

                    }

                }

            }

            // ── FAB ──
            StyledRectangularShadow {
                target: fabButton
                radius: fabButton.buttonRadius
                color: Functions.ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.2)
            }

            RippleButton {
                id: fabButton
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14 * Appearance.effectiveScale
                anchors.bottomMargin: 14 * Appearance.effectiveScale
                implicitWidth: 56 * Appearance.effectiveScale
                implicitHeight: 56 * Appearance.effectiveScale
                buttonRadius: 16 * Appearance.effectiveScale
                colBackground: Appearance.m3colors.m3primaryContainer
                colBackgroundHover: Functions.ColorUtils.mix(Appearance.m3colors.m3primaryContainer, Appearance.m3colors.m3onPrimaryContainer, 0.9)
                colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onPrimaryContainer, 0.15)
                onClicked: root.openEditorNew()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "add"
                    iconSize: 24 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3onPrimaryContainer
                }

                StyledToolTip {
                    text: I18nService.tr("New Event")
                }

            }

        }

    }

    // ══════════════════════════════════════════════════
    //  PAGE 1: EVENT EDITOR
    // ══════════════════════════════════════════════════
    Item {
        id: editorView

        anchors.fill: parent
        visible: root._view === "editor"

        ColumnLayout {
            anchors.fill: parent
            spacing: 12 * Appearance.effectiveScale

            // ── Header: back + title + focus toggle + delete ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                RippleButton {
                    implicitWidth: 36 * Appearance.effectiveScale
                    implicitHeight: 36 * Appearance.effectiveScale
                    buttonRadius: 18 * Appearance.effectiveScale
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.backToTimeline()

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.m3colors.m3onSurface
                    }

                    StyledToolTip {
                        text: I18nService.tr("Back to schedule")
                    }

                }

                StyledText {
                    Layout.fillWidth: true
                    text: root._editingId ? I18nService.tr("Edit Event") : I18nService.tr("New Event")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: 8 * Appearance.effectiveScale

                    MaterialSymbol {
                        text: "do_not_disturb_on"
                        iconSize: 18 * Appearance.effectiveScale
                        color: root.formFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }

                    StyledText {
                        text: I18nService.tr("Focus Mode")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.formFocus ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }

                    AndroidToggle {
                        checked: root.formFocus
                        color: checked ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHigh
                        onToggled: {
                            root.formFocus = !root.formFocus;
                            if (root._editingId)
                                autoSaveTimer.restart();

                        }
                    }

                }

                RippleButton {
                    visible: root._editingId !== ""
                    implicitWidth: 36 * Appearance.effectiveScale
                    implicitHeight: 36 * Appearance.effectiveScale
                    buttonRadius: 18 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainer
                    onClicked: root.deleteEditingEvent()

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.colors.colError
                    }

                    StyledToolTip {
                        text: I18nService.tr("Delete event")
                    }

                }

            }

            // ── Title field ──
            StyledTextInput {
                id: titleField

                Layout.fillWidth: true
                implicitHeight: 44 * Appearance.effectiveScale
                inputRadius: Appearance.rounding.small / Appearance.effectiveScale
                backgroundColor: Appearance.m3colors.m3surfaceContainer
                placeholder: I18nService.tr("Event title...")
                text: root.formTitle
                onTextChanged: {
                    root.formTitle = text;
                    if (root._editingId && titleField.input.activeFocus)
                        autoSaveTimer.restart();

                }
            }

            // ── Start row ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                StyledText {
                    text: I18nService.tr("Start:")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.preferredWidth: 44 * Appearance.effectiveScale
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 44 * Appearance.effectiveScale
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colText: "transparent"
                    onClicked: root.openDatePicker()

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10 * Appearance.effectiveScale
                        text: root._displayDate(root.formDate)
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignLeft
                    }

                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 44 * Appearance.effectiveScale
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colText: "transparent"
                    onClicked: root.openStartTimePicker()

                    StyledText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Appearance.effectiveScale
                        text: root._displayTime(root.formTime)
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignRight
                    }

                }

            }

            // ── End row ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                StyledText {
                    text: I18nService.tr("End:")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.preferredWidth: 44 * Appearance.effectiveScale
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 44 * Appearance.effectiveScale
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colText: "transparent"
                    onClicked: root.openEndDatePicker()

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10 * Appearance.effectiveScale
                        text: root._displayDate(root.formEndDate)
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignLeft
                    }

                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 44 * Appearance.effectiveScale
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colText: "transparent"
                    onClicked: root.openEndTimePicker()

                    StyledText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Appearance.effectiveScale
                        text: root._displayTime(root.formEndTime)
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignRight
                    }

                }

            }

            StyledText {
                visible: root.formEndDate.trim() && !root.formDatesValid
                text: I18nService.tr("End must be later than start")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colError
            }

            // ── Description field ──
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
                        onTextChanged: {
                            root.formDescription = text;
                            if (root._editingId && descArea.activeFocus)
                                autoSaveTimer.restart();

                        }
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
                            text: I18nService.tr("Description (optional)...")
                            color: Appearance.colors.colSubtext
                            visible: !descArea.text && !descArea.activeFocus
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.Wrap
                        }

                    }

                    ScrollBar.vertical: StyledScrollBar {
                    }

                }

            }

            // ── Recurrence selector ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * Appearance.effectiveScale

                StyledText {
                    text: I18nService.tr("Repeat")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

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
                            colBackground: root.formRecurrence === modelData ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainer
                            colBackgroundHover: root.formRecurrence === modelData ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                            onClicked: {
                                root.formRecurrence = modelData;
                                if (root._editingId)
                                    autoSaveTimer.restart();

                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: root._recurrenceLabel(modelData)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.formRecurrence === modelData ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                            }

                        }

                    }

                }

            }

            // ── Save button ──
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 44 * Appearance.effectiveScale
                buttonRadius: 22 * Appearance.effectiveScale
                colBackground: Appearance.colors.colPrimary
                enabled: root.formTitle.trim().length > 0 && root.formDatesValid
                opacity: enabled ? 1 : 0.5
                onClicked: root.saveEvent()

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6 * Appearance.effectiveScale

                    MaterialSymbol {
                        text: "save"
                        iconSize: 18 * Appearance.effectiveScale
                        color: Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        text: root._editingId ? I18nService.tr("Update Event") : I18nService.tr("Add Event")
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                    }

                }

            }

        }

    }

}
