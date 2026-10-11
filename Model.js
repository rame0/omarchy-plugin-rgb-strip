.pragma library

var Glyph = {
  on: String.fromCodePoint(0xF06E8),      // nf-md-lightbulb_on
  off: String.fromCodePoint(0xF0336),     // nf-md-lightbulb_outline
  devices: String.fromCodePoint(0xF0493), // nf-md-cog
  back: String.fromCodePoint(0xF004D),    // nf-md-arrow_left
  scan: String.fromCodePoint(0xF0450),    // nf-md-refresh
  remove: String.fromCodePoint(0xF0A7A),  // nf-md-trash_can_outline
  add: String.fromCodePoint(0xF0415)      // nf-md-plus
}

var PRESETS = [
  "#ff0000", "#ff6000", "#ffc000", "#00ff00", "#00ffc0",
  "#00a0ff", "#0000ff", "#8000ff", "#ff00c0", "#ffffff"
]

var ORDERS = ["rgb", "rbg", "grb", "gbr", "brg", "bgr"]

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v))
}

function isHex(text) {
  return /^#?[0-9a-fA-F]{6}$/.test(String(text).trim())
}

function normHex(text) {
  var t = String(text).trim().toLowerCase()
  return t.charAt(0) === "#" ? t : "#" + t
}

// h in [0, 360), s and v in [0, 1].
function hexToHsv(hex) {
  var h = normHex(hex)
  var r = parseInt(h.substr(1, 2), 16) / 255
  var g = parseInt(h.substr(3, 2), 16) / 255
  var b = parseInt(h.substr(5, 2), 16) / 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
  var hue = 0
  if (d > 0) {
    if (max === r) hue = 60 * (((g - b) / d) % 6)
    else if (max === g) hue = 60 * ((b - r) / d + 2)
    else hue = 60 * ((r - g) / d + 4)
  }
  if (hue < 0) hue += 360
  return { h: hue, s: max === 0 ? 0 : d / max, v: max }
}

function hsvToHex(h, s, v) {
  var c = v * s
  var x = c * (1 - Math.abs(((h / 60) % 2) - 1))
  var m = v - c
  var rgb = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x]
    : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x]
  var out = "#"
  for (var i = 0; i < 3; i++) {
    var n = Math.round((rgb[i] + m) * 255)
    out += (n < 16 ? "0" : "") + n.toString(16)
  }
  return out
}

function parseJson(text, fallback) {
  try {
    var v = JSON.parse(String(text || ""))
    return v === null || v === undefined ? fallback : v
  } catch (e) {
    return fallback
  }
}

// devices.json + state.json + `rgbctl status` folded into one row per device.
function mergeDevices(config, state, status) {
  var list = (config && config.devices) || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    var s = (state && state[d.mac]) || {}
    var st = (status && status[d.mac]) || {}
    out.push({
      mac: d.mac,
      name: d.name || d.mac,
      order: d.order || "rgb",
      power: s.power === true,
      color: isHex(s.color || "") ? normHex(s.color) : "#ffffff",
      brightness: s.brightness === undefined ? 100 : s.brightness,
      effect: s.effect || "",
      speed: s.speed === undefined ? 50 : s.speed,
      connected: st.connected === true,
      present: st.present === true
    })
  }
  return out
}

function connectionLabel(dev) {
  if (!dev) return ""
  if (dev.connected) return "Connected"
  if (dev.present) return "In range, not connected"
  return "Not seen yet"
}
