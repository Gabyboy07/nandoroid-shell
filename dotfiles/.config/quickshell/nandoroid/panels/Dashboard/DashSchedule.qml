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
    // "timeline" | "editor" | "reminder-editor"
    property string _editingId: ""
    property string _editingReminderId: ""
    property int dayOffset: 0 // 0 = today

    // ── Items from parent (for reminder linked-item picker) ──
    property var notepadItems: []
    property var todoItems: []
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
    // Unified column layout for overlapping events AND reminders.
    // Returns [{ item, sf, ef, isReminder, col, colCount }] sorted by start time.
    readonly property var dayLayout: {
        const items = [];

        // Add events
        for (let i = 0; i < root.dayEvents.length; i++) {
            const ev = root.dayEvents[i];
            items.push({ "item": ev, "sf": root._blockStartFrac(ev), "ef": root._blockEndFrac(ev), "isReminder": false });
        }

        // Add reminders (fixed 1-hour height)
        for (let j = 0; j < root.dayReminders.length; j++) {
            const rem = root.dayReminders[j];
            const sf = root._timeFrac(rem.time) ?? 0;
            items.push({ "item": rem, "sf": sf, "ef": Math.min(1, sf + 1 / 24), "isReminder": true });
        }

        if (items.length === 0) return [];

        // Sort by start time
        items.sort(function(a, b) { return a.sf - b.sf; });

        // Group overlapping items into clusters
        const clusters = [];
        let current = [];
        for (let k = 0; k < items.length; k++) {
            const it = items[k];
            let overlaps = false;
            for (let m = 0; m < current.length; m++) {
                if (it.sf < current[m].ef && current[m].sf < it.ef) { overlaps = true; break; }
            }
            if (overlaps) {
                current.push(it);
            } else {
                if (current.length) clusters.push(current);
                current = [it];
            }
        }
        if (current.length) clusters.push(current);

        // Greedy column assignment
        const result = [];
        for (let ci = 0; ci < clusters.length; ci++) {
            const cluster = clusters[ci];
            const colEnds = [];
            const placed = [];
            for (let pi = 0; pi < cluster.length; pi++) {
                const it = cluster[pi];
                let col = 0;
                while (col < colEnds.length && it.sf < colEnds[col]) col++;
                if (col === colEnds.length) colEnds.push(0);
                colEnds[col] = Math.max(colEnds[col], it.ef);
                placed.push({ "item": it.item, "sf": it.sf, "ef": it.ef, "isReminder": it.isReminder, "col": col });
            }
            const colCount = colEnds.length;
            for (let ri = 0; ri < placed.length; ri++) {
                const p = placed[ri];
                result.push({ "item": p.item, "sf": p.sf, "ef": p.ef, "isReminder": p.isReminder, "col": p.col, "colCount": colCount });
            }
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

    // ── Reminder form state ──
    property string reminderText: ""
    property string reminderDate: _defaultDateStr()
    property string reminderTime: "09:00"
    property string reminderType: "basic" // "basic" | "notepad" | "todo"
    property string reminderLinkedId: ""
    property string reminderLinkedTitle: ""

    // ── Speed Dial FAB state ──
    property bool _fabOpen: false

    // ── Reminders for selected day ──
    readonly property var dayReminders: {
        const day = root._dayDate;
        return ReminderService.reminders.filter(r => r.date === day && !r.fired);
    }
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

    // ── Reminder editor helpers ──
    function openReminderEditorNew() {
        root._editingReminderId = "";
        root.clearReminderForm();
        root._fabOpen = false;
        root._view = "reminder-editor";
    }

    function openReminderEditorEdit(id) {
        const r = ReminderService.reminders.find(x => x.id === id);
        if (!r) return;
        root._editingReminderId = id;
        root.reminderText = r.text;
        root.reminderDate = root._formatDateByConfig(r.date);
        root.reminderTime = r.time;
        root.reminderType = r.type || "basic";
        root.reminderLinkedId = r.linkedId || "";
        root.reminderLinkedTitle = r.linkedTitle || "";
        root._fabOpen = false;
        root._view = "reminder-editor";
    }

    function backFromReminderEditor() {
        root._editingReminderId = "";
        root._view = "timeline";
    }

    function clearReminderForm() {
        const now = new Date();
        const nextH = (now.getHours() + 1) % 24;
        const date = new Date(now);
        if (nextH <= now.getHours()) date.setDate(date.getDate() + 1);
        reminderText = "";
        reminderDate = _formatDateObj(date);
        reminderTime = String(nextH).padStart(2, '0') + ":00";
        reminderType = "basic";
        reminderLinkedId = "";
        reminderLinkedTitle = "";
    }

    function saveReminder() {
        if (!reminderText.trim()) return;
        const dateVal = GlobalStates.toCanonicalDateStr(reminderDate) || reminderDate;
        if (root._editingReminderId) {
            ReminderService.updateReminder(root._editingReminderId, {
                text: reminderText.trim(),
                date: dateVal,
                time: reminderTime,
                type: reminderType,
                linkedId: reminderLinkedId,
                linkedTitle: reminderLinkedTitle
            });
        } else {
            ReminderService.addReminder({
                id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
                text: reminderText.trim(),
                date: dateVal,
                time: reminderTime,
                type: reminderType,
                linkedId: reminderLinkedId,
                linkedTitle: reminderLinkedTitle,
                fired: false,
                lastFiredDate: ""
            });
        }
        root._editingReminderId = "";
        root._view = "timeline";
    }

    function deleteEditingReminder() {
        if (!root._editingReminderId) return;
        ReminderService.deleteReminder(root._editingReminderId);
        root._editingReminderId = "";
        root._view = "timeline";
    }

    function openReminderDatePicker() {
        GlobalStates.datePickerCurrentDate = root.reminderDate;
        GlobalStates.datePickerOnSelected = function(dateStr) {
            root.reminderDate = dateStr;
        };
        GlobalStates.datePickerOnCancelled = function() {};
        GlobalStates.datePickerOpen = true;
    }

    function openReminderTimePicker() {
        GlobalStates.openTimePicker(root.reminderTime || "09:00", function(timeStr) {
            root.reminderTime = timeStr;
        }, function() {}, Config.ready && Config.options.time ? Config.options.time.timeStyle === "24H" : false);
    }

    onDayOffsetChanged: Qt.callLater(() => scrollToDayStart())
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

                                    x: root.gutterWidth
                                    y: index * root.hourHeight
                                    width: parent.width - root.gutterWidth
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

                            // Unified event + reminder blocks (column-layout aware)
                            Item {
                                x: root.gutterWidth
                                y: 0
                                width: parent.width - x
                                height: parent.height

                                Repeater {
                                    model: root.dayLayout

                                    delegate: Item {

                                        id: blockDelegate
                                        required property var modelData
                                        readonly property bool isRem: modelData.isReminder
                                        readonly property var ev: modelData.isReminder ? ({"title": "", "time": "", "endTime": "", "id": "", "focus": false}) : modelData.item
                                        readonly property var rem: modelData.isReminder ? modelData.item : ({"text": "", "time": "", "id": "", "linkedTitle": ""})

                                        x: modelData.col / modelData.colCount * parent.width
                                        y: modelData.sf * root.timelineContentHeight
                                        width: parent.width / modelData.colCount
                                        height: Math.max(root.minBlockHeight, (modelData.ef - modelData.sf) * root.timelineContentHeight)

                                        // ── Event block ──
                                        Rectangle {
                                            id: evBlock
                                            visible: !blockDelegate.isRem
                                            radius: Appearance.rounding.small
                                            color: blockDelegate.ev.focus ? Appearance.m3colors.m3tertiaryContainer : Appearance.colors.colLayer3
                                            clip: true

                                            anchors {
                                                fill: parent
                                                topMargin: 1 * Appearance.effectiveScale
                                                bottomMargin: 3 * Appearance.effectiveScale
                                                leftMargin: 0
                                                rightMargin: 1 * Appearance.effectiveScale
                                            }

                                            property bool isCompact: height <= (root.hourHeight * 1.05)
                                            property string timeStr: root._displayTime(blockDelegate.ev.time) + (blockDelegate.ev.endTime && blockDelegate.ev.endTime !== blockDelegate.ev.time ? " - " + root._displayTime(blockDelegate.ev.endTime) : "")

                                            Item {
                                                anchors {
                                                    fill: parent
                                                    topMargin: evBlock.isCompact ? 0 : (6 * Appearance.effectiveScale)
                                                    leftMargin: 10 * Appearance.effectiveScale
                                                    rightMargin: 8 * Appearance.effectiveScale
                                                }

                                                RowLayout {
                                                    visible: evBlock.isCompact
                                                    anchors {
                                                        verticalCenter: parent.verticalCenter
                                                        left: parent.left
                                                    }
                                                    width: Math.min(implicitWidth, parent.width)
                                                    spacing: 4 * Appearance.effectiveScale

                                                    StyledText {
                                                        text: blockDelegate.ev.title
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: blockDelegate.ev.focus ? Appearance.m3colors.m3onTertiaryContainer : Appearance.m3colors.m3onSurface
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    StyledText {
                                                        visible: evBlock.timeStr !== ""
                                                        text: "\u00b7"
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: blockDelegate.ev.focus ? Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.75) : Appearance.colors.colSubtext
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }

                                                    StyledText {
                                                        visible: evBlock.timeStr !== ""
                                                        text: evBlock.timeStr
                                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                                        color: blockDelegate.ev.focus ? Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.75) : Appearance.colors.colSubtext
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                }

                                                StyledText {
                                                    id: evTitle
                                                    visible: !evBlock.isCompact
                                                    text: blockDelegate.ev.title
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    font.weight: Font.Medium
                                                    color: blockDelegate.ev.focus ? Appearance.m3colors.m3onTertiaryContainer : Appearance.m3colors.m3onSurface
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
                                                    visible: !evBlock.isCompact
                                                    text: evBlock.timeStr
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: blockDelegate.ev.focus ? Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onTertiaryContainer, 0.75) : Appearance.colors.colSubtext
                                                    elide: Text.ElideRight
                                                    anchors {
                                                        top: evTitle.bottom
                                                        topMargin: 1 * Appearance.effectiveScale
                                                        left: parent.left
                                                        right: parent.right
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openEditorEdit(blockDelegate.ev.id)
                                            }
                                        }

                                        // ── Reminder block ──
                                        Rectangle {
                                            id: remBlock
                                            visible: parent.isRem
                                            radius: Appearance.rounding.small
                                            color: Appearance.m3colors.m3secondaryContainer
                                            clip: true

                                            anchors {
                                                fill: parent
                                                topMargin: 1 * Appearance.effectiveScale
                                                bottomMargin: 3 * Appearance.effectiveScale
                                                leftMargin: 0
                                                rightMargin: 1 * Appearance.effectiveScale
                                            }

                                            property bool isCompact: height <= (root.hourHeight * 1.05)
                                            property string timeStr: root._displayTime(blockDelegate.rem.time) || ""

                                            Item {
                                                anchors {
                                                    fill: parent
                                                    topMargin: remBlock.isCompact ? 0 : (6 * Appearance.effectiveScale)
                                                    leftMargin: 6 * Appearance.effectiveScale
                                                    rightMargin: 6 * Appearance.effectiveScale
                                                }

                                                // Compact: icon + text + · + time inline
                                                RowLayout {
                                                    visible: remBlock.isCompact
                                                    anchors {
                                                        verticalCenter: parent.verticalCenter
                                                        left: parent.left
                                                    }
                                                    width: Math.min(implicitWidth, parent.width)
                                                    spacing: 4 * Appearance.effectiveScale

                                                    MaterialSymbol {
                                                        text: "alarm"
                                                        iconSize: 12 * Appearance.effectiveScale
                                                        color: Appearance.m3colors.m3onSecondaryContainer
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }

                                                    StyledText {
                                                        text: blockDelegate.rem.text
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: Appearance.m3colors.m3onSecondaryContainer
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    StyledText {
                                                        visible: remBlock.timeStr !== ""
                                                        text: "\u00b7"
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSecondaryContainer, 0.75)
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }

                                                    StyledText {
                                                        visible: remBlock.timeStr !== ""
                                                        text: remBlock.timeStr
                                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                                        color: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSecondaryContainer, 0.75)
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                }

                                                // Expanded: icon+text pinned top, time below
                                                RowLayout {
                                                    id: remTitleRow
                                                    visible: !remBlock.isCompact
                                                    spacing: 4 * Appearance.effectiveScale
                                                    anchors {
                                                        top: parent.top
                                                        left: parent.left
                                                        right: parent.right
                                                    }

                                                    MaterialSymbol {
                                                        text: "alarm"
                                                        iconSize: 14 * Appearance.effectiveScale
                                                        color: Appearance.m3colors.m3onSecondaryContainer
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }

                                                    StyledText {
                                                        text: blockDelegate.rem.text
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        font.weight: Font.Medium
                                                        color: Appearance.m3colors.m3onSecondaryContainer
                                                        wrapMode: Text.Wrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                StyledText {
                                                    visible: !remBlock.isCompact
                                                    text: remBlock.timeStr
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSecondaryContainer, 0.75)
                                                    elide: Text.ElideRight
                                                    anchors {
                                                        top: remTitleRow.bottom
                                                        topMargin: 1 * Appearance.effectiveScale
                                                        left: parent.left
                                                        right: parent.right
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.openReminderEditorEdit(blockDelegate.rem.id)
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
                        visible: root.dayEvents.length === 0 && root.dayReminders.length === 0
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

            // ── Speed Dial FAB ──

            // Scrim (closes speed dial on outside click)
            MouseArea {
                id: fabScrim
                anchors.fill: parent
                visible: root._fabOpen
                z: 90
                onClicked: root._fabOpen = false
            }

            // Speed Dial container — anchored to bottom-right, same margin as FAB
            Item {
                id: fabSpeedDial
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 16 * Appearance.effectiveScale
                anchors.bottomMargin: 16 * Appearance.effectiveScale
                // Size matches the FAB so children can anchor to it
                width: 56 * Appearance.effectiveScale
                height: 56 * Appearance.effectiveScale
                z: 100

                // ── New Event pill (bottom slot, closest to FAB) ──
                RippleButton {
                    id: pillNewEvent
                    anchors.right: parent.right
                    readonly property real shownY: -(8 + 56) * Appearance.effectiveScale
                    y: root._fabOpen ? shownY : 0
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    opacity: root._fabOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    implicitHeight: 56 * Appearance.effectiveScale
                    implicitWidth: pillNewEventRow.implicitWidth + 48 * Appearance.effectiveScale
                    buttonRadius: 28 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3primaryContainer
                    colBackgroundHover: Functions.ColorUtils.mix(Appearance.m3colors.m3primaryContainer, Appearance.m3colors.m3onPrimaryContainer, 0.92)
                    colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onPrimaryContainer, 0.15)
                    onClicked: { root._fabOpen = false; root.openEditorNew(); }

                    RowLayout {
                        id: pillNewEventRow
                        anchors.centerIn: parent
                        spacing: 12 * Appearance.effectiveScale

                        MaterialSymbol {
                            text: "event"
                            iconSize: 24 * Appearance.effectiveScale
                            color: Appearance.m3colors.m3onPrimaryContainer
                        }
                        StyledText {
                            text: I18nService.tr("New Event")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onPrimaryContainer
                        }
                    }
                }

                // ── Reminder pill (top slot) ──
                RippleButton {
                    id: pillReminder
                    anchors.right: parent.right
                    readonly property real shownY: -(8 + 56 + 4 + 56) * Appearance.effectiveScale
                    y: root._fabOpen ? shownY : 0
                    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    opacity: root._fabOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    implicitHeight: 56 * Appearance.effectiveScale
                    implicitWidth: pillReminderRow.implicitWidth + 48 * Appearance.effectiveScale
                    buttonRadius: 28 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3primaryContainer
                    colBackgroundHover: Functions.ColorUtils.mix(Appearance.m3colors.m3primaryContainer, Appearance.m3colors.m3onPrimaryContainer, 0.92)
                    colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onPrimaryContainer, 0.15)
                    onClicked: root.openReminderEditorNew()

                    RowLayout {
                        id: pillReminderRow
                        anchors.centerIn: parent
                        spacing: 12 * Appearance.effectiveScale

                        MaterialSymbol {
                            text: "alarm"
                            iconSize: 24 * Appearance.effectiveScale
                            color: Appearance.m3colors.m3onPrimaryContainer
                        }
                        StyledText {
                            text: I18nService.tr("Reminder")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onPrimaryContainer
                        }
                    }
                }

            }

            // Main FAB
            StyledRectangularShadow {
                target: fabButton
                radius: fabButton.buttonRadius
                z: 101
            }

            RippleButton {
                id: fabButton
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 16 * Appearance.effectiveScale
                anchors.bottomMargin: 16 * Appearance.effectiveScale
                implicitWidth: 56 * Appearance.effectiveScale
                implicitHeight: 56 * Appearance.effectiveScale
                buttonRadius: root._fabOpen ? 28 * Appearance.effectiveScale : 16 * Appearance.effectiveScale
                colBackground: root._fabOpen ? Appearance.colors.colPrimary : Appearance.m3colors.m3primaryContainer
                Behavior on colBackground { ColorAnimation { duration: 200 } }
                colBackgroundHover: root._fabOpen
                    ? Functions.ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colOnPrimary, 0.92)
                    : Functions.ColorUtils.mix(Appearance.m3colors.m3primaryContainer, Appearance.m3colors.m3onPrimaryContainer, 0.92)
                colRipple: root._fabOpen
                    ? Functions.ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.15)
                    : Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onPrimaryContainer, 0.15)
                z: 102
                onClicked: root._fabOpen = !root._fabOpen

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root._fabOpen ? "close" : "add"
                    iconSize: 24 * Appearance.effectiveScale
                    color: root._fabOpen ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onPrimaryContainer
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on text {}
                }

                StyledToolTip {
                    text: root._fabOpen ? I18nService.tr("Close") : I18nService.tr("Add")
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
                    onClicked: {
                        DialogService.requestConfirmation({
                            titleText: I18nService.tr("Delete Event?"),
                            messageText: I18nService.tr("Are you sure you want to delete this event? This action cannot be undone."),
                            iconText: "delete",
                            isDestructive: true
                        }, () => root.deleteEditingEvent())
                    }

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

                Row {
                    spacing: 2 * Appearance.effectiveScale

                    Repeater {
                        model: ["once", "daily", "weekly", "monthly"]

                        delegate: SegmentedButton {
                            required property string modelData
                            readonly property bool _hidden: root._multiDayDiff > 0 && modelData !== "once"

                            visible: !_hidden
                            implicitHeight: 32 * Appearance.effectiveScale
                            checked: root.formRecurrence === modelData
                            buttonText: root._recurrenceLabel(modelData)
                            font.pixelSize: Appearance.font.pixelSize.small
                            leftPadding: 16 * Appearance.effectiveScale
                            rightPadding: 16 * Appearance.effectiveScale

                            onClicked: {
                                root.formRecurrence = modelData;
                                if (root._editingId)
                                    autoSaveTimer.restart();

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

    // ══════════════════════════════════════════════════
    //  PAGE 2: REMINDER EDITOR
    // ══════════════════════════════════════════════════
    Item {
        id: reminderEditorView
        anchors.fill: parent
        visible: root._view === "reminder-editor"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12 * Appearance.effectiveScale

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                RippleButton {
                    implicitWidth: 36 * Appearance.effectiveScale
                    implicitHeight: 36 * Appearance.effectiveScale
                    buttonRadius: 18 * Appearance.effectiveScale
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.backFromReminderEditor()

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.m3colors.m3onSurface
                    }
                    StyledToolTip { text: I18nService.tr("Back to schedule") }
                }

                StyledText {
                    text: root._editingReminderId ? I18nService.tr("Edit Reminder") : I18nService.tr("New Reminder")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.m3colors.m3onSurface
                    Layout.fillWidth: true
                }

                // Delete button (only when editing)
                RippleButton {
                    visible: root._editingReminderId !== ""
                    implicitWidth: 36 * Appearance.effectiveScale
                    implicitHeight: 36 * Appearance.effectiveScale
                    buttonRadius: 18 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainer
                    onClicked: {
                        DialogService.requestConfirmation({
                            titleText: I18nService.tr("Delete Reminder?"),
                            messageText: I18nService.tr("Are you sure you want to delete this reminder? This action cannot be undone."),
                            iconText: "delete",
                            isDestructive: true
                        }, () => root.deleteEditingReminder())
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.colors.colError
                    }
                    StyledToolTip { text: I18nService.tr("Delete reminder") }
                }
            }

            // ── Scrollable form ──
            StyledFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: reminderFormLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: reminderFormLayout
                    width: parent.width
                    spacing: 12 * Appearance.effectiveScale

                    // Reminder text
                    StyledTextInput {
                        id: reminderTextField
                        Layout.fillWidth: true
                        implicitHeight: 44 * Appearance.effectiveScale
                        inputRadius: Appearance.rounding.small / Appearance.effectiveScale
                        backgroundColor: Appearance.m3colors.m3surfaceContainer
                        placeholder: I18nService.tr("Remind me to...")
                        text: root.reminderText
                        onTextChanged: {
                            root.reminderText = text
                        }
                    }

                    // Date row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * Appearance.effectiveScale

                        StyledText {
                            text: I18nService.tr("Date:")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSurface
                            Layout.preferredWidth: 52 * Appearance.effectiveScale
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 40 * Appearance.effectiveScale
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.m3colors.m3surfaceContainer
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: root.openReminderDatePicker()

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * Appearance.effectiveScale
                                anchors.rightMargin: 12 * Appearance.effectiveScale
                                spacing: 8 * Appearance.effectiveScale

                                MaterialSymbol {
                                    text: "calendar_today"
                                    iconSize: 16 * Appearance.effectiveScale
                                    color: Appearance.m3colors.m3onSurface
                                }
                                StyledText {
                                    text: root._displayDate(root.reminderDate) || root.reminderDate
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSurface
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // Time row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * Appearance.effectiveScale

                        StyledText {
                            text: I18nService.tr("Time:")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSurface
                            Layout.preferredWidth: 52 * Appearance.effectiveScale
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 40 * Appearance.effectiveScale
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.m3colors.m3surfaceContainer
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: root.openReminderTimePicker()

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * Appearance.effectiveScale
                                anchors.rightMargin: 12 * Appearance.effectiveScale
                                spacing: 8 * Appearance.effectiveScale

                                MaterialSymbol {
                                    text: "schedule"
                                    iconSize: 16 * Appearance.effectiveScale
                                    color: Appearance.m3colors.m3onSurface
                                }
                                StyledText {
                                    text: root._displayTime(root.reminderTime) || root.reminderTime
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSurface
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // Type row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * Appearance.effectiveScale

                        StyledText {
                            text: I18nService.tr("Type:")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSurface
                            Layout.preferredWidth: 52 * Appearance.effectiveScale
                        }

                        StyledComboBox {
                            id: reminderTypeCombo
                            Layout.fillWidth: true
                            searchable: false
                            model: [I18nService.tr("Basic"), I18nService.tr("Notepad"), I18nService.tr("Todo")]
                            text: {
                                switch (root.reminderType) {
                                    case "notepad": return I18nService.tr("Notepad");
                                    case "todo": return I18nService.tr("Todo");
                                    default: return I18nService.tr("Basic");
                                }
                            }
                            colBackground: Appearance.m3colors.m3surfaceContainer
                            onAccepted: (val) => {
                                if (val === I18nService.tr("Notepad")) root.reminderType = "notepad";
                                else if (val === I18nService.tr("Todo")) root.reminderType = "todo";
                                else root.reminderType = "basic";
                                root.reminderLinkedId = "";
                                root.reminderLinkedTitle = "";
                            }
                        }
                    }

                    // Linked item row (shown only for notepad/todo types)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * Appearance.effectiveScale
                        visible: root.reminderType === "notepad" || root.reminderType === "todo"
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        StyledText {
                            text: root.reminderType === "notepad" ? I18nService.tr("Note:") : I18nService.tr("Task:")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSurface
                            Layout.preferredWidth: 52 * Appearance.effectiveScale
                        }

                        StyledComboBox {
                            id: linkedItemCombo
                            Layout.fillWidth: true
                            searchable: true

                            // Model: notepad item titles or todo task contents (truncated)
                            model: {
                                if (root.reminderType === "notepad") {
                                    return root.notepadItems.map(i => i.title || I18nService.tr("Untitled"));
                                } else if (root.reminderType === "todo") {
                                    const result = [];
                                    for (const task of root.todoItems) {
                                        if (!task || !task.content) continue;
                                        const content = task.content;
                                        result.push(content.length > 50 ? content.slice(0, 47) + "..." : content);
                                    }
                                    return result;
                                }
                                return [];
                            }

                            text: root.reminderLinkedTitle || ""
                            placeholder: root.reminderType === "notepad"
                                ? I18nService.tr("Select notepad...")
                                : I18nService.tr("Select task...")
                            colBackground: Appearance.m3colors.m3surfaceContainer

                            onAccepted: (val) => {
                                root.reminderLinkedTitle = val;
                                // Find linked ID
                                if (root.reminderType === "notepad") {
                                    const item = root.notepadItems.find(i =>
                                        (i.title || I18nService.tr("Untitled")) === val
                                    );
                                    root.reminderLinkedId = item ? item.id : "";
                                } else if (root.reminderType === "todo") {
                                    let foundId = "";
                                    for (const task of root.todoItems) {
                                        if (!task || !task.content) continue;
                                        const content = task.content;
                                        const truncated = content.length > 50 ? content.slice(0, 47) + "..." : content;
                                        if (truncated === val) { foundId = task.id; break; }
                                    }
                                    root.reminderLinkedId = foundId;
                                }
                            }
                        }
                    }

                    Item { implicitHeight: 8 * Appearance.effectiveScale }
                }
            }

            // ── Save button — pinned at bottom (outside scrollable area) ──
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 44 * Appearance.effectiveScale
                buttonRadius: 22 * Appearance.effectiveScale
                enabled: root.reminderText.trim() !== ""
                colBackground: Appearance.colors.colPrimary
                colRipple: Functions.ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.15)
                opacity: enabled ? 1 : 0.5
                onClicked: root.saveReminder()

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8 * Appearance.effectiveScale

                    MaterialSymbol {
                        text: "alarm_add"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        text: root._editingReminderId ? I18nService.tr("Update Reminder") : I18nService.tr("Set Reminder")
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }
}

