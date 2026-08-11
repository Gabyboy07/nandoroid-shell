import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * Secondary sidebar for the Settings panel.
 * Displays sections for the active settings page automatically from SearchRegistry.
 */
Rectangle {
    id: root
    
    property int pageIndex: 0
    property var sections: []
    // Only show if there are sections (more than 1 to be useful)
    implicitWidth: sections && sections.length > 1 ? 160 * Appearance.effectiveScale : 0
    visible: sections && sections.length > 1
    color: "transparent"
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    function refreshSections() {
        if (SearchRegistry.isIndexing) return;
        
        let filtered = [];
        let seen = new Set();
        let pageName = SearchRegistry.getPageName(root.pageIndex);
        let hasOtherSections = false;
        
        // Use raw sections to preserve exact top-to-bottom parsing order!
        for (let i = 0; i < SearchRegistry.sections.length; i++) {
            let section = SearchRegistry.sections[i];
            if (section.pageIndex === root.pageIndex) {
                if (!seen.has(section.canonical)) {
                    filtered.push({
                        title: section.translatedTitle,
                        matchedString: section.canonical,
                        pageIndex: section.pageIndex
                    });
                    seen.add(section.canonical);
                    if (section.canonical !== pageName) {
                        hasOtherSections = true;
                    }
                }
            }
        }
        
        // Remove the redundant fallback page name if actual sections exist
        if (hasOtherSections) {
            filtered = filtered.filter(s => s.matchedString !== pageName);
        }
        
        root.sections = filtered;
    }

    Connections {
        target: SearchRegistry
        function onIsIndexingChanged() { refreshSections(); }
    }

    onPageIndexChanged: refreshSections();
    Component.onCompleted: refreshSections();

    Flickable {
        anchors.fill: parent
        contentHeight: mainLayout.implicitHeight + 24 * Appearance.effectiveScale
        clip: true
        visible: root.visible
        ScrollBar.vertical: StyledScrollBar {}

        ColumnLayout {
            id: mainLayout
            width: parent.width
            anchors.margins: 12 * Appearance.effectiveScale
            spacing: 4 * Appearance.effectiveScale

        Repeater {
            model: root.sections

            delegate: RippleButton {
                Layout.fillWidth: true
                implicitHeight: 40 * Appearance.effectiveScale // Tighter M3 drawer list item height
                buttonRadius: 20 * Appearance.effectiveScale // Half of 40 for full capsule
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer0Hover
                
                onClicked: {
                    // Trigger the search handler to scroll to it
                    SearchRegistry.currentSearch = modelData.matchedString;
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16 * Appearance.effectiveScale
                    anchors.rightMargin: 16 * Appearance.effectiveScale
                    
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.matchedString
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Normal
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    }
}
