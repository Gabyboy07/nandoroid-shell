import "../../core"
import "../../services"
import "../../widgets"
import "../../core/functions" as Functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

/**
 * High-Fidelity Settings-Style Wallpaper Selector.
 * Robust Scoping Fix (Phase 5) - Reliable ID referencing and cursor behavior.
 */
Item {
    id: mainSelector
    
    // Explicit reference for child components to avoid ReferenceError
    readonly property Item selectorItem: mainSelector

    ListModel {
        id: customFoldersModel
    }

    function refreshCustomFolders() {
        customFoldersModel.clear();
        const folders = Config.options.appearance.background.customFolders || [];
        for (let i = 0; i < folders.length; i++) {
            const path = folders[i];
            const name = path.split('/').pop() || path;
            customFoldersModel.append({ "name": name, "path": path });
        }
    }

    Component.onCompleted: {
        refreshCustomFolders();
        applySorting();
    }

    Connections {
        target: Wallpapers
        function onCustomFoldersChanged() { mainSelector.refreshCustomFolders(); }
    }

    // Responsive sizing
    width: Math.min(1380 * Appearance.effectiveScale, (parent ? parent.width : 1500) * 0.95)
    height: Math.min(840 * Appearance.effectiveScale, (parent ? parent.height : 900) * 0.85)
    
    implicitWidth: width
    implicitHeight: height
    
    focus: true
    Keys.onEscapePressed: close()

    signal closed()
    
    property bool favMode: false
    property bool wallhavenMode: false
    property bool naiveMode: false
    property bool liveMode: false
    
    // Selection state for right sidebar
    property var selectedWallpaper: null
    property bool showDetails: liveMode || selectedWallpaper !== null
    
    // Independent search states
    property string localSearch: ""
    property string wallhavenSearch: ""
    property string naiveSearch: ""
    property string liveSearch: ""
    
    // Sorting state
    property string sortMode: "name_asc" // name_asc, name_desc
    
    // Internal lock to prevent recursion during switching
    property bool _switchingMode: false

    function applySorting() {
        if (wallhavenMode || naiveMode) return;

        if (favMode) {
            favModel.refresh();
            return;
        }

        // Local sorting via global Wallpapers service
        if (sortMode === "name_asc") {
            Wallpapers.sortField = FolderListModel.Name;
            Wallpapers.sortReversed = false;
            WallpaperEngineService.sortReversed = false;
        } else if (sortMode === "name_desc") {
            Wallpapers.sortField = FolderListModel.Name;
            Wallpapers.sortReversed = true;
            WallpaperEngineService.sortReversed = true;
        }
    }

    onSortModeChanged: applySorting()

    function switchMode(mode) {
        if (_switchingMode) return;
        _switchingMode = true;
        
        // Save current search state
        if (wallhavenMode) wallhavenSearch = headerSearch.text;
        else if (naiveMode) naiveSearch = headerSearch.text;
        else if (liveMode) liveSearch = headerSearch.text;
        else localSearch = headerSearch.text;
        
        // Update modes
        wallhavenMode = (mode === "wallhaven");
        naiveMode = (mode === "naive");
        favMode = (mode === "fav");
        liveMode = (mode === "live");
        
        // Clear selection when switching modes
        selectedWallpaper = null;
        
        // Restore search state
        if (wallhavenMode) {
            headerSearch.text = wallhavenSearch;
            // If empty, fetch defaults
            if (headerSearch.text === "") WallhavenService.search("");
        } else if (naiveMode) {
            headerSearch.text = naiveSearch;
            NaIveWallpaperService.fetch();
        } else if (liveMode) {
            headerSearch.text = liveSearch;
            WallpaperEngineService.searchQuery = liveSearch;
            WallpaperEngineService.fetch();
        } else {
            headerSearch.text = localSearch;
            if (!favMode && !liveMode) {
                Wallpapers.searchQuery = localSearch;
            }
        }
        
        applySorting();
        _switchingMode = false;
    }

    property alias searchFilter: headerSearch.text
    
    onSearchFilterChanged: {
        if (_switchingMode) return;
        
        if (wallhavenMode) {
            if (searchFilter.startsWith("wallhaven-")) {
                const id = searchFilter.substring(10).trim();
                if (id !== "" && id.length > 3) WallhavenService.search(id, true);
            }
        } else if (naiveMode) {
            // ...
        } else if (liveMode) {
            WallpaperEngineService.searchQuery = searchFilter
        } else {
            Wallpapers.searchQuery = searchFilter
        }
    }

    onSelectedWallpaperChanged: {
        if (selectedWallpaper && mainSelector.liveMode) {
            WallpaperEngineService.fetchProperties(selectedWallpaper.folder, selectedWallpaper.id);
        }
    }

    function close() {
        Wallpapers.searchQuery = "";
        WallpaperEngineService.searchQuery = "";
        localSearch = "";
        wallhavenSearch = "";
        naiveSearch = "";
        liveSearch = "";
        WallhavenService.results.clear();
        NaIveWallpaperService.results.clear();
        mainSelector.closed()
    }
    function selectWallpaper(path) {
        // Stop Wallpaper Engine if switching to static on desktop
        if (GlobalStates.wallpaperSelectorTarget === "desktop") {
            WallpaperEngineService.stop();
            Wallpapers.select(path)
        } else {
            Wallpapers.selectForLockscreen(path)
        }
        mainSelector.close()
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorTargetChanged() {
            // Revert to local mode if target becomes lockscreen while in live mode
            if (GlobalStates.wallpaperSelectorTarget === "lock" && mainSelector.liveMode) {
                mainSelector.switchMode("local");
            }
        }
    }

    function normalizePath(p) {
        let s = p.toString();
        if (s.startsWith("file://")) s = s.substring(7);
        if (s.endsWith("/")) s = s.substring(0, s.length - 1);
        return s;
    }

    // ── Main UI Frame ──
    StyledRectangularShadow {
        target: bgContainer
        radius: bgContainer.radius
        color: Functions.ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.2)
    }

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: 32 * Appearance.effectiveScale
        clip: true

        TapHandler {}

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12 * Appearance.effectiveScale
            spacing: 12 * Appearance.effectiveScale

            // ── Header ──
            Item {
                id: headerItem
                Layout.fillWidth: true
                Layout.preferredHeight: 64 * Appearance.effectiveScale
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16 * Appearance.effectiveScale
                    anchors.rightMargin: 16 * Appearance.effectiveScale
                    spacing: 8 * Appearance.effectiveScale

                    RippleButton {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 48 * Appearance.effectiveScale
                        implicitHeight: 48 * Appearance.effectiveScale
                        buttonRadius: 24 * Appearance.effectiveScale
                        colBackground: "transparent"
                        onClicked: sidebar.expanded = !sidebar.expanded
                        
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: sidebar.expanded ? "menu_open" : "menu"
                            iconSize: 24 * Appearance.effectiveScale
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    // Header Search Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56 * Appearance.effectiveScale
                        radius: 28 * Appearance.effectiveScale
                        color: Appearance.colors.colLayer1
                        Layout.alignment: Qt.AlignVCenter
                        
                        // Centered Text Input
                        StyledTextInput {
                            id: headerSearch
                            anchors.fill: parent
                            // Reserve 120px symmetric margins so text is perfectly centered relative to the Rectangle
                            anchors.leftMargin: 120 * Appearance.effectiveScale
                            anchors.rightMargin: 120 * Appearance.effectiveScale
                            horizontalAlignment: TextInput.AlignHCenter
                            inputRadius: 0
                            backgroundColor: "transparent"
                            borderInactiveWidth: 0
                            showActiveBorder: false
                            placeholder: mainSelector.wallhavenMode ? I18nService.tr("Search Wallhaven") : (mainSelector.naiveMode ? I18nService.tr("Search NA-ive Walls") : I18nService.tr("Search wallpapers"))
                            leftMargin: 0
                            rightMargin: 0
                            font.pixelSize: Appearance.font.pixelSize.normal
                            
                            onTextChanged: {
                                if (mainSelector._switchingMode) return;
                                
                                if (mainSelector.wallhavenMode) mainSelector.wallhavenSearch = text;
                                else if (mainSelector.naiveMode) mainSelector.naiveSearch = text;
                                else if (mainSelector.liveMode) mainSelector.liveSearch = text;
                                else mainSelector.localSearch = text;

                                if (mainSelector.liveMode) {
                                    WallpaperEngineService.searchQuery = text;
                                } else if (!mainSelector.wallhavenMode && !mainSelector.naiveMode) {
                                    Wallpapers.searchQuery = text
                                } else if (text === "" && mainSelector.wallhavenMode) {
                                    WallhavenService.search("");
                                }
                            }
                            
                            onAccepted: {
                                if (mainSelector.wallhavenMode) {
                                    if (text.startsWith("wallhaven-")) {
                                        const id = text.substring(10).trim();
                                        WallhavenService.search(id, true);
                                    } else {
                                        WallhavenService.search(text);
                                    }
                                }
                            }
                        }
                    }

                    // Right action buttons outside the search pill
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0 // M3 groups trailing icons tightly, padding is built into the 48x48 size

                        // Sorting Button
                        Item {
                            id: sortBtnContainer
                            width: 48 * Appearance.effectiveScale
                            height: 48 * Appearance.effectiveScale
                            visible: !mainSelector.wallhavenMode && !mainSelector.naiveMode && !mainSelector.liveMode
    
                            RippleButton {
                                id: sortBtn
                                anchors.fill: parent
                                buttonRadius: 24 * Appearance.effectiveScale 
                                colBackground: "transparent"
                                onClicked: sortPopup.visible = !sortPopup.visible
                                
                                MaterialShapeWrappedMaterialSymbol {
                                    anchors.centerIn: parent
                                    implicitSize: 42 * Appearance.effectiveScale
                                    shapeString: "Sunny"
                                    color: Appearance.colors.colSecondary
                                    colSymbol: Appearance.colors.colOnSecondary
                                    text: "sort_by_alpha"
                                    iconSize: 20 * Appearance.effectiveScale
                                    rotation: sortPopup.visible ? 45 : 0
                                }
                                StyledToolTip { text: I18nService.tr("Sort Options") }
                            }
                        }
    
                        // Random Wallpaper Button
                        Item {
                            id: randBtnContainer
                            width: 48 * Appearance.effectiveScale
                            height: 48 * Appearance.effectiveScale
                            visible: !mainSelector.wallhavenMode && !mainSelector.naiveMode && !mainSelector.liveMode
    
                            RippleButton {
                                id: randBtn
                                anchors.fill: parent
                                buttonRadius: 24 * Appearance.effectiveScale
                                colBackground: "transparent"
                                onClicked: {
                                    if (mainSelector.favMode) {
                                        if (Wallpapers.selectRandomFavorite())
                                            mainSelector.close();
                                    } else if (Wallpapers.directory) {
                                        var d = Wallpapers.directory.toString();
                                        if (d.startsWith("file://")) d = d.substring(7);
                                        randProc.command = ["bash", "-c", `find "${d}" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.avif" \\) | shuf -n 1`];
                                        randProc.running = true;
                                    }
                                }
    
                                Process {
                                    id: randProc
                                    command: ["true"]
                                    running: false
                                    stdout: StdioCollector { id: randOut }
                                    onExited: {
                                        var result = randOut.text.trim();
                                        if (result) {
                                            Wallpapers.select(result);
                                            mainSelector.close();
                                        }
                                    }
                                }
    
                                MaterialShapeWrappedMaterialSymbol {
                                    anchors.centerIn: parent
                                    implicitSize: 42 * Appearance.effectiveScale
                                    shapeString: "Pentagon"
                                    color: Appearance.colors.colTertiary
                                    colSymbol: Appearance.colors.colOnTertiary
                                    text: "shuffle"
                                    iconSize: 20 * Appearance.effectiveScale
                                }
                                StyledToolTip { text: I18nService.tr("Random Wallpaper") }
                            }
                        }
    
                        // Global Wallpaper Engine Settings Button
                        Item {
                            id: weSettingsBtnContainer
                            width: 48 * Appearance.effectiveScale
                            height: 48 * Appearance.effectiveScale
                            visible: mainSelector.liveMode
    
                            RippleButton {
                                id: weSettingsBtn
                                anchors.fill: parent
                                buttonRadius: 24 * Appearance.effectiveScale 
                                colBackground: "transparent"
                                onClicked: weSettingsPopup.visible = !weSettingsPopup.visible
                                
                                MaterialShapeWrappedMaterialSymbol {
                                    anchors.centerIn: parent
                                    implicitSize: 42 * Appearance.effectiveScale
                                    shapeString: "Sunny"
                                    color: Appearance.colors.colSecondary
                                    colSymbol: Appearance.colors.colOnSecondary
                                    text: "settings"
                                    iconSize: 20 * Appearance.effectiveScale
                                    rotation: weSettingsPopup.visible ? 45 : 0
                                }
                                StyledToolTip { text: I18nService.tr("Global Engine Settings") }
                            }
                        }
                        // Close Button
                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 48 * Appearance.effectiveScale
                            implicitHeight: 48 * Appearance.effectiveScale
                            buttonRadius: 24 * Appearance.effectiveScale
                            colBackground: "transparent"
                            onClicked: mainSelector.close()
                            MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 24 * Appearance.effectiveScale; color: Appearance.colors.colSubtext }
                        }
                    }
                }
            }

            // ── Main Body ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12 * Appearance.effectiveScale
                anchors.margins: 4 * Appearance.effectiveScale

                // Left Sidebar (Navigation)
                StyledNavigationRail {
                    id: sidebar
                    
                    showMenuButton: false
                    
                    // The rail starts expanded (like 240px wide sidebar)
                    expanded: true
                    
                    model: {
                        let m = [];
                        let liveEnabled = GlobalStates.wallpaperSelectorTarget === "desktop" && WallpaperEngineService.isInstalled && !GameMode.active;
                        let liveTooltip = I18nService.tr("Browse Wallpaper Engine collection");
                        if (GameMode.active) liveTooltip = I18nService.tr("Live wallpapers cannot be changed while Game Mode is active");
                        else if (!WallpaperEngineService.isInstalled) liveTooltip = I18nService.tr("linux-wallpaperengine not found");
                        else if (GlobalStates.wallpaperSelectorTarget !== "desktop") liveTooltip = I18nService.tr("Live wallpapers only supported on desktop");
                        
                        m.push({ name: I18nService.tr("Live Wallpaper"), icon: "movie", id: "live", enabled: liveEnabled, tooltip: liveTooltip });
                        m.push({ name: I18nService.tr("Wallhaven"), icon: "travel_explore", id: "wallhaven", tooltip: I18nService.tr("Search and download from Wallhaven.cc") });
                        m.push({ name: I18nService.tr("NA-ive Walls"), icon: "collections", id: "naive", tooltip: I18nService.tr("Browse the curated NA-ive wallpaper collection") });
                        m.push({ name: I18nService.tr("Favourites"), icon: "favorite", id: "fav", tooltip: I18nService.tr("View your favorite wallpapers") });
                        
                        m.push({ name: "Home", icon: "home", id: "local", path: Directories.home, tooltip: I18nService.tr("Browse wallpapers in %1").replace("%1", "Home") });
                        m.push({ name: "Pictures", icon: "image", id: "local", path: Directories.pictures, tooltip: I18nService.tr("Browse wallpapers in %1").replace("%1", "Pictures") });
                        m.push({ name: "Wallpapers", icon: "wallpaper", id: "local", path: Directories.home + "/Pictures/Wallpapers", tooltip: I18nService.tr("Browse wallpapers in %1").replace("%1", "Wallpapers") });
                        
                        // Reference customFoldersModel.count to trigger reactivity
                        let _count = customFoldersModel.count;
                        for (let i = 0; i < _count; i++) {
                            let folder = customFoldersModel.get(i);
                            m.push({ name: folder.name, icon: "folder", id: "local", path: folder.path, isCustom: true, tooltip: Functions.FileUtils.shortenHomePath(folder.path), rightActionIcon: "delete" });
                        }
                        
                        m.push({ name: I18nService.tr("Add Folder"), icon: "add", id: "add", tooltip: I18nService.tr("Add custom folder") });
                        return m;
                    }
                    
                    currentIndex: {
                        if (mainSelector.liveMode) return 0;
                        if (mainSelector.wallhavenMode) return 1;
                        if (mainSelector.naiveMode) return 2;
                        if (mainSelector.favMode) return 3;
                        
                        let targetPath = mainSelector.normalizePath(Wallpapers.directory);
                        for (let i = 4; i < model.length - 1; i++) {
                            if (model[i].id === "local" && mainSelector.normalizePath(model[i].path) === targetPath) {
                                return i;
                            }
                        }
                        return -1;
                    }
                    
                    onItemClicked: (index) => {
                        let item = model[index];
                        if (item.id === "live") mainSelector.switchMode("live");
                        else if (item.id === "wallhaven") mainSelector.switchMode("wallhaven");
                        else if (item.id === "naive") mainSelector.switchMode("naive");
                        else if (item.id === "fav") mainSelector.switchMode("fav");
                        else if (item.id === "local") {
                            mainSelector.switchMode("local");
                            Wallpapers.directory = "file://" + mainSelector.normalizePath(item.path);
                        }
                        else if (item.id === "add") Wallpapers.browseFolder();
                    }
                    
                    onRightActionClicked: (index) => {
                        let item = model[index];
                        if (item.isCustom) {
                            let current = (Config.options.appearance.background.customFolders || []).slice();
                            const idx = current.indexOf(item.path);
                            if (idx !== -1) {
                                current.splice(idx, 1);
                                Config.options.appearance.background.customFolders = current;
                                mainSelector.refreshCustomFolders();
                            }
                        }
                    }
                    
                    bottomComponent: Component {
                        Item {
                            // Give extra height above the FAB when compact to increase the gap to the rail items.
                            // FAB is 56px. Adding 24px extra space + 16px from layout spacing = 40px total gap.
                            implicitHeight: sidebar.expanded ? 48 * Appearance.effectiveScale : 80 * Appearance.effectiveScale
                            implicitWidth: sidebar.width
                            
                            Row {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 24 * Appearance.effectiveScale
                                height: sidebar.expanded ? 48 * Appearance.effectiveScale : 56 * Appearance.effectiveScale
                                spacing: 4 * Appearance.effectiveScale
                                
                                SegmentedButton {
                                    width: (parent.width - (4 * Appearance.effectiveScale)) / 2; height: parent.height
                                    buttonText: "Desktop"; isHighlighted: GlobalStates.wallpaperSelectorTarget === "desktop"
                                    colInactive: Appearance.colors.colLayer2; colActive: Appearance.m3colors.m3primary
                                    onClicked: GlobalStates.wallpaperSelectorTarget = "desktop"
                                    visible: sidebar.expanded
                                }
                                SegmentedButton {
                                    width: (parent.width - (4 * Appearance.effectiveScale)) / 2; height: parent.height
                                    buttonText: "Lock"; isHighlighted: GlobalStates.wallpaperSelectorTarget === "lock"
                                    colInactive: Appearance.colors.colLayer2; colActive: Appearance.m3colors.m3primary
                                    onClicked: GlobalStates.wallpaperSelectorTarget = "lock"
                                    visible: sidebar.expanded
                                }
                                
                                RippleButton {
                                    visible: !sidebar.expanded
                                    width: 56 * Appearance.effectiveScale
                                    height: 56 * Appearance.effectiveScale
                                    buttonRadius: 16 * Appearance.effectiveScale
                                    colBackground: Appearance.m3colors.m3primaryContainer
                                    colBackgroundHover: Functions.ColorUtils.mix(Appearance.m3colors.m3primaryContainer, Appearance.m3colors.m3onPrimaryContainer, 0.9)
                                    colRipple: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onPrimaryContainer, 0.15)
                                    onClicked: GlobalStates.wallpaperSelectorTarget = GlobalStates.wallpaperSelectorTarget === "desktop" ? "lock" : "desktop"
                                    
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: GlobalStates.wallpaperSelectorTarget === "desktop" ? "desktop_windows" : "lock"
                                        iconSize: 22 * Appearance.effectiveScale
                                        color: Appearance.m3colors.m3onPrimaryContainer
                                    }
                                    StyledToolTip { text: I18nService.tr("Target: %1").replace("%1", GlobalStates.wallpaperSelectorTarget); extraVisibleCondition: parent.hovered }
                                }
                            }
                        }
                    }
                }

                // Grid Island
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.colors.colLayer1
                    radius: 28 * Appearance.effectiveScale
                    clip: true
                    opacity: 0.98

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: 20 * Appearance.effectiveScale
                        cellWidth: width / (mainSelector.showDetails ? 3 : 4)
                        cellHeight: cellWidth * 9/16 + (40 * Appearance.effectiveScale)
                        clip: true; interactive: true
                        
                        // Memory optimization: Load only what's necessary (about 1.5 extra screen heights)
                        cacheBuffer: Math.max(0, height * 1.5)
                        
                        model: {
                            if (mainSelector.wallhavenMode) return WallhavenService.results;
                            if (mainSelector.naiveMode) return NaIveWallpaperService.results;
                            if (mainSelector.favMode) return favModel;
                            if (mainSelector.liveMode) return WallpaperEngineService.results;
                            return Wallpapers.folderModel;
                        }

                        Connections {
                            target: WallpaperEngineService
                            function onLoadingChanged() {
                                if (!WallpaperEngineService.loading) {
                                    // Force a tiny refresh if needed, though results is a ListModel
                                    // so GridView should handle it.
                                }
                            }
                        }
                    
                        onContentYChanged: {
                            if (mainSelector.wallhavenMode && !WallhavenService.loading && contentY > contentHeight - height - (400 * Appearance.effectiveScale)) {
                                if (WallhavenService.results.count < WallhavenService.totalResults) {
                                    WallhavenService.search(WallhavenService.lastQuery, false, WallhavenService.currentPage + 1);
                                }
                            }
                        }

                        footer: Item {
                            width: grid.width; height: 80 * Appearance.effectiveScale
                            visible: (mainSelector.wallhavenMode && WallhavenService.loading && grid.count > 0) || (mainSelector.naiveMode && NaIveWallpaperService.loading && grid.count > 0)
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 12 * Appearance.effectiveScale
                                MaterialSymbol {
                                    id: loadMoreIcon
                                    text: "progress_activity"; iconSize: 24 * Appearance.effectiveScale; color: Appearance.colors.colPrimary
                                    RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: parent.visible; onRunningChanged: if (!running) loadMoreIcon.rotation = 0 }
                                }
                                StyledText { text: I18nService.tr("Loading more..."); color: Appearance.colors.colSubtext }
                            }
                        }

                        ListModel {
                            id: favModel
                            function refresh() {
                                clear();
                                const favs = Wallpapers.favorites;
                                let data = [];
                                for (let i = 0; i < favs.length; i++) {
                                    const path = favs[i];
                                    const name = path.split('/').pop();
                                    data.push({ "filePath": path, "fileName": name });
                                }

                                // Apply sorting
                                data.sort((a, b) => {
                                    if (mainSelector.sortMode === "name_asc") return a.fileName.localeCompare(b.fileName);
                                    if (mainSelector.sortMode === "name_desc") return b.fileName.localeCompare(a.fileName);
                                    return 0;
                                });

                                for (let item of data) append(item);
                            }
                            Component.onCompleted: refresh()
                        }
                        
                        Connections {
                            target: Wallpapers
                            function onFavoritesChanged() { favModel.refresh(); }
                        }
                        
                        onVisibleChanged: { if (visible) favModel.refresh(); }
                        
                        delegate: Item {
                            id: delegateRoot
                            width: grid.cellWidth; height: grid.cellHeight
                            
                            // EXPLICIT PROXY PROPERTIES TO FIX REFERENCE ERRORS
                            readonly property Item selector: mainSelector.selectorItem
                            readonly property bool inWallhavenMode: delegateRoot.selector.wallhavenMode
                            readonly property bool inNaiveMode: delegateRoot.selector.naiveMode
                            readonly property bool inFavMode: delegateRoot.selector.favMode
                            readonly property bool inLiveMode: delegateRoot.selector.liveMode
                            
                            readonly property string currentFilePath: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode) ? (model.full || "") : (delegateRoot.inFavMode ? (model.filePath || "") : (delegateRoot.inLiveMode ? (model.folder || "") : (filePath || "")))
                            readonly property string currentFileName: delegateRoot.inWallhavenMode ? ("wallhaven-" + (model.id || "")) : (delegateRoot.inNaiveMode ? model.filename : (delegateRoot.inFavMode ? (model.fileName || "") : (delegateRoot.inLiveMode ? (model.title || "") : (fileName || ""))))
                            readonly property string previewPath: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode || delegateRoot.inLiveMode) ? (model.preview || "") : ("file://" + currentFilePath)
                            
                            readonly property bool isSelected: delegateRoot.selector.selectedWallpaper !== null && (delegateRoot.inLiveMode ? delegateRoot.selector.selectedWallpaper.id === model.id : delegateRoot.selector.selectedWallpaper.filePath === currentFilePath)
                            readonly property bool isCurrentWallpaper: {
                                if (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode) return false;
                                if (delegateRoot.inLiveMode) {
                                    let livePath = Config.ready ? Config.options.appearance.background.liveWallpaperPath : "";
                                    return GlobalStates.wallpaperSelectorTarget === "desktop" && livePath !== "" && mainSelector.normalizePath(livePath) === mainSelector.normalizePath(model.folder);
                                }
                                if (!Config.ready || currentFilePath === "") return false;
                                if (GlobalStates.wallpaperSelectorTarget === "lock") {
                                    if (!Config.options.lock.useSeparateWallpaper) return false;
                                    return mainSelector.normalizePath(Config.options.lock.wallpaperPath) === mainSelector.normalizePath("file://" + currentFilePath);
                                }
                                return mainSelector.normalizePath(Config.options.appearance.background.wallpaperPath) === mainSelector.normalizePath("file://" + currentFilePath);
                            }
                            
                            readonly property string wallhavenId: {
                                if (delegateRoot.inWallhavenMode) return model.id || "";
                                if (delegateRoot.inNaiveMode) return model.wallhaven_id || "";
                                // Robust detection from local filename (e.g. wallhaven-XXXXX.jpg)
                                let name = delegateRoot.currentFileName.toLowerCase();
                                if (name.startsWith("wallhaven-")) {
                                    let parts = name.split("-");
                                    if (parts.length > 1) {
                                        let idWithExt = parts[1];
                                        return idWithExt.split(".")[0];
                                    }
                                }
                                return "";
                            }

                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12 * Appearance.effectiveScale; spacing: 8 * Appearance.effectiveScale
                                
                                Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                        Rectangle {
                                            id: imgPlate
                                            anchors.fill: parent; radius: 10 * Appearance.effectiveScale; color: delegateRoot.inNaiveMode ? (model.color || Appearance.colors.colLayer2) : Appearance.colors.colLayer2
                                            layer.enabled: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle { width: imgPlate.width; height: imgPlate.height; radius: 10 * Appearance.effectiveScale }
                                            }

                                        HoverHandler { id: imgHover }

                                        ThumbnailImage {
                                            anchors.fill: parent
                                            sourcePath: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode || delegateRoot.inLiveMode) ? "" : currentFilePath
                                            visible: sourcePath !== ""
                                        }

                                        AnimatedImage {
                                            anchors.fill: parent; source: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode || delegateRoot.inLiveMode) ? previewPath : ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode || delegateRoot.inLiveMode) && source != ""
                                            asynchronous: true; cache: true; playing: true
                                        }

                                        // Highlight border: selected (live preview) or currently applied wallpaper
                                        Rectangle {
                                            anchors.fill: parent
                                            border.width: 3 * Appearance.effectiveScale
                                            border.color: Appearance.colors.colPrimary
                                            radius: 10 * Appearance.effectiveScale
                                            color: "transparent"
                                            antialiasing: true
                                            visible: delegateRoot.isSelected || delegateRoot.isCurrentWallpaper
                                        }
                                        // Active wallpaper checkmark badge
                                        Rectangle {
                                            visible: delegateRoot.isCurrentWallpaper && !delegateRoot.isSelected
                                            anchors.top: parent.top; anchors.left: parent.left
                                            anchors.margins: 8 * Appearance.effectiveScale
                                            width: 28 * Appearance.effectiveScale; height: 28 * Appearance.effectiveScale
                                            radius: 14 * Appearance.effectiveScale
                                            color: Appearance.colors.colPrimary

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "check"
                                                iconSize: 18 * Appearance.effectiveScale
                                                color: Appearance.colors.colOnPrimary
                                                fill: 1
                                            }

                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                            opacity: visible ? 1 : 0
                                        }
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: Qt.rgba(0,0,0, 0.0) } 
                                                GradientStop { position: 0.6; color: Qt.rgba(0,0,0, 0.15) } 
                                                GradientStop { position: 1.0; color: Qt.rgba(0,0,0, 0.45) } 
                                            }
                                        }
                                        
                                        Rectangle {
                                            anchors.fill: parent; color: Appearance.colors.colPrimary; opacity: (mArea.containsMouse || imgHover.hovered) ? 0.15 : 0
                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                        }
                                        
                                        MouseArea {
                                            id: mArea; anchors.fill: parent; hoverEnabled: true
                                            // Arrow cursor in online modes as requested
                                            cursorShape: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode) ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: {
                                                if (delegateRoot.inLiveMode) {
                                                    delegateRoot.selector.selectedWallpaper = {
                                                        "id": model.id,
                                                        "title": model.title,
                                                        "folder": model.folder,
                                                        "metadata": model.metadata,
                                                        "preview": model.preview
                                                    };
                                                } else if (!delegateRoot.inWallhavenMode && !delegateRoot.inNaiveMode) {
                                                    if (currentFilePath !== "") {
                                                        delegateRoot.selector.selectWallpaper("file://" + currentFilePath)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        RowLayout {
                                            anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 4 * Appearance.effectiveScale; spacing: 2 * Appearance.effectiveScale

                                            RippleButton {
                                                id: similarBtn
                                                visible: delegateRoot.wallhavenId !== ""
                                                implicitWidth: 36 * Appearance.effectiveScale; implicitHeight: 36 * Appearance.effectiveScale; buttonRadius: 18 * Appearance.effectiveScale; colBackground: "transparent"
                                                MaterialSymbol {
                                                    anchors.centerIn: parent; text: "auto_awesome"; iconSize: 20 * Appearance.effectiveScale; color: "white"
                                                    fill: parent.hovered ? 1 : 0
                                                }
                                                onClicked: {
                                                    let s = delegateRoot.selector;
                                                    s.switchMode("wallhaven");
                                                    s.searchFilter = "wallhaven-" + delegateRoot.wallhavenId;
                                                    WallhavenService.search(delegateRoot.wallhavenId, true);
                                                }
                                                StyledToolTip { text: I18nService.tr("Search similar on Wallhaven") }
                                            }

                                            RippleButton {
                                                id: favBtn
                                                visible: !delegateRoot.inWallhavenMode && !delegateRoot.inNaiveMode && currentFilePath !== ""
                                                implicitWidth: 36 * Appearance.effectiveScale; implicitHeight: 36 * Appearance.effectiveScale; buttonRadius: 18 * Appearance.effectiveScale; colBackground: "transparent"
                                                readonly property bool isFav: currentFilePath !== "" && Wallpapers.isFavorite(currentFilePath)
                                                MaterialSymbol {
                                                    anchors.centerIn: parent; text: "favorite"; iconSize: 20 * Appearance.effectiveScale
                                                    fill: (favBtn.isFav || favBtn.hovered) ? 1 : 0
                                                    color: favBtn.isFav ? "#ff4081" : "#FFFFFF"
                                                    Behavior on color { ColorAnimation { duration: 200 } }
                                                }
                                                onClicked: Wallpapers.toggleFavorite(currentFilePath)
                                                StyledToolTip { text: favBtn.isFav ? I18nService.tr("Remove from favorites") : I18nService.tr("Add to favorites") }
                                            }

                                            RippleButton {
                                                id: downloadOnlyBtn
                                                visible: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode) && (model.full || "") !== ""
                                                implicitWidth: 36 * Appearance.effectiveScale; implicitHeight: 36 * Appearance.effectiveScale; buttonRadius: 18 * Appearance.effectiveScale; colBackground: "transparent"
                                                MaterialSymbol {
                                                    anchors.centerIn: parent; text: "download"; iconSize: 20 * Appearance.effectiveScale; color: "white"
                                                    fill: parent.hovered ? 1 : 0
                                                }
                                                onClicked: {
                                                    if (delegateRoot.inWallhavenMode) {
                                                        WallhavenService.download(model.full, model.id, model.file_type, false);
                                                    } else {
                                                        NaIveWallpaperService.download(model.full, model.filename, false);
                                                    }
                                                }
                                                StyledToolTip { text: I18nService.tr("Download to folder") }
                                            }

                                            RippleButton {
                                                id: downloadApplyBtn
                                                visible: (delegateRoot.inWallhavenMode || delegateRoot.inNaiveMode) && (model.full || "") !== ""
                                                implicitWidth: 36 * Appearance.effectiveScale; implicitHeight: 36 * Appearance.effectiveScale; buttonRadius: 18 * Appearance.effectiveScale; colBackground: "transparent"
                                                MaterialSymbol {
                                                    anchors.centerIn: parent; text: "wallpaper"; iconSize: 20 * Appearance.effectiveScale; color: "white"
                                                    fill: parent.hovered ? 1 : 0
                                                }
                                                onClicked: {
                                                    if (delegateRoot.inWallhavenMode) {
                                                        WallhavenService.download(model.full, model.id, model.file_type, true);
                                                    } else {
                                                        NaIveWallpaperService.download(model.full, model.filename, true);
                                                    }
                                                }
                                                StyledToolTip { text: I18nService.tr("Download and Apply") }
                                            }
                                        }

                                        Rectangle {
                                            visible: delegateRoot.inWallhavenMode && (model.resolution || "") !== ""
                                            anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8 * Appearance.effectiveScale
                                            width: resText.implicitWidth + (12 * Appearance.effectiveScale); height: 20 * Appearance.effectiveScale; radius: 10 * Appearance.effectiveScale; color: Qt.rgba(0,0,0, 0.5)
                                            StyledText {
                                                id: resText; anchors.centerIn: parent; text: model.resolution || ""
                                                font.pixelSize: Math.round(10 * Appearance.effectiveScale); font.weight: Font.DemiBold; color: "white"
                                            }
                                        }
                                    }
                                }
                                StyledText {
                                    Layout.fillWidth: true; text: currentFileName; horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: Appearance.font.pixelSize.smallest; elide: Text.ElideRight; color: delegateRoot.isCurrentWallpaper ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer1; opacity: delegateRoot.isCurrentWallpaper ? 1 : 0.7
                                }
                            }
                        }
                        
                        ScrollBar.vertical: StyledScrollBar {}

                        ColumnLayout {
                            anchors.centerIn: parent; visible: grid.count === 0; spacing: 12 * Appearance.effectiveScale
                            MaterialSymbol {
                                id: mainLoadIcon
                                visible: (mainSelector.wallhavenMode && WallhavenService.loading) || (mainSelector.naiveMode && NaIveWallpaperService.loading) || (mainSelector.liveMode && WallpaperEngineService.loading)
                                text: "progress_activity"; iconSize: 32 * Appearance.effectiveScale; color: Appearance.colors.colPrimary
                                Layout.alignment: Qt.AlignHCenter
                                RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: parent.visible; onRunningChanged: if (!running) mainLoadIcon.rotation = 0 }
                            }
                            StyledText {
                                text: {
                                    if (mainSelector.wallhavenMode) {
                                        if (WallhavenService.errorMessage !== "") return WallhavenService.errorMessage;
                                        if (WallhavenService.loading) return I18nService.tr("Searching Wallhaven...");
                                        return I18nService.tr("No online wallpapers found");
                                    }
                                    if (mainSelector.naiveMode) {
                                        if (NaIveWallpaperService.errorMessage !== "") return NaIveWallpaperService.errorMessage;
                                        if (NaIveWallpaperService.loading) return I18nService.tr("Fetching Na-ive collection...");
                                        return I18nService.tr("No wallpapers in collection");
                                    }
                                    if (mainSelector.liveMode) {
                                        if (!WallpaperEngineService.isInstalled) return I18nService.tr("linux-wallpaperengine-git is required for this feature");
                                        if (WallpaperEngineService.errorMessage !== "") return WallpaperEngineService.errorMessage;
                                        if (WallpaperEngineService.loading) return I18nService.tr("Scanning Steam Workshop...");
                                        return I18nService.tr("No Wallpaper Engine wallpapers found");
                                    }
                                    return mainSelector.favMode ? I18nService.tr("No favorite wallpapers") : I18nService.tr("No wallpapers found");
                                }
                                color: (WallhavenService.errorMessage !== "" || NaIveWallpaperService.errorMessage !== "" || WallpaperEngineService.errorMessage !== "") ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // Details Sidebar Island
                Rectangle {
                    id: detailsIsland
                    Layout.fillHeight: true
                    Layout.preferredWidth: mainSelector.showDetails ? 320 * Appearance.effectiveScale : 0
                    visible: mainSelector.showDetails
                    color: Appearance.colors.colLayer1
                    radius: 28 * Appearance.effectiveScale
                    clip: true
                    opacity: 0.98

                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16 * Appearance.effectiveScale
                        spacing: 16 * Appearance.effectiveScale
                        visible: mainSelector.selectedWallpaper !== null

                        StyledText {
                            text: mainSelector.selectedWallpaper ? mainSelector.selectedWallpaper.title : I18nService.tr("Wallpaper Details")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Preview & Info
                        Rectangle {
                            id: previewPlate
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180 * Appearance.effectiveScale
                            radius: 16 * Appearance.effectiveScale
                            color: Appearance.colors.colLayer2
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle { width: previewPlate.width; height: previewPlate.height; radius: 16 * Appearance.effectiveScale }
                            }

                            AnimatedImage {
                                anchors.fill: parent
                                source: mainSelector.selectedWallpaper ? mainSelector.selectedWallpaper.preview : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                playing: true
                                cache: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0,0,0, 0.5) }
                                }
                            }

                            StyledText {
                                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 12 * Appearance.effectiveScale
                                text: mainSelector.selectedWallpaper ? mainSelector.selectedWallpaper.id : ""
                                color: "white"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                opacity: 0.8
                            }
                        }

                        ScrollView {
                            id: detailsScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ColumnLayout {
                                width: detailsScroll.availableWidth
                                spacing: 12 * Appearance.effectiveScale

                                StyledText {
                                    text: I18nService.tr("Properties")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colSubtext
                                    visible: WallpaperEngineService.currentProperties.count > 0
                                }

                                Repeater {
                                    model: WallpaperEngineService.currentProperties
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8 * Appearance.effectiveScale

                                        RowLayout {
                                            Layout.fillWidth: true
                                            StyledText {
                                                text: propText || ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colOnLayer1
                                                Layout.fillWidth: true
                                            }
                                            
                                            // Boolean Checkbox
                                            AndroidToggle {
                                                visible: propType === "bool"
                                                checked: valBool
                                                onToggled: {
                                                    WallpaperEngineService.updateProperty(propKey, !checked);
                                                }
                                            }
                                        }

                                        // Slider for numbers
                                        StyledSlider {
                                            visible: propType === "slider"
                                            Layout.fillWidth: true
                                            from: propMin
                                            to: propMax
                                            value: valNum
                                            // Use onMoved to only trigger update when user actively changes it
                                            onMoved: {
                                                WallpaperEngineService.updateProperty(propKey, value);
                                            }
                                        }
                                        
                                        // Combo Box
                                        StyledComboBox {
                                            visible: propType === "combo"
                                            Layout.fillWidth: true
                                            searchable: false
                                            text: {
                                                if (!options_json || options_json === "" || options_json === "[]") return "";
                                                try {
                                                    let opts = JSON.parse(options_json);
                                                    let current = opts.find(o => String(o.value) === String(valNum) || String(o.value) === String(valStr));
                                                    return current ? current.label : "";
                                                } catch(e) { return ""; }
                                            }
                                            model: {
                                                if (!options_json || options_json === "" || options_json === "[]") return [];
                                                try {
                                                    let opts = JSON.parse(options_json);
                                                    return opts.map(o => o.label);
                                                } catch(e) { return []; }
                                            }
                                            onAccepted: (label) => {
                                                try {
                                                    let opts = JSON.parse(options_json);
                                                    let found = opts.find(o => o.label === label);
                                                    if (found) {
                                                        WallpaperEngineService.updateProperty(propKey, found.value);
                                                    }
                                                } catch(e) {}
                                            }
                                        }

                                        Item { Layout.preferredHeight: 4 * Appearance.effectiveScale }
                                    }
                                }

                                // Placeholder if no properties
                                StyledText {
                                    text: I18nService.tr("No properties available for this wallpaper.")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    visible: WallpaperEngineService.currentProperties.count === 0 && !WallpaperEngineService.loading
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12 * Appearance.effectiveScale

                            RippleButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 44 * Appearance.effectiveScale
                                buttonText: I18nService.tr("Apply")
                                enabled: !GameMode.active
                                opacity: enabled ? 1 : 0.5
                                colBackground: Appearance.colors.colPrimary
                                colText: Appearance.colors.colOnPrimary
                                onClicked: {
                                    if (mainSelector.selectedWallpaper) {
                                        WallpaperEngineService.apply(mainSelector.selectedWallpaper.folder, mainSelector.selectedWallpaper.preview);
                                        mainSelector.close();
                                    }
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 44 * Appearance.effectiveScale
                                buttonText: I18nService.tr("Reset")
                                colBackground: Appearance.colors.colLayer2
                                colText: Appearance.colors.colOnLayer2
                                visible: WallpaperEngineService.currentProperties.count > 0
                                onClicked: {
                                    if (mainSelector.selectedWallpaper) {
                                        WallpaperEngineService.resetProperties(mainSelector.selectedWallpaper.folder);
                                    }
                                }
                                StyledToolTip { text: I18nService.tr("Reset properties to default") }
                            }
                        }
                    }

                    // No selection placeholder
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12 * Appearance.effectiveScale
                        visible: mainSelector.selectedWallpaper === null && mainSelector.showDetails
                        
                        MaterialSymbol {
                            text: "wallpaper"
                            iconSize: 48 * Appearance.effectiveScale
                            color: Appearance.colors.colSubtext
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        StyledText {
                            text: I18nService.tr("Select a wallpaper to see details")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // --- Sorting Overlay & Popup (drawn last for z-index) ---
        MouseArea {
            id: sortOverlay
            anchors.fill: parent
            visible: sortPopup.visible
            z: 99
            onPressed: sortPopup.visible = false
        }

        StyledRectangularShadow {
            target: sortPopup
            radius: sortPopup.radius
            visible: sortPopup.visible
            z: 99
        }

        Rectangle {
            id: sortPopup
            visible: false
            z: 100
            width: 180 * Appearance.effectiveScale
            height: sortCol.implicitHeight + (16 * Appearance.effectiveScale)
            
            // Map absolute position relative to the button
            x: {
                let _ = visible;
                let _w = bgContainer.width;
                let p = sortBtn.mapToItem(bgContainer, 0, 0);
                return p.x + sortBtn.width - width;
            }
            y: {
                let _ = visible;
                let _h = bgContainer.height;
                let p = sortBtn.mapToItem(bgContainer, 0, 0);
                return p.y + sortBtn.height + (8 * Appearance.effectiveScale);
            }

            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: 12 * Appearance.effectiveScale
            
            ColumnLayout {
                id: sortCol
                anchors.fill: parent
                anchors.margins: 8 * Appearance.effectiveScale
                spacing: 4 * Appearance.effectiveScale
                
                Repeater {
                    model: [
                        { id: "name_asc",  name: I18nService.tr("Name (A-Z)"), icon: "sort_by_alpha" },
                        { id: "name_desc", name: I18nService.tr("Name (Z-A)"), icon: "sort_by_alpha" }
                    ]
                    delegate: RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 36 * Appearance.effectiveScale
                        buttonRadius: 8 * Appearance.effectiveScale
                        toggled: mainSelector.sortMode === modelData.id
                        colBackground: "transparent"
                        colBackgroundToggled: Appearance.m3colors.m3primaryContainer
                        
                        onClicked: {
                            mainSelector.sortMode = modelData.id;
                            sortPopup.visible = false;
                        }
                        
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12 * Appearance.effectiveScale; spacing: 12 * Appearance.effectiveScale
                            MaterialSymbol { 
                                text: modelData.icon; iconSize: 18 * Appearance.effectiveScale
                                color: parent.parent.toggled ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colOnLayer0
                            }
                            StyledText { 
                                text: modelData.name; Layout.fillWidth: true; 
                                font.pixelSize: Math.round(12 * Appearance.effectiveScale)
                                font.weight: parent.parent.toggled ? Font.DemiBold : Font.Normal
                                color: parent.parent.toggled ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colOnLayer0
                            }
                        }
                    }
                }
            }
        }

        // --- Global Wallpaper Engine Settings Popup ---
        MouseArea {
            id: weSettingsOverlay
            anchors.fill: parent
            visible: weSettingsPopup.visible
            z: 99
            onPressed: weSettingsPopup.visible = false
        }

        StyledRectangularShadow {
            target: weSettingsPopup
            radius: weSettingsPopup.radius
            visible: weSettingsPopup.visible
            z: 99
        }

        Rectangle {
            id: weSettingsPopup
            visible: false
            z: 100
            width: 280 * Appearance.effectiveScale
            height: weSettingsCol.implicitHeight + (24 * Appearance.effectiveScale)
            
            x: {
                let _ = visible;
                let _w = bgContainer.width;
                let p = weSettingsBtn.mapToItem(bgContainer, 0, 0);
                return Math.min(bgContainer.width - width - 12 * Appearance.effectiveScale, p.x + weSettingsBtn.width - width);
            }
            y: {
                let _ = visible;
                let _h = bgContainer.height;
                let p = weSettingsBtn.mapToItem(bgContainer, 0, 0);
                return p.y + weSettingsBtn.height + (8 * Appearance.effectiveScale);
            }

            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: 12 * Appearance.effectiveScale
            
            ColumnLayout {
                id: weSettingsCol
                anchors.fill: parent
                anchors.margins: 16 * Appearance.effectiveScale
                spacing: 12 * Appearance.effectiveScale
                
                StyledText {
                    text: I18nService.tr("Global Engine Settings")
                    font.pixelSize: Math.round(14 * Appearance.effectiveScale)
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                // FPS Slider
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4 * Appearance.effectiveScale
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Target FPS"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        StyledText { text: Math.round(fpsSlider.value); font.pixelSize: 12 * Appearance.effectiveScale; color: Appearance.colors.colPrimary; font.weight: Font.Bold }
                    }
                    StyledSlider {
                        id: fpsSlider
                        Layout.fillWidth: true
                        from: 10; to: 144
                        value: Config.ready ? Config.options.wallpaperEngine.fps : 30
                        onMoved: if (Config.ready) Config.options.wallpaperEngine.fps = Math.round(value)
                    }
                }

                // Volume Slider
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4 * Appearance.effectiveScale
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Global Volume"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        StyledText { text: Math.round(volSlider.value) + "%"; font.pixelSize: 12 * Appearance.effectiveScale; color: Appearance.colors.colPrimary; font.weight: Font.Bold }
                    }
                    StyledSlider {
                        id: volSlider
                        Layout.fillWidth: true
                        from: 0; to: 100
                        value: Config.ready ? Config.options.wallpaperEngine.volume : 15
                        onMoved: if (Config.ready) Config.options.wallpaperEngine.volume = Math.round(value)
                    }
                }

                // Scaling Mode
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4 * Appearance.effectiveScale
                    StyledText { text: I18nService.tr("Scaling Mode"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1 }
                    StyledComboBox {
                        id: scalingCombo
                        Layout.fillWidth: true
                        searchable: false
                        text: Config.ready ? Config.options.wallpaperEngine.scaling.charAt(0).toUpperCase() + Config.options.wallpaperEngine.scaling.slice(1) : "Fill"
                        model: ["Fill", "Stretch", "Fit", "Cover"]
                        onAccepted: (val) => {
                            if (Config.ready) Config.options.wallpaperEngine.scaling = val.toLowerCase();
                        }
                    }
                }

                // Toggles
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8 * Appearance.effectiveScale
                    
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Mute Audio"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.silent : false
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.silent = !checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Disable Audio Processing"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.disableAudioProcessing : false
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.disableAudioProcessing = !checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Auto-Pause (Windows)"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.autoPause : true
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.autoPause = !checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Disable Particles"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.disableParticles : true
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.disableParticles = !checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Disable Parallax"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.disableParallax : false
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.disableParallax = !checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Disable Mouse Interaction"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.disableMouse : false
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.disableMouse = !checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: I18nService.tr("Disable PBO (Texture Fix)"); font.pixelSize: Math.round(12 * Appearance.effectiveScale); color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                        AndroidToggle {
                            checked: Config.ready ? Config.options.wallpaperEngine.noPbo : true
                            onToggled: if (Config.ready) Config.options.wallpaperEngine.noPbo = !checked
                        }
                    }
                }
                
                Item { Layout.preferredHeight: 4 * Appearance.effectiveScale }
                
                StyledText {
                    text: I18nService.tr("* Requires Apply to take full effect")
                    font.pixelSize: Math.round(10 * Appearance.effectiveScale)
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignRight; Layout.fillWidth: true
                }
            }
        }
    }
}
