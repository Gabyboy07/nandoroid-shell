import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts

/**
 * Notification Mode detail panel.
 * Three cards: Normal / Silent / DND.
 */
Rectangle {
    id: root
    signal dismiss()

    focus: true
    property int navIndex: 0

    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.panel

    // Block clicks and hovers from leaking through to the items below
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
        onPressed: (mouse) => mouse.accepted = true
    }

    readonly property var modes: [
        {
            id: 0,
            name: I18nService.tr("Normal"),
            icon: "notifications_active",
            description: I18nService.tr("Popups and sounds are enabled.")
        },
        {
            id: 1,
            name: I18nService.tr("Silent"),
            icon: "vibration",
            description: I18nService.tr("Popups only. No sounds.")
        },
        {
            id: 2,
            name: I18nService.tr("Do Not Disturb"),
            icon: "notifications_off",
            description: I18nService.tr("No popups. No sounds. Saved to history.")
        }
    ]

    // ── Keyboard navigation ──
    function syncModeRing() {
        const it = modeList.currentItem;
        if (!it) { modeNavRing.visible = false; return; }
        const p = it.mapToItem(root, 0, 0);
        modeNavRing.x = p.x - 4 * Appearance.effectiveScale;
        modeNavRing.y = p.y - 4 * Appearance.effectiveScale;
        modeNavRing.width = it.width + 8 * Appearance.effectiveScale;
        modeNavRing.height = it.height + 8 * Appearance.effectiveScale;
        modeNavRing.radius = Math.min(12 * Appearance.effectiveScale, modeNavRing.height / 2);
        modeNavRing.visible = root.activeFocus;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true; return; }
        if (modeList.count === 0) return;
        if (event.key === Qt.Key_Up) {
            if (modeList.currentIndex > 0) {
                modeList.currentIndex--;
                modeList.positionViewAtIndex(modeList.currentIndex, ListView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (modeList.currentIndex < modeList.count - 1) {
                modeList.currentIndex++;
                modeList.positionViewAtIndex(modeList.currentIndex, ListView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            Notifications.mode = root.modes[modeList.currentIndex].id;
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        for (var i = 0; i < root.modes.length; i++) {
            if (root.modes[i].id === Notifications.mode) { root.navIndex = i; break; }
        }
        if (modeList.count > 0) {
            modeList.currentIndex = root.navIndex;
            modeList.positionViewAtIndex(root.navIndex, ListView.Contain);
        }
        root.forceActiveFocus();
        root.syncModeRing();
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
                text: I18nService.tr("Notification Mode")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
            }

            MaterialSymbol {
                text: "notifications"
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
            id: modeList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.modes
            spacing: 8 * Appearance.effectiveScale
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: {
                if (modeList.currentIndex >= 0) {
                    root.navIndex = modeList.currentIndex;
                    root.syncModeRing();
                }
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: 72 * Appearance.effectiveScale
                radius: Appearance.rounding.large
                
                readonly property bool isSelected: Notifications.mode === modelData.id
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
                        modeList.currentIndex = index
                        Notifications.mode = modelData.id
                    }
                }
            }
        }
    }

    // ── Keyboard focus ring ──
    Rectangle {
        id: modeNavRing
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
