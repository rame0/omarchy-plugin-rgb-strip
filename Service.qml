import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Everything that talks to rgbctl. The CLI owns the files; this only reads them
// back, so a keybinding that calls rgbctl directly shows up here too.
Item {
  id: service

  property bool polling: false
  property int pollInterval: 5

  readonly property string rgbctl: String(Qt.resolvedUrl("bin/rgbctl")).replace(/^file:\/\//, "")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

  property var config: ({ devices: [] })
  property var state: ({})
  property var status: ({})
  property var effects: []

  readonly property var devices: Model.mergeDevices(config, state, status)
  readonly property int onCount: devices.filter(function (d) { return d.power }).length

  property var scanResults: []
  property bool scanning: false
  property bool scanned: false

  property bool busy: false
  property string lastError: ""

  // Pending commands, oldest first. A new command with the same key replaces the
  // queued one, so a dragged slider sends its latest value and not every step.
  property var _queue: []

  function targetMacs(target) {
    if (target === "all") return devices.map(function (d) { return d.mac })
    return [target]
  }

  function devicesFor(target) {
    var macs = targetMacs(target)
    return devices.filter(function (d) { return macs.indexOf(d.mac) >= 0 })
  }

  function run(key, args) {
    var q = _queue.filter(function (e) { return key === "" || e.key !== key })
    q.push({ key: key, args: args })
    _queue = q
    _pump()
  }

  function _pump() {
    if (cmdProc.running || _queue.length === 0) return
    var next = _queue[0]
    _queue = _queue.slice(1)
    cmdProc.command = [rgbctl].concat(next.args)
    busy = true
    cmdProc.running = true
  }

  function anyOff(target) {
    return devicesFor(target).some(function (d) { return !d.power })
  }

  function setPower(target, on) { run("power:" + target, [on ? "on" : "off", target]) }
  function togglePower(target) { run("power:" + target, ["toggle", target]) }

  // Picking a color or an effect on a dark strip is a request to see it.
  function setColor(target, hex) {
    if (anyOff(target)) setPower(target, true)
    run("color:" + target, ["color", Model.normHex(hex).substr(1), target])
  }

  function setBrightness(target, value) {
    run("brightness:" + target, ["brightness", String(Math.round(Model.clamp(value, 0, 100))), target])
  }

  function setEffect(target, id) {
    if (anyOff(target)) setPower(target, true)
    run("effect:" + target, ["effect", id, target])
  }

  function setSpeed(target, value) {
    run("speed:" + target, ["speed", String(Math.round(Model.clamp(value, 0, 100))), target])
  }

  function restore(target) { run("", ["restore", target]) }
  function add(mac, name) { run("", ["add", mac, name]) }
  function remove(mac) { run("", ["remove", mac]) }
  function rename(mac, name) { run("rename:" + mac, ["rename", mac, name]) }
  function setOrder(mac, order) { run("order:" + mac, ["order", mac, order]) }

  function scan() {
    if (scanProc.running) return
    scanning = true
    scanProc.running = true
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  Component.onCompleted: {
    refreshStatus()
    effectsProc.running = true
  }

  Timer {
    interval: Math.max(2, service.pollInterval) * 1000
    running: service.polling
    repeat: true
    triggeredOnStart: true
    onTriggered: service.refreshStatus()
  }

  FileView {
    id: configFile
    path: service.configHome + "/omarchy-rgb/devices.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: service.config = Model.parseJson(text(), service.config)
  }

  FileView {
    id: stateFile
    path: service.stateHome + "/omarchy-rgb/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: service.state = Model.parseJson(text(), service.state)
  }

  Process {
    id: cmdProc
    running: false
    stderr: StdioCollector { id: cmdErr; waitForEnd: true }
    onExited: function (exitCode) {
      service.busy = false
      service.lastError = exitCode === 0 ? "" : (String(cmdErr.text || "").trim().split("\n").pop().replace(/^rgbctl: /, "") || "rgbctl failed")
      if (service._queue.length > 0) service._pump()
      else service.refreshStatus()
    }
  }

  Process {
    id: statusProc
    running: false
    command: [service.rgbctl, "status"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode !== 0) return
      service.status = Model.parseJson(statusOut.text, service.status)
      // The first run creates the files; the watchers may have started on nothing.
      configFile.reload()
      stateFile.reload()
    }
  }

  Process {
    id: scanProc
    running: false
    command: [service.rgbctl, "scan", "6"]
    stdout: StdioCollector { id: scanOut; waitForEnd: true }
    onExited: function (exitCode) {
      service.scanning = false
      service.scanned = true
      service.scanResults = exitCode === 0 ? Model.parseJson(scanOut.text, []) : []
    }
  }

  Process {
    id: effectsProc
    running: false
    command: [service.rgbctl, "effects"]
    stdout: StdioCollector { id: effectsOut; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode === 0) service.effects = Model.parseJson(effectsOut.text, [])
    }
  }
}
