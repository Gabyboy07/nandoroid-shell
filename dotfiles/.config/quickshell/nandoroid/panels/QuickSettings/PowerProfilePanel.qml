import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts

/**
 * Power Profile detail panel.
 * Three cards: Daily / Work / Performance.
 * currentMode and onSetProfile are wired from QuickSettingsContent via the Loader.
 */
Rectangle {
    id: root
    signal dismiss()

    // Bound from parent (QuickSettingsContent.powerProfileMode)
    property string currentMode: "daily"
    // Called when user picks a card — parent updates the file + state
    signal setProfile(string profileId)

    focus: true
    property int navIndex: 0
    property bool inheritedNav: false
    property bool navEngaged: false

    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.panel

    // Block clicks and hovers from leaking through to the items below
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
        onPressed: (mouse) => mouse.accepted = true
    }

    readonly property var profiles: [
        {
            id: "daily",
            name: I18nService.tr("Power Saving"),
            icon: "eco",
            description: I18nService.tr("Light usage. Saves battery, stays cool.")
        },
        {
            id: "balanced",
            name: I18nService.tr("Balanced"),
            icon: "balance",
            description: I18nService.tr("Balanced for productivity tasks.")
        },
        {
            id: "performance",
            name: I18nService.tr("Performance"),
            icon: "local_fire_department",
            description: I18nService.tr("Full power for gaming or heavy loads.")
        }
    ]

    // ── Keyboard navigation ──
    function syncProfileRing() {
        const it = profileList.currentItem;
        if (!it) { profileNavRing.visible = false; return; }
        const p = it.mapToItem(root, 0, 0);
        profileNavRing.x = p.x - 4 * Appearance.effectiveScale;
        profileNavRing.y = p.y - 4 * Appearance.effectiveScale;
        profileNavRing.width = it.width + 8 * Appearance.effectiveScale;
        profileNavRing.height = it.height + 8 * Appearance.effectiveScale;
        profileNavRing.radius = Math.min(12 * Appearance.effectiveScale, profileNavRing.height / 2);
        profileNavRing.visible = root.activeFocus && root.navEngaged;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true; return; }
        if (profileList.count === 0) return;
        root.navEngaged = true;
        if (event.key === Qt.Key_Up) {
            if (profileList.currentIndex > 0) {
                profileList.currentIndex--;
                profileList.positionViewAtIndex(profileList.currentIndex, ListView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (profileList.currentIndex < profileList.count - 1) {
                profileList.currentIndex++;
                profileList.positionViewAtIndex(profileList.currentIndex, ListView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.setProfile(root.profiles[profileList.currentIndex].id);
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.navEngaged = root.inheritedNav;
        for (var i = 0; i < root.profiles.length; i++) {
            if (root.profiles[i].id === root.currentMode) { root.navIndex = i; break; }
        }
        if (profileList.count > 0) {
            profileList.currentIndex = root.navIndex;
            profileList.positionViewAtIndex(root.navIndex, ListView.Contain);
        }
        root.forceActiveFocus();
        root.syncProfileRing();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14 * Appearance.effectiveScale
        spacing: 12 * Appearance.effectiveScale

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * Appearance.effectiveScale

            RippleButton {
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.dismiss()
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 20 * Appearance.effectiveScale
                    color: Appearance.m3colors.m3onSurface
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: I18nService.tr("Power Profile")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
            }

            MaterialSymbol {
                text: "airwave"
                iconSize: 22 * Appearance.effectiveScale
                color: Appearance.colors.colPrimary
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }

        // ── List ──
        ListView {
            id: profileList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.profiles
            spacing: 8 * Appearance.effectiveScale
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: {
                if (profileList.currentIndex >= 0) {
                    root.navIndex = profileList.currentIndex;
                    root.syncProfileRing();
                }
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: 72 * Appearance.effectiveScale
                radius: Appearance.rounding.large
                
                readonly property bool isSelected: root.currentMode === modelData.id
                color: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12 * Appearance.effectiveScale
                    spacing: 16 * Appearance.effectiveScale

                    MaterialShapeWrappedMaterialSymbol {
                        text: modelData.icon
                        iconSize: 24 * Appearance.effectiveScale
                        shape: MaterialShape.Shape.Squircle
                        color: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        colSymbol: isSelected ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2 * Appearance.effectiveScale

                        StyledText {
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: isSelected ? Font.DemiBold : Font.Normal
                            color: isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            text: modelData.description
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurfaceVariant
                            opacity: isSelected ? 0.9 : 0.8
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    MaterialSymbol {
                        text: "check_circle"
                        iconSize: 20 * Appearance.effectiveScale
                        color: Appearance.colors.colPrimary
                        visible: isSelected
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        profileList.currentIndex = index
                        root.setProfile(modelData.id)
                    }
                }
            }
        }
    }

    // ── Keyboard focus ring ──
    Rectangle {
        id: profileNavRing
        visible: false
        z: 999
        enabled: false
        color: "transparent"
        border.width: Math.max(1, 2 * Appearance.effectiveScale)
        border.color: Appearance.m3colors.m3primary
        opacity: 0.9
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
