pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Alarm Service — standalone Android-style alarms (DashClock > Alarm tab).
 * Own persistence, own firing timer; completely independent from reminders.
 * Bypasses DND entirely: dedicated panel + looping ringtone via ffplay,
 * no involvement of the notification pipeline.
 *
 * Schema per alarm:
 * {
 *   id           : string   — unique ID
 *   label        : string   — optional name shown on the alarm panel
 *   time         : string   — "HH:MM" (24h)
 *   enabled      : bool
 *   days         : number[] — 0=Sun..6=Sat; empty = one-shot (auto-disables after ring)
 *   lastFiredKey : string   — "YYYY-MM-DD HH:MM" guard against double-firing
 * }
 *
 * Note: accurate only while the system is awake (no wake-from-suspend yet).
 */
Singleton {
    id: root

    property var alarms: []
    onAlarmsChanged: root._scheduleNext()

    readonly property string storagePath: Directories.home.replace("file://", "") + "/.cache/nandoroid/alarms.json"

    // "" | "ringing" | "snoozed"
    property string alarmState: ""
    readonly property bool ringing: alarmState === "ringing"
    readonly property bool snoozed: alarmState === "snoozed"

    property string message: "" // alarm label shown on the panel
    property string snoozeUntil: "" // HH:MM display of next ring

    readonly property int defaultSnoozeMinutes: 5

    readonly property string defaultRingtoneBase: `/usr/share/sounds/${Audio.audioTheme}/stereo/alarm-clock-elapsed`
    readonly property string ringtonePath: {
        const custom = (Config.ready && Config.options.sounds) ? Config.options.sounds.ringtone : "";
        return custom !== "" ? custom : "";
    }
    // Resolve .oga/.ogg at runtime for theme defaults (oxygen ships only .ogg)
    readonly property var ringtoneCommand: root.ringtonePath !== ""
        ? ["ffplay", "-nodisp", "-autoexit", "-loop", "0", root.ringtonePath]
        : ["bash", "-c", `f='${root.defaultRingtoneBase}.oga'; [ -f "$f" ] || f='${root.defaultRingtoneBase}.ogg'; exec ffplay -nodisp -autoexit -loop 0 "$f"`]

    property var _pendingAlarm: null

    // ── CRUD ──
    function save() {
        alarmFile.setText(JSON.stringify(root.alarms, null, 2));
    }

    function addAlarm(alarm) {
        root.alarms = [...root.alarms, alarm];
        save();
    }

    function updateAlarm(id, updatedFields) {
        root.alarms = root.alarms.map(a => a.id === id ? Object.assign({}, a, updatedFields) : a);
        save();
    }

    function deleteAlarm(id) {
        root.alarms = root.alarms.filter(a => a.id !== id);
        save();
    }

    function toggleAlarm(id) {
        const a = root.alarms.find(x => x.id === id);
        if (!a) return;
        // Clearing lastFiredKey restores the Dismiss affordance for the
        // upcoming occurrence after an off→on cycle
        updateAlarm(id, { enabled: !a.enabled, lastFiredKey: "" });
    }

    // ── Firing: event-driven single-shot scheduling (zero periodic polling) ──
    // The timer is armed exactly for the earliest upcoming occurrence and
    // re-armed whenever alarms change, after a ring, or after a snooze.
    property var _scheduledTarget: null

    function _nextOccurrence(alarm, from) {
        const now = from || new Date();
        const parts = String(alarm.time || "").split(":").map(Number);
        for (let i = 0; i < 8; i++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, parts[0] || 0, parts[1] || 0);
            if (d <= now) continue;
            if (alarm.days && alarm.days.length > 0 && !alarm.days.includes(d.getDay())) continue;
            const key = Qt.formatDate(d, "yyyy-MM-dd") + " " + Qt.formatTime(d, "HH:mm");
            if (alarm.lastFiredKey && alarm.lastFiredKey === key) continue;
            return d;
        }
        return null;
    }

    function _scheduleNext() {
        let best = null;
        for (let i = 0; i < root.alarms.length; i++) {
            if (!root.alarms[i].enabled) continue;
            const d = root._nextOccurrence(root.alarms[i], new Date());
            if (d !== null && (best === null || d < best)) best = d;
        }
        root._scheduledTarget = best;
        if (best === null) {
            fireTimer.running = false;
            return;
        }
        // Fires late after suspend — the handler still rings the missed target
        fireTimer.interval = Math.max(250, best.getTime() - Date.now());
        fireTimer.running = true;
    }

    function ring(alarm) {
        root._pendingAlarm = alarm || null;
        root.message = alarm ? (alarm.label || "") : "";
        root.snoozeUntil = "";
        root.alarmState = "ringing";
        ringProc.command = root.ringtoneCommand;
        ringProc.running = true;
    }

    function stop() {
        ringProc.running = false;
        snoozeTimer.stop();
        root._pendingAlarm = null;
        root.alarmState = "";
        root.snoozeUntil = "";
    }

    function snooze(minutes) {
        const mins = minutes > 0 ? minutes : root.defaultSnoozeMinutes;
        const until = new Date(Date.now() + mins * 60000);
        root.snoozeUntil = Qt.formatTime(until, "HH:mm");
        ringProc.running = false;
        root.alarmState = "snoozed";
        snoozeTimer.interval = mins * 60000;
        snoozeTimer.restart();
        SnackbarService.show(
            I18nService.tr("Snoozed until") + " " + root.snoozeUntil,
            I18nService.tr("Stop"),
            () => root.stop()
        );
    }

    Timer {
        id: fireTimer
        interval: 60000
        repeat: false
        running: false
        onTriggered: {
            // Ring the scheduled target regardless of lateness (suspend-safe),
            // guarded by lastFiredKey against double-firing
            if (root._scheduledTarget !== null && !root.ringing) {
                const target = root._scheduledTarget;
                const timeStr = Qt.formatTime(target, "HH:mm");
                const key = Qt.formatDate(target, "yyyy-MM-dd") + " " + timeStr;

                for (let i = 0; i < root.alarms.length; i++) {
                    const a = root.alarms[i];
                    if (!a.enabled || a.time !== timeStr) continue;
                    if (a.days && a.days.length > 0 && !a.days.includes(target.getDay())) continue;
                    if (a.lastFiredKey === key) continue;

                    const isOneShot = !a.days || a.days.length === 0;
                    updateAlarm(a.id, { lastFiredKey: key, enabled: isOneShot ? false : a.enabled });
                    root.ring(a);
                    break;
                }
            }
            root._scheduleNext();
        }
    }

    Timer {
        id: snoozeTimer
        interval: root.defaultSnoozeMinutes * 60000
        repeat: false
        onTriggered: root.ring(root._pendingAlarm)
    }

    Process {
        id: ringProc
        command: []
        running: false
    }

    property bool _created: false

    FileView {
        id: alarmFile
        path: root.storagePath
        watchChanges: false
        printErrors: false
        blockWrites: true
        onLoaded: {
            try {
                const content = alarmFile.text();
                if (content && content.trim() !== "") {
                    const parsed = JSON.parse(content);
                    if (Array.isArray(parsed)) root.alarms = parsed;
                }
            } catch (e) {
                console.warn("AlarmService: failed to parse alarms.json:", e);
            }
        }
        onLoadFailed: {
            if (root._created) return;
            root._created = true;
            alarmFile.setText("[]");
            alarmFile.reload();
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", storagePath.substring(0, storagePath.lastIndexOf('/'))]);
        alarmFile.reload();
    }
}
