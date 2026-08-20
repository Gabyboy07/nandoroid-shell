import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

/**
 * Functional Bluetooth device list panel.
 * Shows real devices using Quickshell.Bluetooth.
 */
Rectangle {
    id: root
    signal dismiss()
    
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

    // ── Keyboard navigation ──
    function syncBtRing() {
        const it = deviceList.currentItem;
        if (!it) { btNavRing.visible = false; return; }
        const p = it.mapToItem(root, 0, 0);
        btNavRing.x = p.x - 4 * Appearance.effectiveScale;
        btNavRing.y = p.y - 4 * Appearance.effectiveScale;
        btNavRing.width = it.width + 8 * Appearance.effectiveScale;
        btNavRing.height = it.height + 8 * Appearance.effectiveScale;
        btNavRing.radius = Math.min(12 * Appearance.effectiveScale, btNavRing.height / 2);
        btNavRing.visible = root.activeFocus && root.navEngaged;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true; return; }
        if (deviceList.count === 0) return;
        root.navEngaged = true;
        if (event.key === Qt.Key_Up) {
            if (deviceList.currentIndex > 0) {
                deviceList.currentIndex--;
                deviceList.positionViewAtIndex(deviceList.currentIndex, ListView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (deviceList.currentIndex < deviceList.count - 1) {
                deviceList.currentIndex++;
                deviceList.positionViewAtIndex(deviceList.currentIndex, ListView.Contain);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            const it = deviceList.currentItem;
            if (it && it.deviceButton) it.deviceButton.click();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.navEngaged = root.inheritedNav;
        if (deviceList.count > 0) {
            deviceList.currentIndex = 0;
            deviceList.positionViewAtIndex(0, ListView.Contain);
        }
        root.forceActiveFocus();
        root.syncBtRing();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14 * Appearance.effectiveScale
        spacing: 12 * Appearance.effectiveScale

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * Appearance.effectiveScale

            RippleButton {
                implicitWidth: 36 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: Appearance.colors.colLayer2
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
                text: I18nService.tr("Bluetooth Devices")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.m3colors.m3onSurface
            }

            // Bluetooth power toggle
            RippleButton {
                implicitWidth: 56 * Appearance.effectiveScale
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: 18 * Appearance.effectiveScale
                colBackground: BluetoothStatus.enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                colBackgroundHover: BluetoothStatus.enabled ? Qt.darker(Appearance.colors.colPrimary, 1.12) : Appearance.colors.colLayer2Hover
                onClicked: {
                    BluetoothStatus.toggle();
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                    iconSize: 20 * Appearance.effectiveScale
                    color: BluetoothStatus.enabled ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }

        // Device list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16 * Appearance.effectiveScale
            color: Appearance.colors.colLayer0
            clip: true

            ListView {
                id: deviceList
                anchors.fill: parent
                anchors.margins: 4 * Appearance.effectiveScale
                clip: true
                spacing: 2 * Appearance.effectiveScale
                model: BluetoothStatus.enabled ? [...BluetoothStatus.connectedDevices, ...BluetoothStatus.pairedButNotConnectedDevices] : []
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: {
                    if (deviceList.currentIndex >= 0) {
                        root.navIndex = deviceList.currentIndex;
                        root.syncBtRing();
                    }
                }

                delegate: Item {
                    id: deviceItem
                    required property var modelData
                    required property int index
                    property alias deviceButton: cardHeader
                    property bool expanded: false
                    width: deviceList.width
                    implicitHeight: deviceContent.implicitHeight

                    ColumnLayout {
                        id: deviceContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0

                        RippleButton {
                            id: cardHeader
                            Layout.fillWidth: true
                            implicitHeight: 64 * Appearance.effectiveScale
                            buttonRadius: 16 * Appearance.effectiveScale
                            colBackground: {
                                if (deviceItem.modelData.connected) return Functions.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.92)
                                if (deviceItem.expanded) return Appearance.colors.colLayer0Hover
                                return "transparent"
                            }
                            colBackgroundHover: deviceItem.modelData.connected ? colBackground : Appearance.colors.colLayer0Hover
                            onClicked: {
                                deviceList.currentIndex = deviceItem.index
                                deviceItem.expanded = !deviceItem.expanded
                            }

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * Appearance.effectiveScale
                                anchors.rightMargin: 12 * Appearance.effectiveScale
                                spacing: 12 * Appearance.effectiveScale

                                MaterialSymbol {
                                    text: {
                                        const type = deviceItem.modelData.deviceType;
                                        if (type === "phone") return "smartphone"
                                        if (type === "computer") return "computer"
                                        if (type === "audio-card") return "headset"
                                        return "bluetooth"
                                    }
                                    iconSize: 22 * Appearance.effectiveScale
                                    color: deviceItem.modelData.connected ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        text: deviceItem.modelData.name || deviceItem.modelData.address
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: deviceItem.modelData.connected ? Font.DemiBold : Font.Normal
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    StyledText {
                                        readonly property var _d: deviceItem.modelData
                                        text: {
                                            if (_d.connected) return I18nService.tr("Connected") + (_d.batteryAvailable ? " · " + Math.round(_d.battery * 100) + "%" : "")
                                            if (_d.state === BluetoothDeviceState.Connecting || BluetoothStatus.pairingAddress === _d.address) return I18nService.tr("Connecting...")
                                            if (_d.pairing) return I18nService.tr("Pairing...")
                                            if (_d.paired || _d.trusted) return I18nService.tr("Paired")
                                            return I18nService.tr("Available")
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: _d.state === BluetoothDeviceState.Connecting || _d.pairing ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                RippleButton {
                                    implicitWidth: 32 * Appearance.effectiveScale
                                    implicitHeight: 32 * Appearance.effectiveScale
                                    buttonRadius: 16 * Appearance.effectiveScale
                                    colBackground: "transparent"
                                    onClicked: deviceItem.expanded = !deviceItem.expanded
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: deviceItem.expanded ? "expand_less" : "expand_more"
                                        iconSize: 20 * Appearance.effectiveScale
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }

                            // Header rounding overlay for expansion joint
                            Rectangle {
                                anchors.fill: parent
                                visible: deviceItem.expanded
                                color: cardHeader.colBackground
                                z: -1
                                radius: 16 * Appearance.effectiveScale
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 16 * Appearance.effectiveScale
                                    color: parent.color
                                }
                            }
                        }

                        // ── Expanded Actions ──
                        Rectangle {
                            id: cardExpansion
                            Layout.fillWidth: true
                            Layout.preferredHeight: deviceItem.expanded ? expansionColumn.implicitHeight + (32 * Appearance.effectiveScale) : 0
                            clip: true
                            color: Appearance.colors.colLayer2
                            radius: 16 * Appearance.effectiveScale
                            opacity: deviceItem.expanded ? 1 : 0
                            visible: Layout.preferredHeight > 0
                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Rectangle {
                                width: parent.width
                                height: 16 * Appearance.effectiveScale
                                color: parent.color
                                visible: deviceItem.expanded
                                anchors.top: parent.top
                            }

                            ColumnLayout {
                                id: expansionColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 16 * Appearance.effectiveScale
                                anchors.rightMargin: 16 * Appearance.effectiveScale
                                anchors.top: parent.top
                                anchors.topMargin: 16 * Appearance.effectiveScale
                                spacing: 12 * Appearance.effectiveScale

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12 * Appearance.effectiveScale

                                    Item { Layout.fillWidth: true }

                                    RippleButton {
                                        visible: (deviceItem.modelData.paired || deviceItem.modelData.trusted) && !deviceItem.modelData.connected
                                        buttonText: I18nService.tr("Forget")
                                        implicitWidth: 90 * Appearance.effectiveScale
                                        implicitHeight: 36 * Appearance.effectiveScale
                                        buttonRadius: 18 * Appearance.effectiveScale
                                        colBackground: Appearance.m3colors.m3error
                                        colText: Appearance.m3colors.m3onError
                                        onClicked: {
                                            if (deviceItem.modelData.forget) deviceItem.modelData.forget()
                                            else if (deviceItem.modelData.unpair) deviceItem.modelData.unpair()
                                            deviceItem.modelData.trusted = false
                                            deviceItem.expanded = false
                                        }
                                    }

                                    RippleButton {
                                        visible: deviceItem.modelData.paired
                                        buttonText: deviceItem.modelData.connected ? I18nService.tr("Disconnect") : I18nService.tr("Connect")
                                        implicitWidth: 110 * Appearance.effectiveScale
                                        implicitHeight: 36 * Appearance.effectiveScale
                                        buttonRadius: 18 * Appearance.effectiveScale
                                        colBackground: Appearance.colors.colPrimary
                                        colText: Appearance.colors.colOnPrimary
                                        onClicked: {
                                            if (deviceItem.modelData.connected) deviceItem.modelData.disconnect()
                                            else BluetoothStatus.pairAndTrust(deviceItem.modelData)
                                            deviceItem.expanded = false
                                        }
                                    }

                                    RippleButton {
                                        visible: !deviceItem.modelData.paired
                                        buttonText: I18nService.tr("Pair & Connect")
                                        implicitWidth: 110 * Appearance.effectiveScale
                                        implicitHeight: 36 * Appearance.effectiveScale
                                        buttonRadius: 18 * Appearance.effectiveScale
                                        colBackground: Appearance.colors.colPrimary
                                        colText: Appearance.colors.colOnPrimary
                                        onClicked: {
                                            BluetoothStatus.pairAndTrust(deviceItem.modelData)
                                            deviceItem.expanded = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.m3colors.m3outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * Appearance.effectiveScale

            RippleButton {
                visible: BluetoothStatus.enabled
                implicitWidth: btPairText.implicitWidth + (24 * Appearance.effectiveScale)
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: height / 2
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: {
                    GlobalStates.settingsPageIndex = 1;
                    GlobalStates.settingsBluetoothPairMode = true;
                    GlobalStates.activateSettings();
                }
                StyledText {
                    id: btPairText
                    anchors.centerIn: parent
                    text: I18nService.tr("Pair new device")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitWidth: btDoneText.implicitWidth + (24 * Appearance.effectiveScale)
                implicitHeight: 36 * Appearance.effectiveScale
                buttonRadius: height / 2
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Qt.darker(Appearance.colors.colPrimary, 1.1)
                onClicked: root.dismiss()
                StyledText {
                    id: btDoneText
                    anchors.centerIn: parent
                    text: I18nService.tr("Done")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }

    // ── Keyboard focus ring ──
    Rectangle {
        id: btNavRing
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
