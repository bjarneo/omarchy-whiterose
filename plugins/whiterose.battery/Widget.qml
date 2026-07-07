import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// Battery percentage with the stock glyph ladders. Urgent tint when
// discharging below the warn threshold. Absent battery, absent widget.
BarWidget {
  id: root
  moduleName: "whiterose.battery"

  readonly property var device: UPower.displayDevice
  readonly property bool present: device !== null && device.isPresent
  readonly property int percent: present ? Math.round(Number(device.percentage || 0) * 100) : 0
  readonly property bool discharging: present && UPower.onBattery && device.state === UPowerDeviceState.Discharging
  readonly property bool low: discharging && percent <= Number(setting("warnAt", 15))

  readonly property string glyph: {
    if (!present) return ""
    var discharge = ["\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}", "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}"]
    var charge = ["\u{f089c}", "\u{f0086}", "\u{f0087}", "\u{f0088}", "\u{f089d}", "\u{f0089}", "\u{f089e}", "\u{f008a}", "\u{f008b}", "\u{f0085}"]
    var index = Math.max(0, Math.min(9, Math.floor(percent / 10)))
    return discharging ? discharge[index] : charge[index]
  }

  visible: present
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph + " " + root.percent + "%"
    active: root.low
    tooltipText: root.discharging ? "Discharging" : "On power"
    onPressed: function() {
      if (root.bar) root.bar.run("omarchy-shell shell toggle whiterose.menu '{\"menu\":\"system\"}'")
    }
  }
}
