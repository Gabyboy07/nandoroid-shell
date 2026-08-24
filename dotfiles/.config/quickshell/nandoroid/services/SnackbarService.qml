pragma Singleton

import QtQuick
import Quickshell
import "../core"

/**
 * Snackbar Service — global Material 3 snackbar.
 * Transient bottom-center feedback with optional action button.
 * DND-proof by design: rendered by the shell itself, never goes through
 * the notification pipeline (SmartAutomation/Notifications can't suppress it).
 *
 * Usage: SnackbarService.show("Text", "Action", () => { ... })
 */
Singleton {
    id: root

    readonly property int duration: 4000
    property bool visible: false
    property string text: ""
    property string actionLabel: ""
    property var _actionCallback: null

    // Incremented per show()/dismiss(); stale timer ticks are ignored
    property int _generation: 0

    function show(message, actionLabel, actionCallback) {
        root._generation++;
        root.text = message || "";
        root.actionLabel = actionLabel || "";
        root._actionCallback = (root.actionLabel !== "" && typeof actionCallback === "function") ? actionCallback : null;
        root.visible = true;
        dismissTimer.restart();
    }

    function dismiss() {
        root._generation++;
        root.visible = false;
        dismissTimer.stop();
    }

    function triggerAction() {
        const cb = root._actionCallback;
        root.dismiss();
        if (cb) cb();
    }

    Timer {
        id: dismissTimer
        interval: root.duration
        repeat: false
        onTriggered: root.dismiss()
    }
}
