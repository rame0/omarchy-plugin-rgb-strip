import QtQuick
import qs.Commons
import qs.Ui

// A rainbow track with a knob; the value is a hue in degrees.
Item {
  id: root

  property real hue: 0
  property real liveHue: hue
  property bool dragging: false
  property color knobBorder: Color.popups.background

  signal moved(real hue)
  signal released(real hue)

  onHueChanged: if (!dragging) liveHue = hue

  implicitWidth: Style.space(200)
  implicitHeight: Style.space(22)

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(10)
    radius: height / 2

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0 / 6; color: "#ff0000" }
      GradientStop { position: 1 / 6; color: "#ffff00" }
      GradientStop { position: 2 / 6; color: "#00ff00" }
      GradientStop { position: 3 / 6; color: "#00ffff" }
      GradientStop { position: 4 / 6; color: "#0000ff" }
      GradientStop { position: 5 / 6; color: "#ff00ff" }
      GradientStop { position: 6 / 6; color: "#ff0000" }
    }
  }

  BorderSurface {
    readonly property real size: Style.space(16)
    width: size
    height: size
    radius: size / 2
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(track.width - width, track.width * (root.liveHue / 360) - width / 2))
    color: Qt.hsva(root.liveHue / 360, 1, 1, 1)
    borderSpec: Border.flat(root.knobBorder, Math.max(1, Style.space(2)))
    scale: mouse.containsMouse || root.dragging ? 1.15 : 1

    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    function hueAt(x) {
      return Math.max(0, Math.min(359.9, x / track.width * 360))
    }

    onPressed: function (e) {
      root.dragging = true
      root.liveHue = hueAt(e.x)
      root.moved(root.liveHue)
    }
    onPositionChanged: function (e) {
      if (!root.dragging) return
      root.liveHue = hueAt(e.x)
      root.moved(root.liveHue)
    }
    onReleased: {
      root.dragging = false
      root.released(root.liveHue)
    }
    onWheel: function (e) {
      root.liveHue = (root.liveHue + (e.angleDelta.y > 0 ? 5 : -5) + 360) % 360
      root.moved(root.liveHue)
      root.released(root.liveHue)
    }
  }
}
