import "../../core"
import "../../widgets"
import "../../services"
import "../../core/functions" as Functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Properties ──
    property var items: [] // List of Kanban cards
    property string _editingId: ""

    readonly property string storagePath: Directories.home.replace("file://", "") + "/.cache/nandoroid/todo.json"
    readonly property string oldStoragePath: Directories.home.replace("file://", "") + "/.cache/nandoroid/notes.json"

    function makeId() { return Date.now().toString(36) + Math.random().toString(36).substr(2,5) }

    function save() {
        const clean = root.items.map(i => {
            const c = {}
            for (const key in i) {
                if (key.startsWith("_")) continue
                c[key] = i[key]
            }
            return c
        })
        todoFile.setText(JSON.stringify(clean, null, 2))
    }

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
                let text = todoFile.text()
                if (!text || text.trim() === "") {
                    _runMigration()
                } else {
                    let parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.items = parsed
                    }
                }
            } catch(e) {
                console.log("Error loading todo.json: ", e)
                _runMigration() // Fallback to migration if invalid/empty
            }
        }
    }

    Component.onCompleted: todoFile.reload()

    // ── Migration Script ──
    function _runMigration() {
        try {
            let notesText = notesFile.text()
            if (!notesText || notesText.trim() === "") return
            
            let allNotes = JSON.parse(notesText)
            if (!Array.isArray(allNotes)) return
            
            let migratedTasks = []
            let remainingNotes = []
            
            for (let note of allNotes) {
                if (note.type === "todo") {
                    if (Array.isArray(note.tasks)) {
                        for (let task of note.tasks) {
                            migratedTasks.push({
                                id: task.id || makeId(),
                                content: task.content || "",
                                status: task.done ? "done" : "todo",
                                updatedAt: task.deadlineTime || note.updatedAt || new Date().toISOString()
                            })
                        }
                    }
                } else {
                    remainingNotes.push(note)
                }
            }
            
            if (migratedTasks.length > 0) {
                root.items = migratedTasks
                save() // Save to todo.json
                notesFile.setText(JSON.stringify(remainingNotes, null, 2)) // Remove from notes.json
            } else {
                root.items = []
                save()
            }
        } catch (e) {
            console.log("Migration failed: ", e)
        }
    }

    // ── Kanban Operations ──
    function addTask(content) {
        if (!content || content.trim() === "") return
        const t = { id: makeId(), content: content, status: "todo", updatedAt: new Date().toISOString() }
        root.items = [t].concat(root.items)
        save()
    }

    function moveTask(id, newStatus) {
        const item = root.items.find(i => i.id === id)
        if (item) {
            item.status = newStatus
            item.updatedAt = new Date().toISOString()
            root.items = root.items.slice()
            save()
        }
    }

    function deleteTask(id) {
        root.items = root.items.filter(i => i.id !== id)
        save()
    }

    // ── UI Components ──
    Component {
        id: cardDelegate
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: cardCol.implicitHeight + 24 * Appearance.effectiveScale
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3surfaceContainerHigh

            ColumnLayout {
                id: cardCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12 * Appearance.effectiveScale
                spacing: 8 * Appearance.effectiveScale

                StyledTextInput {
                    Layout.fillWidth: true
                    text: modelData.content
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    backgroundColor: "transparent"
                    showActiveBorder: false
                    leftMargin: 0
                    rightMargin: 0

                    onEditingFinished: {
                        if (text.trim() !== modelData.content) {
                            const newText = text.trim() === "" ? I18nService.tr("New task") : text.trim()
                            const item = root.items.find(i => i.id === modelData.id)
                            if (item) {
                                item.content = newText
                                item.updatedAt = new Date().toISOString()
                                root.items = root.items.slice()
                                root.save()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4 * Appearance.effectiveScale

                    Item { Layout.fillWidth: true } // spacer

                    // Move Left
                    RippleButton {
                        implicitWidth: 24 * Appearance.effectiveScale
                        implicitHeight: 24 * Appearance.effectiveScale
                        buttonRadius: 12 * Appearance.effectiveScale
                        colBackground: "transparent"
                        visible: modelData.status !== "todo"
                        onClicked: {
                            if (modelData.status === "doing") root.moveTask(modelData.id, "todo")
                            else if (modelData.status === "done") root.moveTask(modelData.id, "doing")
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            iconSize: 14 * Appearance.effectiveScale
                            color: Appearance.colors.colSubtext
                        }
                    }
                    
                    // Move Right
                    RippleButton {
                        implicitWidth: 24 * Appearance.effectiveScale
                        implicitHeight: 24 * Appearance.effectiveScale
                        buttonRadius: 12 * Appearance.effectiveScale
                        colBackground: "transparent"
                        visible: modelData.status !== "done"
                        onClicked: {
                            if (modelData.status === "todo") root.moveTask(modelData.id, "doing")
                            else if (modelData.status === "doing") root.moveTask(modelData.id, "done")
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_forward"
                            iconSize: 14 * Appearance.effectiveScale
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // Delete
                    RippleButton {
                        implicitWidth: 24 * Appearance.effectiveScale
                        implicitHeight: 24 * Appearance.effectiveScale
                        buttonRadius: 12 * Appearance.effectiveScale
                        colBackground: "transparent"
                        onClicked: root.deleteTask(modelData.id)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: 14 * Appearance.effectiveScale
                            color: Appearance.colors.colError
                        }
                    }
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
                model: [
                    { title: I18nService.tr("To Do"), status: "todo", color: Appearance.m3colors.m3error, icon: "schedule", shape: MaterialShape.Shape.Clover4Leaf },
                    { title: I18nService.tr("Ongoing"), status: "doing", color: Appearance.colors.colWarning, icon: "hourglass_bottom", shape: MaterialShape.Shape.Cookie12Sided },
                    { title: I18nService.tr("Done"), status: "done", color: Appearance.m3colors.m3primary, icon: "check_circle", shape: MaterialShape.Shape.Squircle }
                ]
                delegate: Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainer // Ensure board has a visible color

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

                                Item { Layout.fillWidth: true } // spacer
                               
                                RippleButton {
                                    implicitWidth: 32 * Appearance.effectiveScale
                                    implicitHeight: 32 * Appearance.effectiveScale
                                    buttonRadius: 8 * Appearance.effectiveScale
                                    colBackground: Appearance.colors.colPrimary
                                    onClicked: {
                                        const t = { id: root.makeId(), content: I18nService.tr("New task"), status: modelData.status, updatedAt: new Date().toISOString() }
                                        root.items = [t].concat(root.items)
                                        root.save()
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
                                    model: root.items.filter(i => i.status === modelData.status)
                                    delegate: cardDelegate
                                }
                            }
                            ScrollBar.vertical: StyledScrollBar {}
                        }
                    }
                }
            }
        }
    }
}
