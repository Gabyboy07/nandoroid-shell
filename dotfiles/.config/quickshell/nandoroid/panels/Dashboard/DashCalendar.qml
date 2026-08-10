import "../../core"
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts

/**
 * Dashboard Tab 0: Calendar (natural-height, square cells) + schedule summary
 * card (Now / Next today / Next / No schedule) + Pomodoro with arc ring.
 */
RowLayout {
    id: root

    readonly property string _todayStr: {
        const _ = DateTime.now;
        return root._fmtDate(DateTime.now);
    }
    // Recompute the summary card whenever the schedule / deadlines change or each minute.
    readonly property int _minuteTrigger: DateTime.minutes
    on_MinuteTriggerChanged: root._recomputeSummary()
    property var _scheduleTrigger: ScheduleService.events
    on_ScheduleTriggerChanged: root._recomputeSummary()
    property var _deadlineTrigger: GlobalStates.todoDeadlines
    on_DeadlineTriggerChanged: root._recomputeSummary()
    Component.onCompleted: root._recomputeSummary()
    // Build a flat list of all dates this event applies to (expand recurring)
    readonly property var eventDates: {
        let dates = [];
        for (let ev of ScheduleService.events) {
            if (!ev.date)
                continue;

            // Once multi-day: every day from date to endDate
            if (ev.recurrence === "once" && ev.endDate) {
                let d = new Date(ev.date + "T00:00:00");
                const end = new Date(ev.endDate + "T00:00:00");
                for (; d <= end; d.setDate(d.getDate() + 1)) dates.push(root._fmtDate(d))
                continue;
            }
            dates.push(ev.date);
            const limit = ev.endDate ? new Date(ev.endDate + "T00:00:00") : null;
            if (ev.recurrence === "daily") {
                let d = new Date(ev.date);
                d.setDate(d.getDate() + 1);
                for (let i = 0; i < 60; i++) {
                    if (limit && d > limit)
                        break;

                    dates.push(root._fmtDate(d));
                    d.setDate(d.getDate() + 1);
                }
            } else if (ev.recurrence === "weekly") {
                let d = new Date(ev.date);
                d.setDate(d.getDate() + 7);
                for (let i = 0; i < 8; i++) {
                    if (limit && d > limit)
                        break;

                    dates.push(root._fmtDate(d));
                    d.setDate(d.getDate() + 7);
                }
            } else if (ev.recurrence === "monthly") {
                let d = new Date(ev.date);
                for (let i = 0; i < 12; i++) {
                    d.setMonth(d.getMonth() + 1);
                    if (limit && d > limit)
                        break;

                    dates.push(root._fmtDate(d));
                }
            }
        }
        // Add todo deadline dates
        for (let dl of GlobalStates.todoDeadlines) {
            dates.push(dl.date);
        }
        return dates;
    }
    // Combined events for popup: schedule + todo deadlines
    readonly property var allEvents: {
        let combined = ScheduleService.events.slice();
        for (let dl of GlobalStates.todoDeadlines) {
            combined.push({
                "title": dl.taskContent || I18nService.tr("(untitled task)"),
                "description": I18nService.tr("From: ") + dl.itemTitle,
                "time": dl.time,
                "date": dl.date,
                "recurrence": "once"
            });
        }
        return combined;
    }
    property var _summary: {
        "state": "none"
    }
    property string _summaryIcon: "event_busy"
    property string _summaryTitle: ""
    property string _summarySub: ""
    // Filters allEvents (schedule + todo deadlines) for a given YYYY-MM-DD string.
    // Delegates recurrence matching to ScheduleService.eventOccursOn — single source of truth.
    function _getEventsForDate(dateStr) {
        return root.allEvents.filter(ev => ScheduleService.eventOccursOn(ev, dateStr));
    }

    function _recomputeSummary() {
        // Use DateTime.now (SystemClock boundary-aligned) instead of new Date():
        // SystemClock fires within ±50ms of the boundary, so new Date() can still
        // be the previous minute right after the trigger — causing a 1-minute lag.
        const now = DateTime.now;
        const nowFrac = (now.getHours() * 60 + now.getMinutes()) / 1440;
        const today = root._todayStr;
        const todays = root._getEventsForDate(today).slice().sort((a, b) => {
            return (a.time || "00:00").localeCompare(b.time || "00:00");
        });
        // Now: event whose start <= now and end > now
        for (let ev of todays) {
            const s = root._frac(ev.time) ?? 0;
            const e = root._frac(ev.endTime);
            const end = (e !== null && e > s) ? e : 1;
            if (nowFrac >= s && nowFrac < end) {
                root._summary = {
                    "state": "now",
                    "ev": ev
                };
                root._syncSummaryDisplay();
                return;
            }
        }
        // Next event today
        for (let ev of todays) {
            const s = root._frac(ev.time) ?? 0;
            if (s > nowFrac) {
                root._summary = {
                    "state": "nextToday",
                    "ev": ev
                };
                root._syncSummaryDisplay();
                return;
            }
        }
        // Next future event (bounded search)
        for (let i = 1; i <= 60; i++) {
            const d = new Date(now.getTime() + i * 8.64e+07);
            const ds = root._fmtDate(d);
            const evs = root._getEventsForDate(ds);
            if (evs.length) {
                evs.sort((a, b) => {
                    return (a.time || "00:00").localeCompare(b.time || "00:00");
                });
                root._summary = {
                    "state": "nextLater",
                    "ev": evs[0],
                    "dayStr": ds
                };
                root._syncSummaryDisplay();
                return;
            }
        }
        root._summary = {
            "state": "none"
        };
        root._syncSummaryDisplay();
    }
    function _syncSummaryDisplay() {
        const s = root._summary;
        switch (s.state) {
        case "now":
            root._summaryIcon = "timer";
            break;
        case "nextToday":
            root._summaryIcon = "today";
            break;
        case "nextLater":
            root._summaryIcon = "event";
            break;
        default:
            root._summaryIcon = "event_busy";
        }
        if (s.state === "none") {
            root._summaryTitle = I18nService.tr("No schedule");
            root._summarySub = I18nService.tr("No more events today");
            return;
        }

        root._summaryTitle = s.ev.title;
        const start = calWidget._displayTime(s.ev.time);
        const end = s.ev.endTime ? calWidget._displayTime(s.ev.endTime) : "";
        const range = end && end !== start ? start + " - " + end : start;
        if (s.state === "now")
            root._summarySub = I18nService.tr("Now") + " · " + range;
        else if (s.state === "nextToday")
            root._summarySub = I18nService.tr("Next today") + " · " + start;
        else
            root._summarySub = I18nService.tr("Next") + " · " + root._dayLabelFor(s.dayStr) + " · " + start;
    }
    // Compact calendar sizing — natural cells (like ii), always 6 rows → stable height
    readonly property real _cellSize: Math.round(38 * Appearance.effectiveScale)
    readonly property real _cellSpacing: 4 * Appearance.effectiveScale
    readonly property real _sectionSpacing: 16 * Appearance.effectiveScale
    readonly property real _calendarCardWidth: 7 * root._cellSize + 6 * root._cellSpacing + 24 * Appearance.effectiveScale

    signal jumpToSchedule()

    function _fmtDate(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, '0') + "-" + String(d.getDate()).padStart(2, '0');
    }

    // ── Summary card computation ──
    function _frac(t) {
        const p = String(t || "").split(":");
        if (p.length < 2)
            return null;

        const h = +p[0], m = +p[1];
        if (isNaN(h) || isNaN(m))
            return null;

        return (h * 60 + m) / 1440;
    }

    function _dayLabelFor(dateStr) {
        if (dateStr === root._todayStr)
            return I18nService.tr("Today");

        const tom = DateTime.now;
        tom.setDate(tom.getDate() + 1);
        if (dateStr === root._fmtDate(tom))
            return I18nService.tr("Tomorrow");

        const p = String(dateStr).split("-").map(Number);
        if (p.length < 3)
            return dateStr;

        const days = [I18nService.tr("Sun"), I18nService.tr("Mon"), I18nService.tr("Tue"), I18nService.tr("Wed"), I18nService.tr("Thu"), I18nService.tr("Fri"), I18nService.tr("Sat")];
        return days[new Date(p[0], p[1] - 1, p[2]).getDay()];
    }

    spacing: 12 * Appearance.effectiveScale

    TapHandler {
        onTapped: calWidget.closePopup()
    }

    // ── Left column: calendar card + separate schedule summary card ──
    // Calendar keeps its natural width; the pomodoro card fills the remaining space
    ColumnLayout {
        Layout.fillWidth: false
        Layout.preferredWidth: root._calendarCardWidth
        Layout.fillHeight: true
        spacing: 12 * Appearance.effectiveScale

        // Calendar card (always 6 rows → stable height across 5/6-row months)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            Item {
                anchors.fill: parent
                anchors.margins: 12 * Appearance.effectiveScale

                // Calendar at natural size, centred (ii-style: fixed cells, no stretching)
                CalendarWidget {
                    id: calWidget

                    anchors.centerIn: parent
                    width: Math.min(parent.width, implicitWidth)
                    height: implicitHeight
                    compact: true
                    cellSize: root._cellSize
                    cellSpacing: root._cellSpacing
                    sectionSpacing: root._sectionSpacing
                    eventDates: root.eventDates
                    scheduledEvents: root.allEvents
                }

            }

        }

        // Schedule summary card (own card, below the calendar)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56 * Appearance.effectiveScale
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            clip: true

            RippleButton {
                anchors.fill: parent
                buttonRadius: Appearance.rounding.normal
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.jumpToSchedule()

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14 * Appearance.effectiveScale
                    anchors.rightMargin: 6 * Appearance.effectiveScale
                    spacing: 10 * Appearance.effectiveScale

                    MaterialSymbol {
                        text: root._summaryIcon
                        iconSize: 22 * Appearance.effectiveScale
                        color: root._summary.state === "none" ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1 * Appearance.effectiveScale

                        StyledText {
                            Layout.fillWidth: true
                            text: root._summaryTitle
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.m3colors.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root._summarySub
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }

                    }

                    MaterialSymbol {
                        text: "chevron_right"
                        iconSize: 18 * Appearance.effectiveScale
                        color: Appearance.colors.colSubtext
                    }

                }

                StyledToolTip {
                    text: I18nService.tr("Open schedule")
                }

            }

        }

    }

    // ── Pomodoro with circle ring ──
    Rectangle {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        color: Appearance.m3colors.m3surfaceContainer
        radius: Appearance.rounding.normal
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16 * Appearance.effectiveScale
            spacing: 14 * Appearance.effectiveScale

            // ── Circular Arc Timer ──
            Item {
                readonly property int arcSize: Math.min(parent.width ?? 180 * Appearance.effectiveScale, 180 * Appearance.effectiveScale)

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: arcSize
                implicitHeight: arcSize

                // Background ring
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
                        ctx.strokeStyle = Appearance.m3colors.m3outlineVariant;
                        ctx.lineWidth = 7 * Appearance.effectiveScale;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }

                    Connections {
                        function onM3colorsChanged() {
                            bgRing.requestPaint();
                        }

                        target: Appearance
                    }

                }

                // Progress arc
                Canvas {
                    id: arcCanvas

                    readonly property real progress: PomodoroService.progress

                    anchors.fill: parent
                    onProgressChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (progress <= 0)
                            return ;

                        const cx = width / 2, cy = height / 2;
                        const r = Math.min(cx, cy) - 10 * Appearance.effectiveScale;
                        const start = -Math.PI / 2;
                        const end = start + progress * Math.PI * 2;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, start, end);
                        ctx.strokeStyle = Appearance.m3colors.m3primary;
                        ctx.lineWidth = 7 * Appearance.effectiveScale;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }

                    Connections {
                        function onM3colorsChanged() {
                            arcCanvas.requestPaint();
                        }

                        target: Appearance
                    }

                }

                // Centre text
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: PomodoroService.timeString
                        font.pixelSize: Math.round(32 * Appearance.effectiveScale)
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: I18nService.tr(PomodoroService.modeName)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                }

                // Cycle badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 8 * Appearance.effectiveScale
                    anchors.bottomMargin: 8 * Appearance.effectiveScale
                    visible: PomodoroService.rotations > 0
                    width: 22 * Appearance.effectiveScale
                    height: 22 * Appearance.effectiveScale
                    radius: width / 2
                    color: Appearance.m3colors.m3secondaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: PomodoroService.rotations
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }

                }

            }

            // ── Mode selector ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 4 * Appearance.effectiveScale

                Repeater {
                    model: [{
                        "icon": "alarm",
                        "name": I18nService.tr("Focus"),
                        "mode": 0
                    }, {
                        "icon": "coffee",
                        "name": I18nService.tr("Short"),
                        "mode": 1
                    }, {
                        "icon": "self_improvement",
                        "name": I18nService.tr("Long"),
                        "mode": 2
                    }]

                    delegate: SegmentedButton {
                        Layout.fillWidth: true
                        implicitHeight: 32 * Appearance.effectiveScale
                        isHighlighted: PomodoroService.mode === modelData.mode
                        iconName: modelData.icon
                        iconSize: 18 * Appearance.effectiveScale
                        spacing: 5 * Appearance.effectiveScale
                        buttonText: modelData.name
                        colInactive: Appearance.m3colors.m3surfaceContainerHigh
                        onClicked: PomodoroService.setMode(modelData.mode)

                        StyledToolTip {
                            text: modelData.name
                        }

                    }

                }

            }

            // ── Controls ──
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12 * Appearance.effectiveScale

                M3IconButton {
                    iconName: "stop"
                    onClicked: PomodoroService.stop()

                    StyledToolTip {
                        text: I18nService.tr("Stop & Reset")
                    }

                }

                RippleButton {
                    id: startPill

                    implicitWidth: 140 * Appearance.effectiveScale
                    implicitHeight: 44 * Appearance.effectiveScale
                    buttonRadius: 22 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3primary
                    onClicked: PomodoroService.active ? PomodoroService.pause() : PomodoroService.start()

                    contentItem: RowLayout {
                        spacing: 8 * Appearance.effectiveScale
                        Layout.alignment: Qt.AlignHCenter

                        MaterialSymbol {
                            text: PomodoroService.active ? "pause" : "play_arrow"
                            iconSize: 20 * Appearance.effectiveScale
                            color: Appearance.m3colors.m3onPrimary
                        }

                        StyledText {
                            text: PomodoroService.active ? I18nService.tr("Pause") : I18nService.tr("Start")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.m3colors.m3onPrimary
                        }

                    }

                }

                M3IconButton {
                    iconName: "refresh"
                    onClicked: {
                        PomodoroService.reset();
                        PomodoroService.rotations = 0;
                    }

                    StyledToolTip {
                        text: I18nService.tr("Reset Everything")
                    }

                }

            }

            // ── Auto-continue toggle + next-break selector ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6 * Appearance.effectiveScale

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: I18nService.tr("Auto-continue")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        verticalAlignment: Text.AlignVCenter
                    }

                    RippleButton {
                        implicitWidth: 40 * Appearance.effectiveScale
                        implicitHeight: 22 * Appearance.effectiveScale
                        buttonRadius: 11 * Appearance.effectiveScale
                        colBackground: PomodoroService.autoContinue ? Appearance.m3colors.m3primary : Appearance.m3colors.m3surfaceContainerHigh
                        onClicked: PomodoroService.autoContinue = !PomodoroService.autoContinue

                        Rectangle {
                            x: PomodoroService.autoContinue ? parent.width - width - 3 * Appearance.effectiveScale : 3 * Appearance.effectiveScale
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16 * Appearance.effectiveScale
                            height: 16 * Appearance.effectiveScale
                            radius: Appearance.rounding.verysmall
                            color: PomodoroService.autoContinue ? Appearance.m3colors.m3onPrimary : Appearance.colors.colSubtext

                            Behavior on x {
                                NumberAnimation {
                                    duration: 180
                                }

                            }

                        }

                    }

                }

                // Next break selector (shown when auto-continue is on)
                RowLayout {
                    Layout.fillWidth: true
                    visible: PomodoroService.autoContinue

                    StyledText {
                        Layout.fillWidth: true
                        text: I18nService.tr("Next Break")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        verticalAlignment: Text.AlignVCenter
                    }

                    RowLayout {
                        spacing: 4 * Appearance.effectiveScale

                        Repeater {
                            model: [{
                                "icon": "coffee",
                                "name": I18nService.tr("Short"),
                                "mode": 1
                            }, {
                                "icon": "self_improvement",
                                "name": I18nService.tr("Long"),
                                "mode": 2
                            }]

                            delegate: SegmentedButton {
                                implicitWidth: 72 * Appearance.effectiveScale
                                implicitHeight: 24 * Appearance.effectiveScale
                                isHighlighted: PomodoroService.nextBreakMode === modelData.mode
                                iconName: modelData.icon
                                buttonText: modelData.name
                                iconSize: 11 * Appearance.effectiveScale
                                colInactive: Appearance.m3colors.m3surfaceContainerHigh
                                colActive: Appearance.m3colors.m3secondary
                                colActiveText: Appearance.m3colors.m3onSecondary
                                onClicked: PomodoroService.nextBreakMode = modelData.mode
                            }

                        }

                    }

                }

            }

        }

    }

}
