import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Properties ──
    property var items: []
    // List of Kanban cards
    property string _editingId: ""
    property string hoveredStatus: ""
    property string hoveredTargetId: ""
    property string draggedTaskId: ""
    property alias dragOverlay: dragOverlayItem
    readonly property string storagePath: Functions.FileUtils.trimFileProtocol(Directories.home) + "/.cache/nandoroid/todo.json"
    readonly property string oldStoragePath: Functions.FileUtils.trimFileProtocol(Directories.home) + "/.cache/nandoroid/notes.json"
    property int _idCounter: 0

    function makeId() {
        root._idCounter++;
        return Date.now().toString(36) + "_" + root._idCounter.toString(36) + Math.random().toString(36).substr(2, 5);
    }

    function save() {
        const clean = root.items.map((i) => {
            const c = {
            };
            for (const key in i) {
                if (key.startsWith("_"))
                    continue;

                c[key] = i[key];
            }
            return c;
        });
        todoFile.setText(JSON.stringify(clean, null, 2));
    }

    // ── Migration Script ──
    function _runMigration() {
        try {
            let notesText = notesFile.text();
            if (!notesText || notesText.trim() === "")
                return ;

            let allNotes = JSON.parse(notesText);
            if (!Array.isArray(allNotes))
                return ;

            let migratedTasks = [];
            let remainingNotes = [];
            for (let note of allNotes) {
                if (note.type === "todo") {
                    if (Array.isArray(note.tasks)) {
                        for (let task of note.tasks) {
                            migratedTasks.push({
                                "id": task.id || makeId(),
                                "content": task.content || "",
                                "status": task.done ? "done" : "todo",
                                "updatedAt": task.deadlineTime || note.updatedAt || new Date().toISOString()
                            });
                        }
                    }
                } else {
                    remainingNotes.push(note);
                }
            }
            if (migratedTasks.length > 0) {
                root.items = migratedTasks;
                save(); // Save to todo.json
                notesFile.setText(JSON.stringify(remainingNotes, null, 2)); // Remove from notes.json
            } else {
                root.items = [];
                save();
            }
        } catch (e) {
            console.log("Migration failed: ", e);
        }
    }

    // ── Kanban Operations ──
    function addTask(content) {
        if (!content || content.trim() === "")
            return ;

        const t = {
            "id": makeId(),
            "content": content,
            "status": "todo",
            "updatedAt": new Date().toISOString()
        };
        root.items = [t].concat(root.items);
        save();
    }

    function moveTaskBefore(taskId, newStatus, targetId) {
        let taskIndex = root.items.findIndex((i) => {
            return i.id === taskId;
        });
        if (taskIndex === -1)
            return ;

        let task = root.items[taskIndex];
        task.status = newStatus;
        task.updatedAt = new Date().toISOString();
        root.items.splice(taskIndex, 1);
        if (targetId && targetId !== "") {
            let targetIndex = root.items.findIndex((i) => {
                return i.id === targetId;
            });
            if (targetIndex !== -1)
                root.items.splice(targetIndex, 0, task);
            else
                root.items.push(task);
        } else {
            root.items.push(task);
        }
        root.items = root.items.slice();
        save();
    }

    function deleteTask(id) {
        root.items = root.items.filter((i) => {
            return i.id !== id;
        });
        save();
    }

    Component.onCompleted: todoFile.reload()

    // ── File I/O ──
    FileView {
        id: notesFile

        path: root.oldStoragePath
        watchChanges: false
    }

    FileView {
        id: todoFile

        path: root.storagePath
        watchChanges: false
        onLoaded: {
            try {
                let text = todoFile.text();
                if (!text || text.trim() === "") {
                    _runMigration();
                } else {
                    let parsed = JSON.parse(text);
                    if (Array.isArray(parsed))
                        root.items = parsed;

                }
            } catch (e) {
                console.warn("Error loading todo.json: ", e);
                _runMigration(); // Fallback to migration if invalid/empty
            }
        }
    }

    // ── UI Components ──
    Component {
        id: cardDelegate

        Item {
            id: delegateRoot

            required property var modelData
            property bool dragging: false
            property var pressPos: Qt.point(0, 0)
            property int dragThreshold: 5
            property Item originalParent: null

            Layout.fillWidth: true
            // Auto collapse when dragged, and expand when hovered
            implicitHeight: dragging ? 0 : (cardRect.implicitHeight + (cardDropArea.dragEntered && delegateRoot.modelData.id !== root.draggedTaskId ? 48 * Appearance.effectiveScale : 0))

            DropArea {
                id: cardDropArea

                property bool dragEntered: containsDrag

                enabled: !delegateRoot.dragging
                anchors.fill: parent
                keys: ["task"]
                onEntered: {
                    if (delegateRoot.modelData.id !== root.draggedTaskId) {
                        root.hoveredTargetId = delegateRoot.modelData.id;
                        root.hoveredStatus = delegateRoot.modelData.status;
                    }
                }
                onExited: {
                    if (root.hoveredTargetId === delegateRoot.modelData.id)
                        root.hoveredTargetId = "";

                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 4 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3primary
                    visible: cardDropArea.dragEntered && delegateRoot.modelData.id !== root.draggedTaskId
                    radius: Appearance.rounding.small
                }

            }

            Rectangle {
                id: cardRect

                // Slide down to create a gap when hovered
                transform: Translate { y: (cardDropArea.dragEntered && delegateRoot.modelData.id !== root.draggedTaskId) ? 48 * Appearance.effectiveScale : 0; Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                width: delegateRoot.width
                implicitHeight: cardCol.implicitHeight + 24 * Appearance.effectiveScale
                radius: Appearance.rounding.small
                color: Appearance.m3colors.m3surfaceContainerHigh
                // Highlight while dragging
                border.width: delegateRoot.dragging ? Math.max(1, 2 * Appearance.effectiveScale) : 0
                border.color: Appearance.colors.colPrimary
                scale: delegateRoot.dragging ? 1.02 : 1
                opacity: delegateRoot.dragging ? 0.9 : 1
                Drag.active: delegateRoot.dragging
                Drag.source: delegateRoot
                Drag.keys: ["task"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                MouseArea {
                    id: cardDragArea

                    anchors.fill: parent
                    cursorShape: delegateRoot.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: delegateRoot.dragging ? cardRect : null
                    drag.threshold: 0
                    onPressed: (mouse) => {
                        delegateRoot.pressPos = Qt.point(mouse.x, mouse.y);
                        root.draggedTaskId = delegateRoot.modelData.id;
                    }
                    onPositionChanged: (mouse) => {
                        if (!delegateRoot.dragging) {
                            const dx = mouse.x - delegateRoot.pressPos.x;
                            const dy = mouse.y - delegateRoot.pressPos.y;
                            if (Math.sqrt(dx * dx + dy * dy) > delegateRoot.dragThreshold) {
                                delegateRoot.dragging = true;
                                delegateRoot.originalParent = cardRect.parent;
                                const globalPos = cardRect.mapToItem(root.dragOverlay, 0, 0);
                                cardRect.parent = root.dragOverlay;
                                cardRect.x = globalPos.x;
                                cardRect.y = globalPos.y;
                            }
                        }
                    }
                    onReleased: {
                        if (delegateRoot.dragging) {
                            const targetStatus = root.hoveredStatus;
                            const targetId = root.hoveredTargetId;
                            const currentId = delegateRoot.modelData.id;
                            delegateRoot.dragging = false;
                            root.draggedTaskId = "";
                            root.hoveredTargetId = "";
                            if (cardRect) {
                                cardRect.parent = delegateRoot.originalParent;
                                cardRect.x = 0;
                                cardRect.y = 0;
                            }
                            if (targetStatus !== "")
                                root.moveTaskBefore(currentId, targetStatus, targetId);

                        } else {
                            root.draggedTaskId = "";
                        }
                    }
                }

                ColumnLayout {
                    id: cardCol

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12 * Appearance.effectiveScale
                    spacing: 8 * Appearance.effectiveScale

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * Appearance.effectiveScale

                        StyledTextInput {
                            Layout.fillWidth: true
                            text: delegateRoot.modelData.content
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                            backgroundColor: "transparent"
                            showActiveBorder: false
                            leftMargin: 0
                            rightMargin: 0
                            onEditingFinished: {
                                if (text.trim() !== delegateRoot.modelData.content) {
                                    const newText = text.trim() === "" ? I18nService.tr("New task") : text.trim();
                                    const item = root.items.find((i) => {
                                        return i.id === delegateRoot.modelData.id;
                                    });
                                    if (item) {
                                        item.content = newText;
                                        item.updatedAt = new Date().toISOString();
                                        root.items = root.items.slice();
                                        root.save();
                                    }
                                }
                            }
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4 * Appearance.effectiveScale

                        // spacer
                        Item {
                            Layout.fillWidth: true
                        }

                        // Delete
                        RippleButton {
                            implicitWidth: 24 * Appearance.effectiveScale
                            implicitHeight: 24 * Appearance.effectiveScale
                            buttonRadius: 12 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: {
                                DialogService.requestConfirmation({
                                    "titleText": I18nService.tr("Delete Task?"),
                                    "messageText": I18nService.tr("Are you sure you want to delete this task? This action cannot be undone."),
                                    "iconText": "delete",
                                    "isDestructive": true
                                }, () => {
                                    return root.deleteTask(delegateRoot.modelData.id);
                                });
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: 14 * Appearance.effectiveScale
                                color: Appearance.colors.colError
                            }

                        }

                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // ── Main UI ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 12 * Appearance.effectiveScale

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12 * Appearance.effectiveScale

            Repeater {
                model: [{
                    "title": I18nService.tr("To Do"),
                    "status": "todo",
                    "color": Appearance.m3colors.m3error,
                    "icon": "schedule",
                    "shape": MaterialShape.Shape.Clover4Leaf
                }, {
                    "title": I18nService.tr("Ongoing"),
                    "status": "doing",
                    "color": Appearance.colors.colWarning,
                    "icon": "hourglass_bottom",
                    "shape": MaterialShape.Shape.Cookie12Sided
                }, {
                    "title": I18nService.tr("Done"),
                    "status": "done",
                    "color": Appearance.m3colors.m3primary,
                    "icon": "check_circle",
                    "shape": MaterialShape.Shape.Squircle
                }]

                delegate: DropArea {
                    property bool dragEntered: containsDrag

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    keys: ["task"]
                    onEntered: root.hoveredStatus = modelData.status
                    onExited: {
                        if (root.hoveredStatus === modelData.status)
                            root.hoveredStatus = "";

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: parent.dragEntered ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainer

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8 * Appearance.effectiveScale
                            spacing: 12 * Appearance.effectiveScale

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52 * Appearance.effectiveScale
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12 * Appearance.effectiveScale
                                    anchors.rightMargin: 12 * Appearance.effectiveScale
                                    anchors.topMargin: 8 * Appearance.effectiveScale
                                    anchors.bottomMargin: 8 * Appearance.effectiveScale
                                    spacing: 12 * Appearance.effectiveScale

                                    Row {
                                        spacing: 4 * Appearance.effectiveScale
                                        Layout.alignment: Qt.AlignVCenter

                                        StyledText {
                                            text: modelData.title
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: `(${root.items.filter(i => i.status === modelData.status).length})`
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer1
                                            opacity: 0.5
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }

                                    // spacer
                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    RippleButton {
                                        implicitWidth: 32 * Appearance.effectiveScale
                                        implicitHeight: 32 * Appearance.effectiveScale
                                        buttonRadius: 8 * Appearance.effectiveScale
                                        colBackground: Appearance.colors.colPrimary
                                        onClicked: {
                                            const t = {
                                                "id": root.makeId(),
                                                "content": I18nService.tr("New task"),
                                                "status": modelData.status,
                                                "updatedAt": new Date().toISOString()
                                            };
                                            root.items = [t].concat(root.items);
                                            root.save();
                                        }

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "add"
                                            iconSize: 20 * Appearance.effectiveScale
                                            color: Appearance.colors.colOnPrimary
                                        }

                                    }

                                }

                            }

                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: cardListCol.implicitHeight
                                clip: true

                                ColumnLayout {
                                    id: cardListCol

                                    width: parent.width
                                    spacing: 8 * Appearance.effectiveScale

                                    Repeater {
                                        model: root.items.filter((i) => {
                                            return i.status === modelData.status;
                                        })
                                        delegate: cardDelegate
                                    }

                                }

                                ScrollBar.vertical: StyledScrollBar {
                                }

                            }

                        }

                    }

                }

            }

        }

    }

    Item {
        id: dragOverlayItem

        anchors.fill: parent
        z: 9999
    }

}
