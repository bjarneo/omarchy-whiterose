import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Output volume. Wheel adjusts, right click mutes, left click opens a
// compact PipeWire popout with sink selection and microphone mute.
Panel {
  id: root
  moduleName: "whiterose.audio"
  // Same IPC surface as the stock panels: `omarchy-shell whiterose.audio
  // toggle`. After heavy plugin rescans the old instance's handler can
  // linger; omarchy-restart-shell clears it.
  ipcTarget: "whiterose.audio"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var candidateSinks: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (node && node.isSink && !node.isStream) list.push(node)
    }
    return list
  }
  readonly property var sinks: {
    var list = candidateSinks.slice()
    if (sink && list.indexOf(sink) < 0) list.unshift(sink)
    return list
  }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  readonly property bool inputMuted: source && source.audio ? source.audio.muted : true
  readonly property int rowCount: 1 + (source ? 1 : 0) + displaySinks.length

  property var displaySinks: []
  property int cursor: 0

  readonly property string glyph: muted ? "\u{f075f}"
    : (volume < 0.01 ? "" : (volume < 0.5 ? "" : "\u{f057e}"))

  function setVolume(value) {
    if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, value))
  }

  function toggleMute() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
  }

  function toggleMicMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  function setDefaultSink(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    if (root.bar && node.id !== undefined && node.name) {
      Quickshell.execDetached([
        root.bar.omarchyPath + "/bin/omarchy-audio-output-set-default",
        String(node.id),
        String(node.name)
      ])
    }
  }

  function sinkCursorOffset() {
    return source ? 2 : 1
  }

  function sinkForCursor() {
    var index = cursor - sinkCursorOffset()
    return index >= 0 && index < displaySinks.length ? displaySinks[index] : null
  }

  function activateCursor() {
    if (cursor === 0) {
      toggleMute()
      return
    }
    if (source && cursor === 1) {
      toggleMicMute()
      return
    }
    setDefaultSink(sinkForCursor())
  }

  function moveCursor(delta) {
    if (rowCount <= 0) return
    cursor = Math.max(0, Math.min(rowCount - 1, cursor + delta))
  }

  function clampCursor() {
    cursor = Math.max(0, Math.min(Math.max(0, rowCount - 1), cursor))
  }

  function refreshDisplaySinks() {
    if (!opened) return
    displaySinks = sinks.slice()
    clampCursor()
  }

  function friendlyDeviceLabel(text) {
    var label = String(text || "").trim()
    label = label.replace(/^sof-soundwire\s+/i, "")
    label = label.replace(/^built-?in audio\s+/i, "")
    label = label.replace(/\s+Output$/i, "")
    return label
  }

  function nodeProps(node) {
    return node && node.ready && node.properties ? node.properties : {}
  }

  function nodeLabel(node) {
    if (!node) return "Unknown"
    var props = nodeProps(node)
    var label = node.nickname || node.nick || props["node.nick"]
      || node.description || props["node.description"] || node.name || "Unknown"
    return friendlyDeviceLabel(label)
  }

  function isActiveSink(node) {
    return sink && node && sink.id === node.id
  }

  function sinkGlyph(node) {
    if (!node) return "\u{f04a8}"
    var props = nodeProps(node)
    var blob = String([
      node.name, node.description, node.nickname,
      props["device.icon-name"] || "",
      props["device.product.name"] || "",
      props["node.description"] || "",
      props["node.nick"] || ""
    ].join(" ")).toLowerCase()
    if (blob.indexOf("headphone") !== -1 || blob.indexOf("headset") !== -1
        || blob.indexOf("earbud") !== -1 || blob.indexOf("earphone") !== -1) return "\u{f02cb}"
    if (blob.indexOf("bluetooth") !== -1) return "\u{f00af}"
    if (blob.indexOf("hdmi") !== -1 || blob.indexOf("display") !== -1) return "\u{f0379}"
    return "\u{f04a8}"
  }

  onOpenedChanged: {
    if (opened) {
      cursor = 0
      refreshDisplaySinks()
    } else {
      displaySinks = []
    }
  }

  onSinksChanged: if (opened) sinkRefresh.restart()
  onRowCountChanged: clampCursor()

  readonly property var trackedNodes: {
    var list = []
    if (sink) list.push(sink)
    if (source && list.indexOf(source) < 0) list.push(source)
    for (var i = 0; i < displaySinks.length; i++) {
      if (displaySinks[i] && list.indexOf(displaySinks[i]) < 0) list.push(displaySinks[i])
    }
    return list
  }

  PwObjectTracker { objects: root.trackedNodes }

  Timer {
    id: sinkRefresh
    interval: 75
    repeat: false
    onTriggered: root.refreshDisplaySinks()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    dimmed: root.muted
    tooltipText: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton || mouseButton === Qt.MiddleButton) root.toggleMute()
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      root.setVolume(root.volume + (delta > 0 ? 0.05 : -0.05))
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
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0 && root.cursor === 0) root.setVolume(root.volume + dx * 0.05)
      }
      onActivateRequested: root.activateCursor()

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.panelGap

        Item {
          width: parent.width
          height: Style.space(20)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "volume"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
            color: root.muted ? Color.muted : Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        // Hairline slider: 2px track, accent fill, generous hit area.
        Item {
          id: slider
          width: parent.width
          height: Style.space(24)

          Rectangle {
            anchors.fill: parent
            radius: Math.min(Style.cornerRadius, Style.space(5))
            color: Color.popups.text
            opacity: root.cursor === 0 ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.spaceReal(2)
            radius: height / 2
            color: Color.popups.text
            opacity: 0.15
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.volume
            height: Style.spaceReal(2)
            radius: height / 2
            color: root.muted ? Color.muted : Color.accent

            Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
          }

          Rectangle {
            x: parent.width * root.volume - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            color: root.muted ? Color.muted : Color.accent
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) {
              root.cursor = 0
              root.setVolume(mouse.x / width)
            }
            onPositionChanged: function(mouse) {
              if (pressed) root.setVolume(Math.max(0, Math.min(1, mouse.x / width)))
            }
          }
        }

        Item {
          id: micRow
          visible: root.source !== null
          width: parent.width
          height: visible ? Style.space(30) : 0

          Rectangle {
            anchors.fill: parent
            radius: Math.min(Style.cornerRadius, Style.space(5))
            color: Color.popups.text
            opacity: root.cursor === 1 ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          }

          Text {
            id: micIcon
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.inputMuted ? "\u{f036d}" : "\u{f036c}"
            color: root.inputMuted ? Color.muted : Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            anchors.left: micIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: micState.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: "microphone"
            color: Color.popups.text
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            id: micState
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.inputMuted ? "muted" : "live"
            color: root.inputMuted ? Color.muted : Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) root.cursor = 1
            onClicked: root.toggleMicMute()
          }
        }

        Rectangle {
          visible: root.displaySinks.length > 0
          width: parent.width
          height: 1
          color: Color.popups.text
          opacity: 0.08
        }

        Repeater {
          model: root.displaySinks

          Item {
            id: sinkRow
            required property var modelData
            required property int index

            readonly property int rowCursor: root.sinkCursorOffset() + index
            readonly property bool selected: root.cursor === rowCursor
            readonly property bool activeSink: root.isActiveSink(modelData)

            width: content.width
            height: Style.space(30)

            Rectangle {
              anchors.fill: parent
              radius: Math.min(Style.cornerRadius, Style.space(5))
              color: Color.popups.text
              opacity: sinkRow.selected ? 0.08 : 0
              Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Text {
              id: sinkIcon
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.sinkGlyph(sinkRow.modelData)
              color: sinkRow.activeSink ? Color.accent : Color.popups.text
              opacity: sinkRow.activeSink ? 1 : 0.72
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.left: sinkIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: sinkState.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.nodeLabel(sinkRow.modelData)
              color: Color.popups.text
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: sinkRow.activeSink
            }

            Text {
              id: sinkState
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: sinkRow.activeSink ? "default" : ""
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.cursor = sinkRow.rowCursor
              onClicked: root.setDefaultSink(sinkRow.modelData)
            }
          }
        }

        Text {
          width: parent.width
          text: "left/right volume    enter toggles/selects"
          color: Color.muted
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
