import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui

// NetworkManager-backed connection state and Wi-Fi picker. Bar state still
// comes from `omarchy-network-status --verbose` for interface/IP detail.
Panel {
  id: root
  moduleName: "whiterose.network"
  ipcTarget: "whiterose.network"

  property string iface: ""
  property string kind: ""
  property string ssid: ""
  property string ip: ""
  property int signalPercent: -1

  readonly property bool connected: iface !== ""
  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property bool wifiAvailable: networkManagerAvailable && wifiDevice !== null
  readonly property var networkRows: wifiNetworks

  property var wifiNetworks: []
  property int cursor: 0
  property bool scanning: false
  property string actionSsid: ""
  property string actionKind: ""
  property string failureSsid: ""
  property string failureReason: ""
  property string passwordSsid: ""
  property string passwordText: ""

  readonly property bool busy: actionKind !== ""

  readonly property string glyph: {
    if (!connected) return "\u{f092e}"
    if (kind !== "wifi") return "\u{f0200}"
    return wifiIconFor(signalPercent)
  }

  function updateStatus(raw) {
    var fields = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var tab = lines[i].indexOf("\t")
      if (tab > 0) fields[lines[i].slice(0, tab)] = lines[i].slice(tab + 1).trim()
    }
    iface = fields.iface || ""
    kind = fields.type || (iface ? "ethernet" : "")
    ssid = fields.ssid || ""
    ip = fields.ip || ""
    var dbm = parseFloat(fields.signal_dbm)
    signalPercent = isNaN(dbm) ? -1 : Math.max(0, Math.min(100, Math.round(2 * (dbm + 100))))
  }

  function findDevice(type) {
    var devices = networkDevices || []
    for (var i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i].type === type) return devices[i]
    }
    return null
  }

  function wifiIconFor(strength) {
    var icons = ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]
    if (strength < 0) return icons[4]
    var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1))
    return icons[index]
  }

  function wifiRow(network) {
    if (!network) return null
    return {
      network: network,
      connected: !!network.connected,
      known: !!network.known,
      ssid: network.name || "",
      signal: Math.round(Number(network.signalStrength || 0) * 100),
      security: network.security
    }
  }

  function sortWifiRows(rows) {
    var next = rows.slice()
    next.sort(function(a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.known !== b.known) return a.known ? -1 : 1
      return b.signal - a.signal
    })
    return next
  }

  function syncWifiNetworks() {
    if (!wifiAvailable) {
      wifiNetworks = []
      scanning = false
      return
    }
    var rows = []
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      var network = networks[i]
      if (!network) continue
      checkActionCompletion(network)
      var row = wifiRow(network)
      if (row) rows.push(row)
    }
    wifiNetworks = sortWifiRows(rows)
    scanning = false
  }

  function isProtected(security) {
    return security !== WifiSecurityType.Open
  }

  function networkForSsid(targetSsid) {
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].name === targetSsid) return networks[i]
    }
    return null
  }

  function moveCursor(delta) {
    if (networkRows.length === 0) return
    cursor = Math.max(0, Math.min(networkRows.length - 1, cursor + delta))
  }

  function openPasswordPrompt(targetSsid) {
    if (passwordSsid !== targetSsid) passwordText = ""
    passwordSsid = targetSsid
  }

  function runNetworkAction(kind, network, callback) {
    if (busy || !network) return
    actionSsid = network.name || ""
    actionKind = kind
    failureSsid = ""
    failureReason = ""
    callback(network)
    actionTimeout.restart()
  }

  function clearNetworkAction() {
    actionTimeout.stop()
    if (actionKind === "connect") {
      passwordSsid = ""
      passwordText = ""
    }
    actionSsid = ""
    actionKind = ""
    refresh(false)
  }

  function failNetworkAction(network, reason) {
    if (!network || actionKind === "" || actionSsid !== (network.name || "")) return
    actionTimeout.stop()
    failureSsid = actionSsid
    failureReason = networkFailureReason(reason)
    actionSsid = ""
    actionKind = ""
    refresh(false)
  }

  function networkFailureReason(reason) {
    if (reason === ConnectionFailReason.NoSecrets) return "passphrase required"
    if (reason === ConnectionFailReason.WifiAuthTimeout) return "wrong passphrase"
    if (reason === ConnectionFailReason.WifiNetworkLost) return "network lost"
    if (reason === ConnectionFailReason.WifiClientDisconnected) return "disconnected"
    if (reason === ConnectionFailReason.WifiClientFailed) return "connection failed"
    return "failed"
  }

  function checkActionCompletion(network) {
    if (!network || actionKind === "" || actionSsid !== (network.name || "")) return
    if (actionKind === "connect" && network.connected) clearNetworkAction()
    else if (actionKind === "disconnect" && !network.connected && !network.stateChanging) clearNetworkAction()
  }

  function connectKnown(targetSsid) {
    runNetworkAction("connect", networkForSsid(targetSsid), function(network) { network.connect() })
  }

  function connectWithPassphrase(targetSsid, passphrase) {
    runNetworkAction("connect", networkForSsid(targetSsid), function(network) { network.connectWithPsk(passphrase) })
  }

  function disconnect(network) {
    runNetworkAction("disconnect", network, function(net) { net.disconnect() })
  }

  function activateRow(row) {
    if (!row || busy) return
    if (!row.network) return
    if (row.connected) {
      disconnect(row.network)
      return
    }
    if (isProtected(row.security) && !row.known) {
      openPasswordPrompt(row.ssid)
      return
    }
    connectKnown(row.ssid)
  }

  function activateSelected() {
    if (cursor < 0 || cursor >= networkRows.length) return
    activateRow(networkRows[cursor])
  }

  function refresh(scanWifi) {
    if (!statusProc.running) statusProc.running = true
    if (!wifiAvailable) {
      wifiNetworks = []
      scanning = false
      return
    }
    if (scanWifi) {
      scanning = true
      wifiDevice.scannerEnabled = false
      scanRestart.restart()
    } else {
      wifiDevice.scannerEnabled = opened
      syncWifiNetworks()
    }
  }

  function toggleWifi() {
    if (!networkManagerAvailable) return
    Networking.wifiEnabled = !Networking.wifiEnabled
    Qt.callLater(function() { refresh(true) })
  }

  onOpenedChanged: {
    if (opened) {
      refresh(true)
      cursor = networkRows.length > 0 ? 0 : -1
    } else {
      passwordSsid = ""
      passwordText = ""
      if (wifiDevice) wifiDevice.scannerEnabled = false
    }
  }

  onWifiDeviceChanged: {
    if (wifiDevice) wifiDevice.scannerEnabled = opened
    syncWifiNetworks()
  }

  onWifiNetworkObjectsChanged: syncWifiNetworks()
  onNetworkRowsChanged: {
    if (networkRows.length === 0) cursor = -1
    else if (cursor < 0) cursor = 0
    else if (cursor >= networkRows.length) cursor = networkRows.length - 1
  }
  onNetworkManagerAvailableChanged: refresh(true)
  onPasswordSsidChanged: if (passwordSsid === "") passwordText = ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: {
    refresh(false)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    dimmed: !root.connected
    tooltipText: {
      if (!root.connected) return "Disconnected"
      if (root.kind === "wifi") return (root.ssid || root.iface) + (root.signalPercent >= 0 ? "  " + root.signalPercent + "%" : "")
      return root.iface + (root.ip ? "  " + root.ip : "")
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleWifi()
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
    contentWidth: pop.fittedContentWidth(Style.space(320))
    contentHeight: pop.fittedContentHeight(content.implicitHeight, Style.space(440))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.passwordSsid !== ""
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: root.activateSelected()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh(true)
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
            text: "network"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }

          Text {
            id: wifiToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.networkManagerAvailable ? (Networking.wifiEnabled ? "nm on" : "nm off") : "nm unavailable"
            color: root.networkManagerAvailable && Networking.wifiEnabled ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2

            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              enabled: root.networkManagerAvailable
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.toggleWifi()
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Color.popups.text; opacity: 0.08 }

        Text {
          visible: root.networkRows.length === 0
          width: parent.width
          text: !root.networkManagerAvailable ? "NetworkManager unavailable"
            : (!root.wifiDevice ? "no Wi-Fi device" : (root.scanning ? "scanning..." : "no networks found"))
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          topPadding: Style.space(4)
          bottomPadding: Style.space(4)
        }

        Repeater {
          model: root.networkRows

          Item {
            id: networkRow
            required property var modelData
            required property int index

            readonly property bool selected: index === root.cursor
            readonly property bool protectedNetwork: root.isProtected(modelData.security)
            readonly property bool passwordOpen: root.passwordSsid !== "" && root.passwordSsid === modelData.ssid
            readonly property bool rowBusy: root.actionKind !== "" && root.actionSsid === modelData.ssid
            readonly property bool rowFailed: root.failureReason !== "" && root.failureSsid === modelData.ssid
            readonly property string statusText: {
              if (passwordOpen) return ""
              if (rowBusy && root.actionKind === "connect") return "connecting"
              if (rowBusy && root.actionKind === "disconnect") return "disconnecting"
              if (rowFailed) return root.failureReason
              if (modelData.connected) return "connected"
              if (modelData.known) return "known"
              return ""
            }

            width: content.width
            height: rowBody.height + (passwordOpen ? passwordPanel.height + Style.space(6) : 0)

            Connections {
              target: networkRow.modelData ? networkRow.modelData.network : null
              function onConnectionFailed(reason) {
                root.failNetworkAction(networkRow.modelData.network, reason)
                if (reason === ConnectionFailReason.NoSecrets) root.openPasswordPrompt(networkRow.modelData.ssid)
              }
              function onConnectedChanged() { root.checkActionCompletion(networkRow.modelData.network) }
              function onStateChangingChanged() { root.checkActionCompletion(networkRow.modelData.network) }
            }

            Item {
              id: rowBody
              width: parent.width
              height: Style.space(32)

              Rectangle {
                anchors.fill: parent
                radius: Math.min(Style.cornerRadius, Style.space(5))
                color: Color.popups.text
                opacity: networkRow.selected ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }

              Text {
                id: rowIcon
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiIconFor(networkRow.modelData.signal)
                color: networkRow.modelData.connected ? Color.accent : Color.popups.text
                opacity: networkRow.modelData.connected ? 1 : 0.72
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              Text {
                id: lockIcon
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                visible: networkRow.protectedNetwork
                text: "\u{f033e}"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Text {
                id: stateLabel
                anchors.right: networkRow.protectedNetwork ? lockIcon.left : parent.right
                anchors.rightMargin: networkRow.protectedNetwork ? Style.space(8) : Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: networkRow.statusText
                color: networkRow.rowFailed ? Color.urgent : (networkRow.modelData.connected ? Color.accent : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.left: rowIcon.right
                anchors.leftMargin: Style.space(10)
                anchors.right: stateLabel.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: networkRow.modelData.ssid || "Hidden"
                color: Color.popups.text
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.busy
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onContainsMouseChanged: if (containsMouse) root.cursor = networkRow.index
                onClicked: {
                  root.cursor = networkRow.index
                  root.activateRow(networkRow.modelData)
                }
              }
            }

            Item {
              id: passwordPanel
              visible: networkRow.passwordOpen
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: rowBody.bottom
              anchors.topMargin: Style.space(4)
              height: visible ? Style.space(30) : 0

              TextField {
                id: passwordField
                anchors.left: parent.left
                anchors.right: connectButton.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                password: true
                placeholderText: "Passphrase"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                foreground: Color.popups.text
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(4)
                enabled: !networkRow.rowBusy
                text: networkRow.passwordOpen ? root.passwordText : ""
                onAccepted: if (!root.busy && text.length > 0) root.connectWithPassphrase(networkRow.modelData.ssid, text)
                onTextChanged: if (networkRow.passwordOpen && text !== root.passwordText) root.passwordText = text
                Keys.onEscapePressed: root.passwordSsid = ""
                onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
              }

              BorderSurface {
                id: connectButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(30)
                height: Style.space(26)
                color: connectMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
                borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
                radius: Math.min(Style.cornerRadius, Style.space(5))
                opacity: root.passwordText.length > 0 && !root.busy ? 1 : 0.45

                Text {
                  anchors.centerIn: parent
                  text: "\u{f012c}"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: connectMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: root.passwordText.length > 0 && !root.busy
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.connectWithPassphrase(networkRow.modelData.ssid, root.passwordText)
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "enter toggles    r rescans    right click wifi"
          color: Color.muted
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          topPadding: Style.space(2)
        }
      }
    }
  }

  Process {
    id: statusProc
    command: [root.bar ? root.bar.omarchyPath + "/bin/omarchy-network-status" : "omarchy-network-status", "--verbose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStatus(text)
    }
  }

  Timer {
    interval: 3000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  Timer {
    id: scanRestart
    interval: 100
    repeat: false
    onTriggered: {
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = true
      scanDone.restart()
    }
  }

  Timer {
    id: scanDone
    interval: 1500
    repeat: false
    onTriggered: root.syncWifiNetworks()
  }

  Timer {
    id: actionTimeout
    interval: 15000
    repeat: false
    onTriggered: {
      if (!root.actionKind) return
      root.failureSsid = root.actionSsid
      root.failureReason = root.actionKind === "connect" ? "timed out connecting" : "timed out disconnecting"
      root.actionSsid = ""
      root.actionKind = ""
      root.refresh(false)
    }
  }
}
