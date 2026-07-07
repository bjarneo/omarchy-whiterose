import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Connection state from `omarchy-network-status --verbose` (key/value
// lines read straight from the kernel via ip/iw). The non-verbose mode
// trusts nmcli, which reports "disconnected" on iwd-managed interfaces;
// verbose does not have that blind spot.
BarWidget {
  id: root
  moduleName: "whiterose.network"

  property string iface: ""
  property string kind: ""
  property string ssid: ""
  property string ip: ""
  property int signalPercent: -1

  readonly property bool connected: iface !== ""

  readonly property string glyph: {
    if (!connected) return "\u{f092e}"
    if (kind !== "wifi") return "\u{f0200}"
    var icons = ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]
    if (signalPercent < 0) return icons[4]
    var index = Math.max(0, Math.min(4, Math.ceil(signalPercent / 20) - 1))
    return icons[index]
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
    // dBm to a rough quality percentage: -50 dBm is full, -100 dBm is gone.
    var dbm = parseFloat(fields.signal_dbm)
    signalPercent = isNaN(dbm) ? -1 : Math.max(0, Math.min(100, Math.round(2 * (dbm + 100))))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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
    onPressed: function() {
      if (root.bar) root.bar.run(String(root.setting("onClick", "omarchy-launch-floating-terminal-with-presentation nmtui")))
    }
  }

  Process {
    id: statusProc
    command: ["omarchy-network-status", "--verbose"]
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
}
