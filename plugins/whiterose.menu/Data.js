// Whiterose menu tree. One flat list; parents are inferred from dotted ids,
// mirroring the omarchy-menu.jsonc convention so entries stay portable.
//
// Fields: id, icon, label, desc, keywords, action, confirm, provider.
// An entry without an action is a submenu. Provider submenus are filled by
// Menu.qml at runtime. Icons are Nerd Font glyphs copied from the stock
// omarchy menu so they render on every install.

var TREE = [
  { id: "apps", icon: "❯", label: "Apps", desc: "app launcher", keywords: "launcher search omni run", action: "omarchy-shell shell toggle omarchy.launcher '{}'" },

  { id: "capture", icon: "", label: "Capture", desc: "", keywords: "screenshot record ocr color" },
  { id: "capture.screenshot", icon: "", label: "Screenshot", desc: "", keywords: "picture region", action: "omarchy-capture-screenshot" },
  { id: "capture.record", icon: "", label: "Screenrecord", desc: "", keywords: "video", action: "omarchy-capture-screenrecording" },
  { id: "capture.record-audio", icon: "", label: "Screenrecord with audio", desc: "desktop + microphone", keywords: "video mic", action: "omarchy-capture-screenrecording --with-desktop-audio --with-microphone-audio" },
  { id: "capture.stop", icon: "", label: "Stop recording", desc: "", keywords: "video stop", action: "omarchy-capture-screenrecording --stop-recording" },
  { id: "capture.text", icon: "\u{f0d11}", label: "Extract text", desc: "OCR from screen region", keywords: "ocr grab", action: "omarchy-capture-text-extraction" },
  { id: "capture.color", icon: "\u{f00c9}", label: "Pick color", desc: "", keywords: "picker hyprpicker", action: "pkill hyprpicker || hyprpicker -a" },

  { id: "style", icon: "", label: "Style", desc: "", keywords: "theme background colors" },
  { id: "style.theme", icon: "\u{f0e0c}", label: "Theme switcher", desc: "preview and apply", keywords: "colors switch", action: "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\"" },
  { id: "style.themes", icon: "\u{f0e0c}", label: "Themes", desc: "choose installed theme", keywords: "colors switch palette", provider: "themes" },
  { id: "style.background", icon: "", label: "Next background", desc: "", keywords: "wallpaper", action: "omarchy-theme-bg-next" },

  { id: "toggle", icon: "\u{f050e}", label: "Toggle", desc: "", keywords: "switch" },
  { id: "toggle.nightlight", icon: "\u{f050e}", label: "Nightlight", desc: "", keywords: "hyprsunset warm", action: "omarchy-toggle-nightlight" },
  { id: "toggle.idle", icon: "\u{f1ad6}", label: "Idle lock", desc: "", keywords: "screensaver caffeine stay awake", action: "omarchy-toggle-idle" },
  { id: "toggle.lightmode", icon: "\u{f05a8}", label: "Light mode", desc: "swap light/dark theme twin", keywords: "dark light mode theme paper invert", action: "t=$(cat \"$HOME/.local/state/omarchy/current/theme.name\" 2>/dev/null); [ -n \"$t\" ] || exit 0; case $t in catppuccin) n=catppuccin-latte ;; catppuccin-latte) n=catppuccin ;; *-light) n=${t%-light} ;; *) n=$t-light ;; esac; if [ -d \"$HOME/.config/omarchy/themes/$n\" ] || [ -d \"${OMARCHY_PATH:-$HOME/.local/share/omarchy}/themes/$n\" ]; then omarchy-theme-set \"$n\"; else notify-send \"Whiterose\" \"No $n theme installed\"; fi" },
  { id: "toggle.bar", icon: "\u{f035c}", label: "Bar", desc: "show or hide the bar", keywords: "hide show", action: "omarchy-toggle-bar" },

  { id: "system", icon: "", label: "System", desc: "", keywords: "power lock logout restart shutdown" },
  { id: "system.lock", icon: "", label: "Lock", desc: "", keywords: "screen", action: "whiterose-lock" },
  { id: "system.suspend", icon: "\u{f04b2}", label: "Suspend", desc: "", keywords: "sleep", action: "systemctl suspend" },
  { id: "system.power-profile", icon: "\u{f0c0b}", label: "Power profile", desc: "performance mode", keywords: "battery balanced performance saver", provider: "power-profiles" },
  { id: "system.update", icon: "", label: "Update", desc: "run omarchy update", keywords: "upgrade packages", action: "omarchy-launch-floating-terminal-with-presentation omarchy-update" },
  { id: "system.relaunch", icon: "\u{f0709}", label: "Relaunch shell", desc: "restart bar and menus", keywords: "quickshell reload", action: "omarchy-restart-shell" },
  { id: "system.logout", icon: "\u{f0343}", label: "Logout", desc: "", keywords: "sign out exit", action: "omarchy-system-logout", confirm: true },
  { id: "system.restart", icon: "\u{f0709}", label: "Restart", desc: "", keywords: "reboot", action: "omarchy-system-reboot", confirm: true },
  { id: "system.shutdown", icon: "\u{f0425}", label: "Shutdown", desc: "", keywords: "power off halt", action: "omarchy-system-shutdown", confirm: true }
]

var DYNAMIC = {}

// Route aliases accepted in the summon payload.
var ALIASES = { root: "", power: "system" }

function parentOf(id) {
  var dot = id.lastIndexOf(".")
  return dot === -1 ? "" : id.slice(0, dot)
}

function allNodes() {
  var nodes = TREE.slice()
  for (var parentId in DYNAMIC) {
    var rows = DYNAMIC[parentId] || []
    for (var i = 0; i < rows.length; i++) nodes.push(rows[i])
  }
  return nodes
}

function nodeById(id) {
  var nodes = allNodes()
  for (var i = 0; i < nodes.length; i++) {
    if (nodes[i].id === id) return nodes[i]
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
  var node = nodeById(id)
  if (node && node.provider) return true
  var nodes = allNodes()
  for (var i = 0; i < nodes.length; i++) {
    if (parentOf(nodes[i].id) === id) return true
  }
  return false
}

function providerFor(id) {
  var node = nodeById(id)
  return node && node.provider ? node.provider : ""
}

function providerRoutes() {
  var routes = []
  for (var i = 0; i < TREE.length; i++) {
    if (TREE[i].provider) routes.push(TREE[i].id)
  }
  return routes
}

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "item"
}

function setDynamicRows(parentId, rows) {
  var next = []
  var seen = {}
  for (var i = 0; i < rows.length; i++) {
    var input = rows[i] || {}
    var slug = slugify(input.value || input.label || i)
    var id = parentId + "." + slug
    var n = 2
    while (seen[id]) id = parentId + "." + slug + "-" + (n++)
    seen[id] = true
    next.push({
      id: id,
      icon: input.icon || "",
      label: input.label || input.value || "",
      desc: input.desc || "",
      keywords: input.keywords || "",
      action: input.action || "",
      confirm: input.confirm === true
    })
  }
  DYNAMIC[parentId] = next
}

// Rows for one submenu level.
function childrenOf(route) {
  var rows = []
  var nodes = allNodes()
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i]
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
  var nodes = allNodes()
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i]
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
    provider: node.provider || "",
    submenu: !node.action && hasChildren(node.id)
  }
}
