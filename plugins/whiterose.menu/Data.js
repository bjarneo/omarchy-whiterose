// Whiterose menu tree. One flat list; parents are inferred from dotted ids,
// mirroring the omarchy-menu.jsonc convention so entries stay portable.
//
// Fields: id, icon, label, desc, keywords, action, confirm.
// An entry without an action is a submenu. Icons are Nerd Font glyphs
// copied from the stock omarchy menu so they render on every install.

var TREE = [
  { id: "apps", icon: "❯", label: "Apps", desc: "omni command palette", keywords: "launcher search omni run", action: "omarchy-shell shell toggle omni '{}'" },

  { id: "capture", icon: "", label: "Capture", desc: "", keywords: "screenshot record ocr color" },
  { id: "capture.screenshot", icon: "", label: "Screenshot", desc: "", keywords: "picture region", action: "omarchy-capture-screenshot" },
  { id: "capture.record", icon: "", label: "Screenrecord", desc: "", keywords: "video", action: "omarchy-capture-screenrecording" },
  { id: "capture.record-audio", icon: "", label: "Screenrecord with audio", desc: "desktop + microphone", keywords: "video mic", action: "omarchy-capture-screenrecording --with-desktop-audio --with-microphone-audio" },
  { id: "capture.stop", icon: "", label: "Stop recording", desc: "", keywords: "video stop", action: "omarchy-capture-screenrecording --stop-recording" },
  { id: "capture.text", icon: "\u{f0d11}", label: "Extract text", desc: "OCR from screen region", keywords: "ocr grab", action: "omarchy-capture-text-extraction" },
  { id: "capture.color", icon: "\u{f00c9}", label: "Pick color", desc: "", keywords: "picker hyprpicker", action: "pkill hyprpicker || hyprpicker -a" },

  { id: "style", icon: "", label: "Style", desc: "", keywords: "theme background colors" },
  { id: "style.theme", icon: "\u{f0e0c}", label: "Next theme", desc: "cycle installed themes", keywords: "colors switch", action: "omarchy-theme-next" },
  { id: "style.background", icon: "", label: "Next background", desc: "", keywords: "wallpaper", action: "omarchy-theme-bg-next" },

  { id: "toggle", icon: "\u{f050e}", label: "Toggle", desc: "", keywords: "switch" },
  { id: "toggle.nightlight", icon: "\u{f050e}", label: "Nightlight", desc: "", keywords: "hyprsunset warm", action: "omarchy-toggle-nightlight" },
  { id: "toggle.idle", icon: "\u{f1ad6}", label: "Idle lock", desc: "", keywords: "screensaver caffeine stay awake", action: "omarchy-toggle-idle" },
  { id: "toggle.bar", icon: "\u{f035c}", label: "Bar", desc: "show or hide the bar", keywords: "hide show", action: "omarchy-toggle-bar" },

  { id: "system", icon: "", label: "System", desc: "", keywords: "power lock logout restart shutdown" },
  { id: "system.lock", icon: "", label: "Lock", desc: "", keywords: "screen", action: "omarchy-system-lock" },
  { id: "system.suspend", icon: "\u{f04b2}", label: "Suspend", desc: "", keywords: "sleep", action: "systemctl suspend" },
  { id: "system.update", icon: "", label: "Update", desc: "run omarchy update", keywords: "upgrade packages", action: "omarchy-launch-floating-terminal-with-presentation omarchy-update" },
  { id: "system.relaunch", icon: "\u{f0709}", label: "Relaunch shell", desc: "restart bar and menus", keywords: "quickshell reload", action: "omarchy-restart-shell" },
  { id: "system.logout", icon: "\u{f0343}", label: "Logout", desc: "", keywords: "sign out exit", action: "omarchy-system-logout", confirm: true },
  { id: "system.restart", icon: "\u{f0709}", label: "Restart", desc: "", keywords: "reboot", action: "omarchy-system-reboot", confirm: true },
  { id: "system.shutdown", icon: "\u{f0425}", label: "Shutdown", desc: "", keywords: "power off halt", action: "omarchy-system-shutdown", confirm: true }
]

// Route aliases accepted in the summon payload.
var ALIASES = { root: "", power: "system" }

function parentOf(id) {
  var dot = id.lastIndexOf(".")
  return dot === -1 ? "" : id.slice(0, dot)
}

function nodeById(id) {
  for (var i = 0; i < TREE.length; i++) {
    if (TREE[i].id === id) return TREE[i]
  }
  return null
}

function normalizeRoute(route) {
  var r = String(route || "").trim()
  if (r in ALIASES) r = ALIASES[r]
  if (r && !nodeById(r)) r = ""
  return r
}

function hasChildren(id) {
  for (var i = 0; i < TREE.length; i++) {
    if (parentOf(TREE[i].id) === id) return true
  }
  return false
}

// Rows for one submenu level.
function childrenOf(route) {
  var rows = []
  for (var i = 0; i < TREE.length; i++) {
    var node = TREE[i]
    if (parentOf(node.id) !== route) continue
    rows.push(rowFor(node))
  }
  return rows
}

// Subsequence match: every needle character must appear in order.
// Lower scores are better; -1 means no match. Gaps between matched
// characters cost, so "slock" prefers "system lock" over scattered hits.
function fuzzyScore(needle, haystack) {
  var score = 0
  var pos = 0
  for (var i = 0; i < needle.length; i++) {
    var found = haystack.indexOf(needle[i], pos)
    if (found === -1) return -1
    score += found - pos
    pos = found + 1
  }
  return score + haystack.length * 0.01
}

// Filtered rows across the whole tree (actions and submenus),
// best matches first. Label matches rank above keyword/path matches.
function search(filter) {
  var needle = String(filter || "").toLowerCase().replace(/\s+/g, "")
  var scored = []
  for (var i = 0; i < TREE.length; i++) {
    var node = TREE[i]
    var label = node.label.toLowerCase()
    var haystack = (node.id + " " + node.label + " " + (node.keywords || "") + " " + (node.desc || "")).toLowerCase()
    var score = fuzzyScore(needle, label)
    if (score !== -1) score -= 1000
    else score = fuzzyScore(needle, haystack)
    if (score === -1) continue
    var row = rowFor(node)
    // Show the path so identical labels stay distinguishable while filtering.
    row.desc = node.id.indexOf(".") === -1 ? row.desc : "/" + node.id.split(".").join("/")
    scored.push({ score: score, row: row })
  }
  scored.sort(function(a, b) { return a.score - b.score })
  return scored.map(function(entry) { return entry.row })
}

function rowFor(node) {
  return {
    id: node.id,
    icon: node.icon || "",
    label: node.label,
    desc: node.desc || "",
    action: node.action || "",
    confirm: node.confirm === true,
    submenu: !node.action && hasChildren(node.id)
  }
}
