pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core"

Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property alias font: input.font
    property alias color: input.color
    property alias echoMode: input.echoMode
    property alias input: input
    property alias readOnly: input.readOnly
    property alias selectByMouse: input.selectByMouse
    property alias horizontalAlignment: input.horizontalAlignment

    property real inputRadius: 12
    property color backgroundColor: Appearance.m3colors.m3surfaceContainerLow
    property real borderInactiveWidth: 0
    property bool showActiveBorder: true

    signal editingFinished()
    signal accepted()

    implicitWidth: 200 * Appearance.effectiveScale
    implicitHeight: 48 * Appearance.effectiveScale

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.inputRadius * Appearance.effectiveScale
        color: root.backgroundColor
        border.width: input.activeFocus && root.showActiveBorder ? Math.max(1, 2 * Appearance.effectiveScale) : root.borderInactiveWidth * Appearance.effectiveScale
        border.color: Appearance.colors.colPrimary
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 16 * Appearance.effectiveScale
        anchors.rightMargin: 16 * Appearance.effectiveScale
        verticalAlignment: TextInput.AlignVCenter
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.normal
        color: Appearance.colors.colOnLayer1
        clip: true

        onEditingFinished: root.editingFinished()
        onAccepted: root.accepted()

        StyledText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: input.horizontalAlignment
            text: root.placeholder
            color: Appearance.colors.colSubtext
            visible: input.text === "" && !input.activeFocus
        }

        onActiveFocusChanged: {
            if (activeFocus)
                focusGuard.open()
        }
    }

    Popup {
        id: focusGuard
        x: 0
        y: 0
        width: root.width
        height: root.height
        padding: 0
        margins: 0
        modal: false
        closePolicy: Popup.CloseOnPressOutside

        background: Item {}

        onClosed: input.focus = false
    }
}
