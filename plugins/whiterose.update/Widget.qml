import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Invisible until omarchy-update-available exits zero; then a single
// urgent-tinted glyph. Click launches the update in a floating terminal.
BarWidget {
  id: root
  moduleName: "whiterose.update"

  property bool updateAvailable: false
  property string updateLine: ""
  property int recheckRemaining: 0

  visible: updateAvailable
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    active: true
    tooltipText: root.updateLine || "Update available"
    onPressed: function() {
      if (!root.bar) return
      root.bar.run("omarchy-launch-floating-terminal-with-presentation omarchy-update")
      // Poll for a while after launching the update so the glyph clears
      // shortly after it finishes instead of lingering until the hourly check.
      root.recheckRemaining = 15
      recheckTimer.restart()
    }
  }

  Process {
    id: checkProc
    command: ["omarchy-update-available"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateLine = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.updateAvailable = exitCode === 0
      if (!root.updateAvailable) recheckTimer.stop()
    }
  }

  Timer {
    interval: 3600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!checkProc.running) checkProc.running = true
  }

  Timer {
    id: recheckTimer
    interval: 120000
    repeat: true
    onTriggered: {
      if (root.recheckRemaining <= 0) {
        stop()
        return
      }
      root.recheckRemaining--
      if (!checkProc.running) checkProc.running = true
    }
  }
}
