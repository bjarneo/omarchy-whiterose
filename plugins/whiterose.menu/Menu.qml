import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Data.js" as Data

// Whiterose system menu. Summoned via:
//   omarchy-shell shell toggle whiterose.menu '{"menu":"root"}'
// Routes: root, capture, style, toggle, system (alias: power).
Item {
  id: root

  // Injected by the shell host when the property exists.
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "whiterose.menu"

  property bool opened: false
  property string route: ""
  property int cursor: 0
  property int armed: -1
  property var rows: []
  property var providerLoaded: ({})
  property var providerQueue: []

  readonly property var providers: ({
    "themes": {
      script: "current=$(omarchy-theme-current 2>/dev/null); omarchy-theme-list 2>/dev/null | while IFS= read -r t; do [[ -z $t ]] && continue; printf '%s\\t%s\\t%s\\n' \"$t\" \"$t\" \"$current\"; done",
      icon: "\u{f0e0c}",
      desc: "apply theme",
      currentDesc: "current theme",
      actionFor: function(value) { return "omarchy-theme-set " + root.shellQuote(value) },
      keywordsFor: function(value) { return value + " theme colors palette" }
    },
    "power-profiles": {
      script: "omarchy-powerprofiles-list --active-state 2>/dev/null | while IFS=$'\\t' read -r p active; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$active\"; done",
      icon: "\u{f0c0b}",
      desc: "set profile",
      currentDesc: "current profile",
      actionFor: function(value) { return "powerprofilesctl set " + root.shellQuote(value) },
      keywordsFor: function(value) { return value + " power battery performance balanced saver" }
    }
  })

  function rebuild() {
    rows = filterField.text.length > 0 ? Data.search(filterField.text) : Data.childrenOf(route)
    if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)
    armed = -1
    if (filterField.text.length > 0) loadProvidersForSearch()
    else loadProviderForRoute(route)
  }

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) {}
    route = Data.normalizeRoute(payload.menu || payload.initialMenu || "")
    filterField.text = ""
    cursor = 0
    armed = -1
    providerLoaded = ({})
    providerQueue = []
    rebuild()
    opened = true
    Qt.callLater(function() { filterField.forceActiveFocus() })
  }

  function close() { opened = false }

  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }

  function toggle(payloadJson) {
    if (opened) dismiss()
    else open(payloadJson || "{}")
  }

  function launch(command) {
    if (!command) return
    var bin = omarchyPath ? omarchyPath + "/bin/omarchy-hyprland-launch" : "omarchy-hyprland-launch"
    Quickshell.execDetached([bin, command])
  }

  function shellQuote(value) {
    return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
  }

  function markProviderLoaded(id) {
    var next = ({})
    for (var key in providerLoaded) next[key] = providerLoaded[key]
    next[id] = true
    providerLoaded = next
  }

  function startProviderForRoute(id) {
    var providerKey = Data.providerFor(id)
    var spec = providers[providerKey]
    if (!spec) return
    markProviderLoaded(id)
    providerProc.parentId = id
    providerProc.providerKey = providerKey
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function startNextProvider() {
    if (providerProc.running) return
    while (providerQueue.length > 0) {
      var id = providerQueue[0]
      providerQueue = providerQueue.slice(1)
      if (providerLoaded[id]) continue
      startProviderForRoute(id)
      return
    }
  }

  function loadProviderForRoute(id) {
    if (!id || providerLoaded[id] || !Data.providerFor(id)) return
    if (providerProc.running) {
      if (providerQueue.indexOf(id) === -1) providerQueue = providerQueue.concat([id])
      return
    }
    startProviderForRoute(id)
  }

  function loadProvidersForSearch() {
    var routes = Data.providerRoutes()
    for (var i = 0; i < routes.length; i++) loadProviderForRoute(routes[i])
  }

  function mergeProviderRows(parentId, providerKey, raw) {
    var spec = providers[providerKey]
    if (!spec) return
    var rows = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (!line) continue
      var parts = line.split("\t")
      var label = parts[0] || ""
      var value = parts[1] || label
      var current = parts[2] || ""
      if (!label || !value) continue
      var isCurrent = current === "1" || value === current || label === current
      rows.push({
        icon: isCurrent ? "✓" : spec.icon,
        label: label,
        desc: isCurrent ? spec.currentDesc : spec.desc,
        keywords: spec.keywordsFor(value),
        action: spec.actionFor(value)
      })
    }
    Data.setDynamicRows(parentId, rows)
    if (opened) rebuild()
  }

  function descend(row) {
    filterField.text = ""
    route = row.id
    cursor = 0
    rebuild()
  }

  function back() {
    if (route === "") {
      dismiss()
      return
    }
    var dot = route.lastIndexOf(".")
    route = dot === -1 ? "" : route.slice(0, dot)
    cursor = 0
    rebuild()
  }

  function activate(index) {
    if (index < 0 || index >= rows.length) return
    var row = rows[index]
    if (row.submenu) {
      descend(row)
      return
    }
    if (!row.action) return
    // Destructive rows require a second Enter within three seconds.
    if (row.confirm && armed !== index) {
      armed = index
      disarmTimer.restart()
      return
    }
    dismiss()
    launch(row.action)
  }

  function moveCursor(delta) {
    if (rows.length === 0) return
    cursor = (cursor + delta + rows.length) % rows.length
    armed = -1
    list.positionViewAtIndex(cursor, ListView.Contain)
  }

  Timer {
    id: disarmTimer
    interval: 3000
    onTriggered: root.armed = -1
  }

  Process {
    id: providerProc
    property string parentId: ""
    property string providerKey: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.mergeProviderRows(providerProc.parentId, providerProc.providerKey, text)
    }
    onExited: {
      parentId = ""
      providerKey = ""
      root.startNextProvider()
    }
  }

  IpcHandler {
    target: "whiterose.menu"
    function toggle(): void { root.toggle("{}") }
    function open(): void { root.open("{}") }
    function close(): void { root.dismiss() }
  }

  PanelWindow {
    id: window

    visible: root.opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "whiterose-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
      opacity: root.opened ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card

      readonly property int maxListHeight: Style.space(400)

      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.opened ? 0 : Style.space(8)
      width: Math.min(Style.space(560), parent.width - Style.space(48))
      implicitHeight: column.implicitHeight
      height: implicitHeight
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, 1)
      radius: Style.cornerRadius
      opacity: root.opened ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      // Swallow clicks so the scrim MouseArea does not dismiss.
      MouseArea { anchors.fill: parent }

      Column {
        id: column
        width: parent.width

        // Prompt row.
        Item {
          width: parent.width
          height: Style.space(46)

          Text {
            id: prompt
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.panelPadding
            anchors.verticalCenter: parent.verticalCenter
            text: "❯"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
          }

          TextInput {
            id: filterField
            anchors.left: prompt.right
            anchors.leftMargin: Style.space(8)
            anchors.right: crumb.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            color: Color.menu.text
            selectionColor: Color.accent
            selectedTextColor: Color.menu.background
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            clip: true
            onTextChanged: {
              root.cursor = 0
              root.rebuild()
            }

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                if (filterField.text.length > 0) filterField.text = ""
                else root.dismiss()
                event.accepted = true
              } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                root.moveCursor(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.moveCursor(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_PageDown) {
                root.moveCursor(5)
                event.accepted = true
              } else if (event.key === Qt.Key_PageUp) {
                root.moveCursor(-5)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.cursor)
                event.accepted = true
              } else if (event.key === Qt.Key_Right && filterField.cursorPosition === filterField.text.length) {
                var row = root.rows[root.cursor]
                if (row && row.submenu) {
                  root.descend(row)
                  event.accepted = true
                }
              } else if (event.key === Qt.Key_Backspace && filterField.text.length === 0) {
                root.back()
                event.accepted = true
              } else if (event.key === Qt.Key_Left && filterField.text.length === 0) {
                root.back()
                event.accepted = true
              }
            }

            Text {
              anchors.fill: parent
              visible: filterField.text.length === 0
              text: "type to filter"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              verticalAlignment: Text.AlignVCenter
            }
          }

          Text {
            id: crumb
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.panelPadding
            anchors.verticalCenter: parent.verticalCenter
            text: root.route === "" ? "/" : "/" + root.route.split(".").join("/")
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Color.menu.text
          opacity: 0.08
        }

        ListView {
          id: list
          width: parent.width
          height: Math.min(contentHeight, card.maxListHeight)
          clip: true
          model: root.rows
          interactive: contentHeight > height
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            id: rowItem

            required property var modelData
            required property int index

            readonly property bool selected: index === root.cursor
            readonly property bool armedRow: index === root.armed

            width: list.width
            height: Style.space(38)

            Rectangle {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              radius: Math.min(Style.cornerRadius, Style.space(6))
              color: Color.menu.selectedBackground
              opacity: rowItem.selected ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(2)
              height: parent.height - Style.space(14)
              radius: width / 2
              color: rowItem.armedRow ? Color.urgent : Color.accent
              opacity: rowItem.selected ? 0.9 : 0
              Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Text {
              id: rowIcon
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.panelPadding + Style.space(2)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(22)
              text: rowItem.modelData.icon
              color: rowItem.armedRow ? Color.urgent : (rowItem.selected ? Color.menu.selectedText : Color.muted)
              font.family: Style.font.family
              font.pixelSize: Style.font.icon
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              id: rowLabel
              anchors.left: rowIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: rowItem.modelData.label
              color: rowItem.selected ? Color.menu.selectedText : Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.left: rowLabel.right
              anchors.leftMargin: Style.space(10)
              anchors.right: rowMark.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: rowItem.armedRow ? "enter again to confirm" : rowItem.modelData.desc
              color: rowItem.armedRow ? Color.urgent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignRight
            }

            Text {
              id: rowMark
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.panelPadding
              anchors.verticalCenter: parent.verticalCenter
              text: rowItem.modelData.submenu ? "›" : ""
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.cursor = rowItem.index
              onClicked: root.activate(rowItem.index)
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Color.menu.text
          opacity: 0.08
        }

        // Hint row.
        Item {
          width: parent.width
          height: Style.space(30)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.panelPadding
            anchors.verticalCenter: parent.verticalCenter
            text: "esc close    bksp back    enter run"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.panelPadding
            anchors.verticalCenter: parent.verticalCenter
            text: "whiterose"
            color: Color.muted
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }
        }
      }
    }
  }
}
