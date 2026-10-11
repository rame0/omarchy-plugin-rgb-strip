import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// BLE LED strip controllers in the bar, driven through bin/rgbctl.
BarWidget {
  id: root
  moduleName: "rame0.rgb"

  // opened/open()/close() are how the shell routes summon/hide/toggle — keep the names.
  property bool popupOpen: false
  property bool devicesView: false
  property string target: "all"

  readonly property bool opened: popupOpen
  readonly property bool anyOn: service.onCount > 0
  readonly property var lead: service.devices.length > 0 ? service.devices[0] : null
  readonly property int wheelStep: Math.max(1, setting("wheelStep", 10))

  // A selected strip that was removed falls back to all of them.
  readonly property string liveTarget: target === "all" || service.devices.some(function (d) { return d.mac === target })
    ? target : "all"

  function open() {
    popupOpen = true
    service.refreshStatus()
  }

  function close() {
    popupOpen = false
    devicesView = false
  }

  function togglePanel() {
    if (popupOpen) close()
    else open()
  }

  function refresh() { service.refreshStatus() }

  Service {
    id: service
    polling: root.popupOpen
    pollInterval: root.setting("pollInterval", 5)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.anyOn ? Model.Glyph.on : Model.Glyph.off
    active: root.popupOpen
    useActiveColor: false
    // The glyph wears the strip's color while it shows a solid one.
    foreground: root.anyOn && root.setting("tintIcon", true) && root.lead && root.lead.power && root.lead.effect === ""
      ? root.lead.color
      : (root.bar ? root.bar.barForeground : Color.foreground)
    dimmed: !root.anyOn
    tooltipText: service.devices.length === 0 ? "LED strips: none added"
      : service.devices.map(function (d) { return d.name + ": " + (d.power ? "on" : "off") }).join("\n")
    fixedWidth: root.vertical ? root.barSize : -1
    fixedHeight: root.vertical ? root.barSize : -1

    onPressed: function (mouseButton) {
      if (mouseButton === Qt.RightButton) {
        if (service.devices.length > 0) service.togglePower("all")
        return
      }
      if (mouseButton === Qt.MiddleButton) {
        if (service.devices.length > 0) service.restore("all")
        return
      }
      root.togglePanel()
    }

    onWheelMoved: function (delta) {
      if (!root.lead) return
      var next = Model.clamp(root.lead.brightness + (delta > 0 ? root.wheelStep : -root.wheelStep), 0, 100)
      service.setBrightness(root.liveTarget, next)
    }
  }

  Popup {
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen

    service: service
    target: root.liveTarget
    devicesView: root.devicesView

    onTargetRequested: function (t) { root.target = t }
    onDevicesRequested: root.devicesView = true
    onBackRequested: root.devicesView = false
    onEscapePressed: {
      if (root.devicesView) root.devicesView = false
      else root.close()
    }
  }

  IpcHandler {
    target: "rame0.rgb"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }
}
