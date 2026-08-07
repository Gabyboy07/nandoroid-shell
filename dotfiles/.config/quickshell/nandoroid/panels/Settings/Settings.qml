import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

/**
 * Main Settings Application Window.
 * Central hub for system configuration.
 */
Scope {
    id: root
    
    property string pendingSearchQuery: ""
    property var searchResults: []
    property int currentResultIndex: 0
    property string lastQuery: ""

    function navigateToResult(index) {
        if (searchResults.length === 0) return;
        if (index < 0) index = searchResults.length - 1;
        if (index >= searchResults.length) index = 0;
        
        currentResultIndex = index;
        let result = searchResults[index];
        
        const targetPage = result.pageIndex;
        const query = result.matchedString || lastQuery;
        


        if (GlobalStates.settingsPageIndex === targetPage) {
            // Trigger search handler in the current page
            SearchRegistry.currentSearch = ""; // Reset first
            SearchRegistry.currentSearch = query;
        } else {
            root.pendingSearchQuery = query;
            GlobalStates.settingsPageIndex = targetPage;
        }
    }

    // Jumps requested from the launcher (< prefix): same navigation path as
    // the in-window search, so the target page highlights and scrolls into view.
    Connections {
        target: SearchRegistry
        function onPendingJumpChanged() {
            const jump = SearchRegistry.pendingJump;
            SearchRegistry.pendingJump = null;
            if (!jump || jump.pageIndex === undefined) return;
            if (GlobalStates.settingsPageIndex === jump.pageIndex) {
                SearchRegistry.currentSearch = "";
                SearchRegistry.currentSearch = jump.query;
            } else {
                root.pendingSearchQuery = jump.query;
                GlobalStates.settingsPageIndex = jump.pageIndex;
            }
        }
    }

    FloatingWindow {
        id: settingsWindow
        visible: GlobalStates.settingsOpen
        title: "Settings"
        
        readonly property var screen: Quickshell.screens[0]

        color: "transparent"

        // Since it's a real window, it defaults to a reasonable size:
        implicitWidth: Math.min(1100 * Appearance.effectiveScale, screen.width * 0.85)
        implicitHeight: Math.min(800 * Appearance.effectiveScale, screen.height * 0.8)

        onVisibleChanged: {
            if (!visible) {
                GlobalStates.settingsOpen = false;
            }
        }

        // Reset to first page whenever Settings closes
        Connections {
            target: GlobalStates
            function onSettingsOpenChanged() {
                if (!GlobalStates.settingsOpen) {
                    GlobalStates.settingsPageIndex = 0;
                    GlobalStates.settingsBluetoothPairMode = false;
                    SearchRegistry.currentSearch = ""; // Clear active search to allow re-triggering the same query next time
                    searchInput.text = ""; // Reset search text
                    searchInput.hasNoResults = false;
                }
            }
        }

        Component.onCompleted: {
            MaterialThemeLoader.reapplyTheme()
        }

        // Main Panel Background
        Rectangle {
            id: contentContainer
            anchors.fill: parent

            focus: visible
            Keys.onEscapePressed: GlobalStates.settingsOpen = false

            color: Appearance.colors.colLayer0
            border.color: Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSurface, 0.12)
            border.width: Math.max(1, 1 * Appearance.effectiveScale)
            radius: 20 * Appearance.effectiveScale

            // Trap clicks inside
            TapHandler {}

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12 * Appearance.effectiveScale
                spacing: 12 * Appearance.effectiveScale

                // ── Global Header ──
                Item {
                    id: headerWrapper
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52 * Appearance.effectiveScale // Reduced from 64

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20 * Appearance.effectiveScale
                        anchors.rightMargin: 0
                        spacing: 20 * Appearance.effectiveScale

                        StyledText {
                            text: I18nService.tr("Settings")
                            font.pixelSize: Math.round(24 * Appearance.effectiveScale)
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                            Layout.preferredWidth: 200 * Appearance.effectiveScale
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Truly Centered Search pill
                        Rectangle {
                            Layout.preferredWidth: 360 * Appearance.effectiveScale
                            Layout.preferredHeight: 44 * Appearance.effectiveScale
                            Layout.alignment: Qt.AlignVCenter
                            radius: 22 * Appearance.effectiveScale
                            color: Appearance.colors.colLayer1 // Using colLayer1 for search as it sits on colLayer0
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16 * Appearance.effectiveScale
                                spacing: 12 * Appearance.effectiveScale
                                MaterialSymbol {
                                    text: "search"
                                    iconSize: 22 * Appearance.effectiveScale
                                    color: Appearance.colors.colSubtext
                                }
                                StyledTextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.rightMargin: 16 * Appearance.effectiveScale
                                    inputRadius: 0
                                    backgroundColor: "transparent"
                                    borderInactiveWidth: 0
                                    showActiveBorder: false
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    placeholder: searchInput.hasNoResults ? I18nService.tr("No results found") : I18nService.tr("Search all settings..")
                                    placeholderColor: searchInput.hasNoResults ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                                    leftMargin: 0
                                    rightMargin: 0
                                    
                                    property bool hasNoResults: false
                                    
                                    onTextChanged: hasNoResults = false
                                    
                                    onAccepted: {
                                        const query = text.trim();
                                        if (query === "") return;

                                        if (query.toLowerCase() === root.lastQuery.toLowerCase() && root.searchResults.length > 0) {
                                            root.navigateToResult(root.currentResultIndex + 1);
                                        } else {
                                            root.lastQuery = query;
                                            let results = SearchRegistry.getResultsRanked(query);
                                            
                                            if (results && results.length > 0) {
                                                root.searchResults = results;
                                                root.currentResultIndex = 0;
                                                root.navigateToResult(0);
                                                hasNoResults = false;
                                            } else {
                                                root.searchResults = [];
                                                root.currentResultIndex = 0;
                                                hasNoResults = true;
                                            }
                                        }
                                    }
                                }

                                // Search Indicator (X/Y)
                                StyledText {
                                    visible: root.searchResults.length > 0 && searchInput.text === root.lastQuery
                                    text: (root.currentResultIndex + 1) + "/" + root.searchResults.length
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 16 * Appearance.effectiveScale
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Item {
                            Layout.preferredWidth: 200 * Appearance.effectiveScale
                            Layout.fillHeight: true

                            RippleButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 36 * Appearance.effectiveScale
                                implicitHeight: 36 * Appearance.effectiveScale
                                buttonRadius: 18 * Appearance.effectiveScale
                                colBackground: "transparent"
                                onClicked: GlobalStates.settingsOpen = false
                                
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 22 * Appearance.effectiveScale
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }


                // ── Main Content Area ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12 * Appearance.effectiveScale

                    SettingsSidebar {
                        id: sidebar
                        Layout.fillHeight: true
                        currentIndex: GlobalStates.settingsPageIndex
                        onPageSelected: (index) => {
                            GlobalStates.settingsPageIndex = index
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Appearance.colors.colLayer1
                        radius: 28 * Appearance.effectiveScale

                        Item {
                            anchors.fill: parent
                            clip: true

                            // Keep-alive page loaders (end4-pC style):
                            // Each page is loaded on first visit and stays alive afterwards,
                            // so switching pages never re-parses QML.
                            Repeater {
                                id: pagesRepeater
                                model: root.pages
                                delegate: Loader {
                                    id: pageLoader
                                    required property var modelData
                                    required property int index
                                    asynchronous: true
                                    active: GlobalStates.settingsPageIndex === index || item !== null
                                    anchors.fill: parent
                                    anchors.bottomMargin: 24 * Appearance.effectiveScale
                                    anchors.leftMargin: 24 * Appearance.effectiveScale
                                    anchors.rightMargin: 0
                                    source: modelData.component

                                    readonly property bool isActive: GlobalStates.settingsPageIndex === index

                                    anchors.topMargin: (isActive ? 24 : 44) * Appearance.effectiveScale
                                    opacity: isActive ? 1 : 0
                                    enabled: isActive
                                    visible: opacity > 0

                                    Behavior on anchors.topMargin {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }

                                    onLoaded: {
                                        if (isActive && root.pendingSearchQuery !== "") {
                                            applyPendingSearch()
                                        }
                                    }

                                    onIsActiveChanged: {
                                        if (isActive && item && root.pendingSearchQuery !== "") {
                                            applyPendingSearch()
                                        }
                                    }

                                    function applyPendingSearch() {
                                        if (root.pendingSearchQuery !== "") {
                                            SearchRegistry.currentSearch = "";
                                            SearchRegistry.currentSearch = root.pendingSearchQuery;
                                            root.pendingSearchQuery = "";
                                        }
                                    }

                                    TextEdit {
                                        visible: pageLoader.status === Loader.Error
                                        anchors.centerIn: parent
                                        width: Math.min(800 * Appearance.effectiveScale, parent.width - (40 * Appearance.effectiveScale))
                                        wrapMode: TextEdit.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                        text: I18nService.tr("Error loading page: ") + pageLoader.source + "\n\n" + (pageLoader.sourceComponent ? pageLoader.sourceComponent.errorString() : I18nService.tr("Unknown component error"))
                                        color: "#FF5555"
                                        font.pixelSize: Math.round(14 * Appearance.effectiveScale)
                                        font.family: "monospace"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var pages: [
        { name: "Network", component: "pages/Network/NetworkSettings.qml" },
        { name: "Bluetooth", component: "pages/Bluetooth/BluetoothSettings.qml" },
        { name: "Audio", component: "pages/Audio/AudioSettings.qml" },
        { name: "Display", component: "pages/Display/DisplaySettings.qml" },
        { name: "Wallpaper & Style", component: "pages/WallpaperStyle/WallpaperStyleSettings.qml" },
        { name: "Widgets", component: "pages/Widgets/WidgetsSettings.qml" },
        { name: "System", component: "pages/System/SystemSettings.qml" },
        { name: "Services", component: "pages/Services/ServicesSettings.qml" },
        { name: "Profile", component: "pages/Profile/ProfileSettings.qml" },
        { name: "About", component: "pages/About/AboutSettings.qml" }
    ]
}
