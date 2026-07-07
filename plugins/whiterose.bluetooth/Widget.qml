import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Commons
import qs.Ui

// Bluetooth with a device picker. Left click opens the popout (Enter or
// click connects/disconnects a device), right click toggles the adapter.
Panel {
  id: root
  moduleName: "whiterose.bluetooth"
  ipcTarget: "whiterose.bluetooth"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool enabled: adapter !== null && adapter.enabled

  property int cursor: 0
  property string pendingAddress: ""

  function deviceLabel(device) {
    return (device && (device.name || device.deviceName)) || (device ? device.address : "")
  }

  // Connected first, then remembered devices, both sorted by label.
  readonly property var rows: {
    if (!enabled || !Bluetooth.devices) return []
    var connected = []
    var known = []
    var devices = Bluetooth.devices.values
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device) continue
      if (device.connected) connected.push(device)
      else if (device.paired || device.bonded || device.trusted) known.push(device)
    }
    var byLabel = function(a, b) { return deviceLabel(a).localeCompare(deviceLabel(b)) }
    connected.sort(byLabel)
    known.sort(byLabel)
    return connected.concat(known)
  }

  readonly property int connectedCount: {
    var count = 0
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].connected) count++
    }
    return count
  }

  function toggleAdapter() {
    if (adapter) adapter.enabled = !adapter.enabled
  }

  function toggleDevice(device) {
    if (!device || !device.address) return
    pendingAddress = device.address
    pendingClear.restart()
    if (device.connected) {
      if (device.disconnect) device.disconnect()
      else Quickshell.execDetached(["omarchy-bluetooth-device", "disconnect", device.address])
    } else {
      var action = (device.paired || device.bonded || device.trusted) ? "connect" : "pair"
      Quickshell.execDetached(["omarchy-bluetooth-device", action, device.address])
    }
  }

  function moveCursor(delta) {
    if (rows.length === 0) return
    cursor = (cursor + delta + rows.length) % rows.length
  }

  onRowsChanged: {
    if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)
    pendingAddress = ""
  }

  Timer {
    id: pendingClear
    interval: 8000
    onTriggered: root.pendingAddress = ""
  }

  visible: adapter !== null
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.connectedCount > 0 ? "\u{f00b1}" : (root.enabled ? "\u{f00af}" : "\u{f00b2}")
    dimmed: !root.enabled
    tooltipText: {
      if (!root.enabled) return "Bluetooth off"
      if (root.connectedCount > 0) return root.connectedCount + " connected"
      return "Bluetooth on"
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleAdapter()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: pop
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: pop.fittedContentWidth(Style.space(280))
    contentHeight: pop.fittedContentHeight(content.implicitHeight, Style.space(360))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: {
        if (root.rows.length > 0) root.toggleDevice(root.rows[root.cursor])
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(6)

        Item {
          width: parent.width
          height: Style.space(20)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "bluetooth"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.enabled ? "on" : "off"
            color: root.enabled ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2

            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleAdapter()
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Color.popups.text
          opacity: 0.08
        }

        Text {
          visible: root.rows.length === 0
          text: root.enabled ? "no known devices" : "adapter is off"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          topPadding: Style.space(4)
          bottomPadding: Style.space(4)
        }

        Repeater {
          model: root.rows

          Item {
            id: deviceRow

            required property var modelData
            required property int index

            readonly property bool selected: index === root.cursor
            readonly property bool pending: root.pendingAddress !== "" && root.pendingAddress === modelData.address

            width: content.width
            height: Style.space(30)

            Rectangle {
              anchors.fill: parent
              radius: Math.min(Style.cornerRadius, Style.space(5))
              color: Color.popups.text
              opacity: deviceRow.selected ? 0.08 : 0
              Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(6)
              height: Style.space(6)
              radius: width / 2
              color: deviceRow.modelData.connected ? Color.accent : Color.muted
              opacity: deviceRow.modelData.connected ? 1 : 0.4
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(22)
              anchors.right: stateLabel.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.deviceLabel(deviceRow.modelData)
              color: Color.popups.text
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              id: stateLabel
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: deviceRow.pending ? "..." : (deviceRow.modelData.connected ? "connected" : "")
              color: deviceRow.pending ? Color.popups.text : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.cursor = deviceRow.index
              onClicked: root.toggleDevice(deviceRow.modelData)
            }
          }
        }

        Text {
          width: parent.width
          text: "enter toggles    right click power"
          color: Color.muted
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          topPadding: Style.space(2)
        }
      }
    }
  }
}
