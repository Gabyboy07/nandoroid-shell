pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Provides current date and time using Quickshell's native C++ SystemClock
 * with declarative QML property bindings.
 */
Singleton {
    id: root

    property var clock: SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property date now: clock.date
    readonly property int hours: clock.date.getHours()
    readonly property int minutes: clock.date.getMinutes()
    readonly property int seconds: clock.date.getSeconds()

    readonly property string currentDate: Qt.formatDate(clock.date, Config.ready ? Config.dateFormat : "ddd, dd/MM")

    readonly property string currentTime: {
        const h = root.hours
        const m = root.minutes
        const is24 = Config.ready && Config.options.time ? Config.options.time.timeStyle === "24H" : true

        if (is24) {
            return h.toString().padStart(2, "0") + ":" + m.toString().padStart(2, "0")
        } else {
            const upper = Config.ready && Config.options.time ? Config.options.time.timeStyle === "12H_PM" : true
            const ap = h >= 12 ? (upper ? "PM" : "pm") : (upper ? "AM" : "am")
            const h12 = h % 12 || 12
            return h12.toString().padStart(2, "0") + ":" + m.toString().padStart(2, "0") + " " + ap
        }
    }

    readonly property string time12h: {
        const h = root.hours
        const m = root.minutes
        const h12 = h % 12 || 12
        return h12.toString().padStart(2, "0") + ":" + m.toString().padStart(2, "0") + " " + (h >= 12 ? "pm" : "am")
    }

    // Uptime calculation from /proc/uptime
    property string uptime: "0m"

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fileUptime.reload()
            const text = fileUptime.text()
            const secs = Number(text.split(" ")[0] ?? 0)
            const d = Math.floor(secs / 86400)
            const h = Math.floor((secs % 86400) / 3600)
            const m = Math.floor((secs % 3600) / 60)
            let fmt = ""
            if (d > 0) fmt += `${d}d`
            if (h > 0) fmt += `${fmt ? ", " : ""}${h}h`
            if (m > 0 || !fmt) fmt += `${fmt ? ", " : ""}${m}m`
            root.uptime = fmt
        }
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
    }
}
