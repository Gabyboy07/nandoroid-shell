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
    property var items: []
    property string _view: "list" // "list" | "notepad" | "todo"
    property string _editingId: ""

    readonly property string storagePath: Directories.home.replace("file://", "") + "/.cache/nandoroid/notes.json"

    function _currentItem() {
        return items.find(i => i.id === _editingId)
    }

    function makeId() { return Date.now().toString(36) + Math.random().toString(36).substr(2,5) }

    function stripHtml(html) {
        if (!html) return "";
        return html.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    function save() {
        const clean = root.items.map(i => {
            const c = {}
            for (const key in i) {
                if (key.startsWith("_")) continue
                c[key] = i[key]
            }
            return c
        })
        notesFile.setText(JSON.stringify(clean, null, 2))
    }

    function _flushSave() {
        if (saveTimer.running) {
            saveTimer.stop()
            _doSave()
        }
    }

    function goBack() {
        _flushSave()
        _view = "list"
        _editingId = ""
    }

    function openItem(id) {
        _flushSave()
        _editingId = id
        const item = _currentItem()
        if (!item) return
        _view = item.type
        if (item.type === "notepad") {
            noteTitleInput.text = item.title
            bodyArea.text = item.body
        } else if (item.type === "todo") {
            todoTitleInput.text = item.title
        }
    }

    function newNotepad() {
        const n = { type: "notepad", id: makeId(), title: I18nService.tr("Untitled"), body: "", color: "", pinned: false, updatedAt: new Date().toISOString() }
        root.items = [n].concat(root.items)
        save()
        openItem(n.id)
    }

    function newTodo() {
        const t = { type: "todo", id: makeId(), title: I18nService.tr("Untitled"), tasks: [], color: "", updatedAt: new Date().toISOString() }
        root.items = [t].concat(root.items)
        save()
        openItem(t.id)
    }

    function deleteCurrent() {
        if (!_editingId) return
        root.items = root.items.filter(i => i.id !== _editingId)
        save()
        goBack()
    }

    function deleteItem(itemId) {
        items = items.filter(i => i.id !== itemId)
        save()
    }

    function togglePin(itemId) {
        const item = items.find(i => i.id === itemId)
        if (item) {
            item.pinned = !item.pinned
            save()
            items = items.slice()
        }
    }

    function _distributeMasonry(itemsArray, numCols, targetIndex) {
        if (numCols <= 0) numCols = 1;
        var colHeights = [];
        var colItems = [];
        for (var c = 0; c < numCols; c++) {
            colHeights.push(0);
            colItems.push([]);
        }
        
        for (var i = 0; i < itemsArray.length; i++) {
            var itm = itemsArray[i];
            var shortestCol = 0;
            var minH = colHeights[0];
            for (var j = 1; j < numCols; j++) {
                if (colHeights[j] < minH) {
                    minH = colHeights[j];
                    shortestCol = j;
                }
            }
            colItems[shortestCol].push(itm);
            
            var estH = 80;
            if (itm.title) estH += 24 + Math.floor(itm.title.length / 25) * 24;
            if (itm.body) {
                var lines = itm.body.split('\n');
                var lc = 0;
                for (var k = 0; k < lines.length; k++) lc += 1 + Math.floor(lines[k].length / 35);
                estH += Math.min(8, lc) * 18;
            }
            colHeights[shortestCol] += estH;
        }
        return colItems[targetIndex];
    }

    // ── Date formatting helpers ──

    function _displayTime(timeStr) {
        if (!timeStr) return timeStr
        const parts = String(timeStr).split(":")
        if (parts.length < 2) return timeStr
        const h = parseInt(parts[0], 10)
        if (isNaN(h)) return timeStr
        const m = parts[1]
        const rest = parts.length > 2 ? ":" + parts.slice(2).join(":") : ""
        const style = Config.ready && Config.options.time ? Config.options.time.timeStyle : "24H"
        if (style === "24H") return String(h).padStart(2, "0") + ":" + m + rest
        const upper = style === "12H_PM"
        const ap = h >= 12 ? (upper ? "PM" : "pm") : (upper ? "AM" : "am")
        const h12 = h % 12 || 12
        return String(h12).padStart(2, "0") + ":" + m + rest + " " + ap
    }

    function _displayDate(dStr) {
        if (!dStr) return dStr
        const style = Config.ready && Config.options.time ? (Config.options.time.dateStyle ?? "DMY") : "DMY"
        const parts = String(dStr).trim().split(/[-/]/).map(Number)
        if (parts.length < 3 || parts.some(isNaN)) return dStr
        let y, m, d
        if (parts[0] > 1000) { y = parts[0]; m = parts[1]; d = parts[2] }
        else if (style === "MDY") { m = parts[0]; d = parts[1]; y = parts[2] }
        else { d = parts[0]; m = parts[1]; y = parts[2] }
        if (!y || !m || !d) return dStr
        const days = [I18nService.tr("Sun"), I18nService.tr("Mon"), I18nService.tr("Tue"), I18nService.tr("Wed"), I18nService.tr("Thu"), I18nService.tr("Fri"), I18nService.tr("Sat")]
        return days[new Date(y, m - 1, d).getDay()] + ", " + dStr
    }

    // ── File I/O ──
    FileView {
        id: notesFile
        path: root.storagePath
        watchChanges: false
        onLoaded: {
            try {
                let parsed = JSON.parse(notesFile.text())
                if (Array.isArray(parsed)) {
                    parsed = parsed.map(i => {
                        if (!i.type) { i.type = "notepad"; i.color = "" }
                        if (typeof i.pinned === "undefined") i.pinned = false
                        return i
                    })
                    root.items = parsed
                }
            } catch(e) {}
        }
    }

    Component.onCompleted: notesFile.reload()

    // ── Auto-save timer ──
    function _doSave() {
        if (!root._editingId) return
        const now = new Date().toISOString()
        const item = root._currentItem()
        if (!item) return

        if (item.type === "notepad") {
            item.title = noteTitleInput.text
            item.body = bodyArea.text
        }
        item.updatedAt = now

        const idx = root.items.indexOf(item)
        if (idx > 0) {
            root.items.splice(idx, 1)
            root.items.unshift(item)
        }
        root.items = root.items.slice()
        root.save()
    }

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: _doSave()
    }

    // ══════════════════════════════════════════════════
    //  UI
    // ══════════════════════════════════════════════════
    Component {
        id: noteDelegateComponent
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: contentCol.implicitHeight + 24 * Appearance.effectiveScale
            radius: Appearance.rounding.normal
            color: itemMouse.containsMouse ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainer
            border.color: Appearance.m3colors.m3outlineVariant
            border.width: 1 * Appearance.effectiveScale

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openItem(modelData.id)
            }

            ColumnLayout {
                id: contentCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12 * Appearance.effectiveScale
                spacing: 8 * Appearance.effectiveScale

                // Title & Pin
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * Appearance.effectiveScale
                    
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.title || I18nService.tr("Untitled")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.Wrap
                        visible: text.length > 0
                    }
                    
                    RippleButton {
                        id: pinBtn
                        implicitWidth: 28 * Appearance.effectiveScale
                        implicitHeight: 28 * Appearance.effectiveScale
                        Layout.alignment: Qt.AlignTop
                        buttonRadius: 14 * Appearance.effectiveScale
                        colBackground: "transparent"
                        opacity: itemMouse.containsMouse || pinBtn.realHovered || delBtn.realHovered || modelData.pinned ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        onClicked: root.togglePin(modelData.id)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keep"
                            iconSize: 18 * Appearance.effectiveScale
                            color: modelData.pinned ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }

                // Body preview for notepad
                StyledText {
                    Layout.fillWidth: true
                    visible: modelData.type === "notepad"
                    text: (modelData.body || "").trim()
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    wrapMode: Text.Wrap
                    maximumLineCount: 8
                    elide: Text.ElideRight
                }

                // Preview for todo
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * Appearance.effectiveScale
                    visible: modelData.type === "todo"

                    Repeater {
                        model: modelData.type === "todo" ? (modelData.tasks ? modelData.tasks.slice(0, 5) : []) : []
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6 * Appearance.effectiveScale
                            MaterialSymbol {
                                text: modelData.done ? "check_box" : "check_box_outline_blank"
                                iconSize: 14 * Appearance.effectiveScale
                                color: modelData.done ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.content
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: modelData.done ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                                font.strikeout: modelData.done
                                elide: Text.ElideRight
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: modelData.type === "todo" && modelData.tasks && modelData.tasks.length > 5
                        text: I18nService.tr("+ %1 more").arg(modelData.tasks ? modelData.tasks.length - 5 : 0)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                // Footer (Date & Delete)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: footerLayout.implicitHeight
                    Layout.topMargin: 4 * Appearance.effectiveScale
                    
                    RowLayout {
                        id: footerLayout
                        anchors.fill: parent
                        
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.updatedAt ? root._displayDate(modelData.updatedAt.split("T")[0]) : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        
                        RippleButton {
                            id: delBtn
                            implicitWidth: 24 * Appearance.effectiveScale
                            implicitHeight: 24 * Appearance.effectiveScale
                            buttonRadius: 12 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: root.deleteItem(modelData.id)
                            opacity: itemMouse.containsMouse || pinBtn.realHovered || delBtn.realHovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
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
    }

    Item {
        anchors.fill: parent
        anchors.margins: 16 * Appearance.effectiveScale

        // ──────────────────────────────────────────────
        //  STEP 1: LIST VIEW
        // ──────────────────────────────────────────────
        Item {
            id: listView
            anchors.fill: parent
            visible: root._view === "list"

            // ── Item List ──
            Flickable {
                id: itemList
                anchors.fill: parent
                contentHeight: contentCol.implicitHeight
                bottomMargin: 80 * Appearance.effectiveScale
                clip: true

                property int columnsCount: Math.max(2, Math.floor(width / (220 * Appearance.effectiveScale)))
                
                property var pinnedItems: root.items.filter(i => i.pinned === true && i.type === "notepad").sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt))
                property var otherItems: root.items.filter(i => i.pinned !== true && i.type === "notepad").sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt))

                ColumnLayout {
                    id: contentCol
                    width: itemList.width
                    spacing: 24 * Appearance.effectiveScale
                    
                    // Pinned Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12 * Appearance.effectiveScale
                        visible: itemList.pinnedItems.length > 0

                        StyledText {
                            text: I18nService.tr("Pinned")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colSubtext
                            Layout.leftMargin: 8 * Appearance.effectiveScale
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12 * Appearance.effectiveScale
                            Repeater {
                                model: itemList.columnsCount
                                delegate: ColumnLayout {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.fillWidth: true
                                    spacing: 12 * Appearance.effectiveScale
                                    Repeater {
                                        model: root._distributeMasonry(itemList.pinnedItems, itemList.columnsCount, index)
                                        delegate: noteDelegateComponent
                                    }
                                }
                            }
                        }
                    }

                    // Others Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12 * Appearance.effectiveScale
                        visible: itemList.otherItems.length > 0

                        StyledText {
                            text: I18nService.tr("Others")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colSubtext
                            Layout.leftMargin: 8 * Appearance.effectiveScale
                            visible: itemList.pinnedItems.length > 0 // Only show title if pinned exists
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12 * Appearance.effectiveScale
                            Repeater {
                                model: itemList.columnsCount
                                delegate: ColumnLayout {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.fillWidth: true
                                    spacing: 12 * Appearance.effectiveScale
                                    Repeater {
                                        model: root._distributeMasonry(itemList.otherItems, itemList.columnsCount, index)
                                        delegate: noteDelegateComponent
                                    }
                                }
                            }
                        }
                    }
                }
                
                ScrollBar.vertical: StyledScrollBar {}
            }

            // ── FAB ──
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
                onClicked: root.newNotepad()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "add"
                    iconSize: 24 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3onPrimaryContainer
                }
            }
        }

        // ──────────────────────────────────────────────
        //  STEP 2: NOTEPAD EDITOR
        // ──────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            spacing: 8 * Appearance.effectiveScale
            visible: root._view === "notepad"

            // Top bar: back + title + delete
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * Appearance.effectiveScale

                RippleButton {
                    implicitWidth: 36 * Appearance.effectiveScale
                    implicitHeight: 36 * Appearance.effectiveScale
                    buttonRadius: 18 * Appearance.effectiveScale
                    colBackground: Appearance.colors.colLayer2
                    onClicked: root.goBack()
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.m3colors.m3onSurface
                    }
                }

                StyledTextInput {
                    id: noteTitleInput
                    Layout.fillWidth: true
                    implicitHeight: 40 * Appearance.effectiveScale
                    inputRadius: Appearance.rounding.small / Appearance.effectiveScale
                    backgroundColor: Appearance.m3colors.m3surfaceContainer
                    text: ""
                    placeholder: I18nService.tr("Note title...")
                    onTextChanged: saveTimer.restart()
                }

                RippleButton {
                    implicitWidth: 40 * Appearance.effectiveScale
                    implicitHeight: 40 * Appearance.effectiveScale
                    buttonRadius: 20 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainer
                    onClicked: root.deleteCurrent()
                    MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 20 * Appearance.effectiveScale; color: Appearance.colors.colError }
                    StyledToolTip { text: I18nService.tr("Delete") }
                }
            }

            // Body editor
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                border.color: bodyArea.activeFocus ? Appearance.colors.colPrimary : "transparent"
                border.width: 2 * Appearance.effectiveScale
                clip: true

                Flickable {
                    id: bodyFlickable
                    anchors.fill: parent
                    anchors.margins: 12 * Appearance.effectiveScale
                    contentHeight: bodyArea.height
                    clip: true

                    TextEdit {
                        id: bodyArea
                        width: bodyFlickable.width
                        height: Math.max(implicitHeight, bodyFlickable.height)
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        wrapMode: TextEdit.Wrap
                        selectionColor: Appearance.colors.colPrimaryContainer
                        selectedTextColor: Appearance.colors.colOnPrimaryContainer
                        onTextChanged: saveTimer.restart()

                        onCursorRectangleChanged: {
                            const margin = 20 * Appearance.effectiveScale
                            if (cursorRectangle.y < bodyFlickable.contentY) {
                                bodyFlickable.contentY = cursorRectangle.y
                            } else if (cursorRectangle.y + cursorRectangle.height + margin > bodyFlickable.contentY + bodyFlickable.height) {
                                bodyFlickable.contentY = cursorRectangle.y + cursorRectangle.height - bodyFlickable.height + margin
                            }
                        }

                        StyledText {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            text: I18nService.tr("Start typing your note...")
                            color: Appearance.colors.colSubtext
                            visible: !parent.text && !parent.activeFocus
                            font.pixelSize: Appearance.font.pixelSize.normal
                            wrapMode: Text.Wrap
                        }
                    }

                    ScrollBar.vertical: StyledScrollBar {}
                }
            }
        }

    }
}
