import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspaces as thin dashes. The focused workspace widens and takes the
// accent color; occupied workspaces sit at full strength; empty ones fade.
BarWidget {
  id: root
  moduleName: "whiterose.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  Grid {
    id: layout
    anchors.fill: parent
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(2)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: cell

        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: " "
        keepSpace: true
        tooltipText: "Workspace " + modelData
        horizontalMargin: 0
        verticalPadding: 0
        fixedWidth: root.vertical ? root.barSize : Style.space(22)
        fixedHeight: root.vertical ? Style.space(22) : root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        Rectangle {
          id: dash

          property real glitchX: 0
          property real glitchDim: 1
          property real baseOpacity: cell.focused ? 1 : (cell.occupied ? 0.65 : 0.22)

          anchors.centerIn: parent
          width: root.vertical ? Style.spaceReal(2) : (cell.focused ? Style.space(14) : Style.space(8))
          height: root.vertical ? (cell.focused ? Style.space(14) : Style.space(8)) : Style.spaceReal(2)
          radius: Style.spaceReal(1)
          color: cell.focused ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
          opacity: baseOpacity * glitchDim
          transform: Translate { x: dash.glitchX }

          Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 160 } }
          Behavior on baseOpacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

          // One quick jitter per hover entry: two offsets and an opacity
          // dip, then settle. Disable with a `glitch: false` setting.
          SequentialAnimation {
            id: glitch
            ParallelAnimation {
              NumberAnimation { target: dash; property: "glitchX"; to: Style.spaceReal(1.5); duration: 35 }
              NumberAnimation { target: dash; property: "glitchDim"; to: 0.5; duration: 35 }
            }
            NumberAnimation { target: dash; property: "glitchX"; to: -Style.spaceReal(1.2); duration: 35 }
            ParallelAnimation {
              NumberAnimation { target: dash; property: "glitchX"; to: 0; duration: 60; easing.type: Easing.OutCubic }
              NumberAnimation { target: dash; property: "glitchDim"; to: 1; duration: 60; easing.type: Easing.OutCubic }
            }
          }

          Connections {
            target: cell
            function onTooltipHoveredChanged() {
              if (cell.tooltipHovered && root.setting("glitch", true) === true) glitch.restart()
            }
          }
        }
      }
    }
  }
}
