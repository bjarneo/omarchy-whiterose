import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui

// Bar state still comes from `omarchy-network-status --verbose`, which reads
// kernel/ip/iw state correctly on iwd systems. The popout prefers the
// Quickshell.Networking NetworkManager backend for Wi-Fi actions, then iwd
// via iwctl, and finally a read-only iw scan when neither manager is usable.
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
  readonly property string configuredBackend: normalizedBackend(String(setting("backend", "auto")))
  readonly property bool networkManagerUsable: networkManagerAvailable && wifiDevice !== null
  property bool iwdAvailable: false
  readonly property bool useNetworkManager: configuredBackend !== "iwd" && configuredBackend !== "iw" && networkManagerUsable
  readonly property bool useIwd: !useNetworkManager && configuredBackend !== "iw" && iwdAvailable
  readonly property string backendLabel: useNetworkManager ? "nm"
    : (useIwd ? (configuredBackend === "iwd" ? "iwd" : "iwd fallback")
      : (configuredBackend === "iw" ? "iw" : "iw fallback"))
  readonly property var networkRows: useNetworkManager ? wifiNetworks : iwNetworks

  property var wifiNetworks: []
  property var iwNetworks: []
  property string iwScanError: ""
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

  function normalizedBackend(value) {
    var v = String(value || "auto").toLowerCase()
    return (v === "nm" || v === "iwd" || v === "iw" || v === "auto") ? v : "auto"
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
    if (!useNetworkManager) return
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

  function updateIwNetworks(raw) {
    var rows = []
    var seen = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      var name = parts[0] || ""
      if (!name || seen[name]) continue
      seen[name] = true
      var dbm = parseFloat(parts[1] || "")
      if (!isNaN(dbm) && dbm < -200) dbm = dbm / 100
      var signal = isNaN(dbm) ? -1 : Math.max(0, Math.min(100, Math.round(2 * (dbm + 100))))
      rows.push({
        backend: useIwd ? "iwd" : "iw",
        network: null,
        connected: kind === "wifi" && ssid !== "" && name === ssid,
        known: false,
        ssid: name,
        signal: signal,
        security: parts[2] === "1" ? "protected" : WifiSecurityType.Open
      })
    }
    iwNetworks = sortWifiRows(rows)
    iwScanError = ""
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

  function runIwdAction(kind, targetSsid, passphrase) {
    if (busy) return
    actionSsid = targetSsid || ssid || ""
    actionKind = kind
    failureSsid = ""
    failureReason = ""
    iwdActionProc.command = [
      "bash",
      "-lc",
      "iface=${WHITEROSE_NETWORK_IFACE:-}; if [[ -z $iface ]]; then iface=$(iw dev 2>/dev/null | awk '$1 == \"Interface\" { print $2; exit }'); fi; [[ -n $iface ]] || { echo 'no wireless interface' >&2; exit 2; }; action=$1; ssid=$2; passphrase=$3; case $action in connect) if [[ -n $passphrase ]]; then iwctl --passphrase \"$passphrase\" station \"$iface\" connect \"$ssid\"; else iwctl --dont-ask station \"$iface\" connect \"$ssid\"; fi ;; disconnect) iwctl station \"$iface\" disconnect ;; *) echo \"unknown iwd action: $action\" >&2; exit 2 ;; esac",
      "whiterose-iwd",
      kind,
      targetSsid || "",
      passphrase || ""
    ]
    iwdActionProc.running = true
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
    if (useIwd) {
      runIwdAction("connect", targetSsid, "")
      return
    }
    runNetworkAction("connect", networkForSsid(targetSsid), function(network) { network.connect() })
  }

  function connectWithPassphrase(targetSsid, passphrase) {
    if (useIwd) {
      runIwdAction("connect", targetSsid, passphrase)
      return
    }
    runNetworkAction("connect", networkForSsid(targetSsid), function(network) { network.connectWithPsk(passphrase) })
  }

  function disconnect(network) {
    runNetworkAction("disconnect", network, function(net) { net.disconnect() })
  }

  function activateRow(row) {
    if (!row || busy) return
    if (row.backend === "iw") return
    if (row.backend === "iwd") {
      if (row.connected) runIwdAction("disconnect", row.ssid, "")
      else if (isProtected(row.security)) openPasswordPrompt(row.ssid)
      else connectKnown(row.ssid)
      return
    }
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
    if (!useNetworkManager) {
      wifiNetworks = []
      if (!iwScanProc.running) {
        scanning = true
        iwScanProc.command = useIwd ? iwdScanCommand() : iwScanCommand()
        iwScanProc.running = true
      }
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
    if (!useNetworkManager) return
    Networking.wifiEnabled = !Networking.wifiEnabled
    Qt.callLater(function() { refresh(true) })
  }

  function iwdScanCommand() {
    return [
      "bash",
      "-lc",
      "iface=${WHITEROSE_NETWORK_IFACE:-}; if [[ -z $iface ]]; then iface=$(iw dev 2>/dev/null | awk '$1 == \"Interface\" { print $2; exit }'); fi; [[ -n $iface ]] || { echo 'no wireless interface' >&2; exit 2; }; iwctl station \"$iface\" scan >/dev/null 2>&1 || true; iwctl station \"$iface\" get-networks rssi-dbms | awk '{ gsub(/\\033\\[[0-9;]*[A-Za-z]/, \"\"); line=$0; gsub(/^[[:space:]>]+|[[:space:]]+$/, \"\", line); if (line !~ /[[:space:]](open|psk|8021x|owe|sae)[[:space:]]+-?[0-9]+$/) next; signal=line; sub(/^.*[[:space:]]/, \"\", signal); security=line; sub(/[[:space:]]+-?[0-9]+$/, \"\", security); sub(/^.*[[:space:]]/, \"\", security); name=line; sub(/[[:space:]]+(open|psk|8021x|owe|sae)[[:space:]]+-?[0-9]+$/, \"\", name); if (name != \"\") print name \"\\t\" signal \"\\t\" (security == \"open\" ? 0 : 1) }'"
    ]
  }

  function iwScanCommand() {
    return [
      "bash",
      "-lc",
      "iface=${WHITEROSE_NETWORK_IFACE:-}; if [[ -z $iface ]]; then iface=$(iw dev 2>/dev/null | awk '$1 == \"Interface\" { print $2; exit }'); fi; [[ -n $iface ]] || { echo 'no wireless interface' >&2; exit 2; }; iw dev \"$iface\" scan 2>/dev/null | awk 'function emit(){ if (ssid != \"\") { print ssid \"\\t\" signal \"\\t\" protected } ssid=\"\"; signal=\"\"; protected=0 } /^BSS / { emit(); next } /^[[:space:]]*signal:/ { signal=$2 } /^[[:space:]]*SSID:/ { ssid=$0; sub(/^[[:space:]]*SSID:[[:space:]]*/, \"\", ssid) } /^[[:space:]]*(RSN:|WPA:)/ { protected=1 } /^[[:space:]]*capability:/ && /Privacy/ { protected=1 } END { emit() }'"
    ]
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
    if (wifiDevice) wifiDevice.scannerEnabled = opened && useNetworkManager
    syncWifiNetworks()
  }

  onWifiNetworkObjectsChanged: syncWifiNetworks()
  onNetworkRowsChanged: {
    if (networkRows.length === 0) cursor = -1
    else if (cursor < 0) cursor = 0
    else if (cursor >= networkRows.length) cursor = networkRows.length - 1
  }
  onUseNetworkManagerChanged: refresh(true)
  onUseIwdChanged: refresh(true)
  onPasswordSsidChanged: if (passwordSsid === "") passwordText = ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: {
    iwdCheckProc.running = true
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
            text: root.useNetworkManager ? (Networking.wifiEnabled ? "nm on" : "nm off") : root.backendLabel
            color: root.useNetworkManager && Networking.wifiEnabled ? Color.accent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2

            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              enabled: root.useNetworkManager
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.toggleWifi()
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Color.popups.text; opacity: 0.08 }

        Text {
          visible: root.networkRows.length === 0
          width: parent.width
          text: root.useNetworkManager ? (root.scanning ? "scanning..." : "no networks found")
            : (root.iwScanError || (root.scanning ? "scanning with iw..." : "no networks found by iw"))
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
              if (modelData.backend === "iw") return modelData.connected ? "connected" : "iw scan"
              if (rowBusy && root.actionKind === "connect") return "connecting"
              if (rowBusy && root.actionKind === "disconnect") return "disconnecting"
              if (rowFailed) return root.failureReason
              if (modelData.connected) return "connected"
              if (modelData.backend === "iwd") return root.isProtected(modelData.security) ? "passphrase" : "iwd"
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
                enabled: !root.busy && networkRow.modelData.backend !== "iw"
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
          text: root.useNetworkManager ? "enter toggles    r rescans    right click wifi"
            : (root.useIwd ? "enter toggles    r rescans    backend iwd" : "iw fallback is read-only    r rescans")
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

  Process {
    id: iwdCheckProc
    command: ["bash", "-lc", "command -v iwctl >/dev/null 2>&1 && iwctl station list >/dev/null 2>&1"]
    onExited: function(exitCode) { root.iwdAvailable = exitCode === 0 }
  }

  Process {
    id: iwdActionProc
    property string stderrText: ""
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: iwdActionProc.stderrText = String(text || "").trim()
    }
    onExited: function(exitCode) {
      actionTimeout.stop()
      if (exitCode === 0) {
        root.clearNetworkAction()
      } else {
        root.failureSsid = root.actionSsid
        root.failureReason = stderrText || "iwd action failed"
        root.actionSsid = ""
        root.actionKind = ""
        root.refresh(false)
      }
      stderrText = ""
    }
  }

  Timer {
    interval: 3000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: iwScanProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateIwNetworks(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.iwScanError = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.scanning = false
      if (exitCode !== 0 && root.iwScanError === "") root.iwScanError = "iw scan failed"
    }
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
