import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Two views in one Column: the controls, and the device list with a scan.
KeyboardPanel {
  id: popup

  property var service: null
  property string target: "all"
  property bool devicesView: false

  signal targetRequested(string target)
  signal devicesRequested()
  signal backRequested()
  signal escapePressed()

  readonly property var devices: service ? service.devices : []
  readonly property var targeted: service ? service.devicesFor(target) : []
  readonly property var lead: targeted.length > 0 ? targeted[0] : null
  readonly property bool powered: targeted.some(function (d) { return d.power })

  readonly property string currentColor: lead ? lead.color : "#ffffff"
  readonly property string currentEffect: lead ? lead.effect : ""

  // Hue survives a trip through white, where the hex alone would reset it to red.
  property real hue: 0
  property real sat: 1
  onCurrentColorChanged: syncPicker()
  Component.onCompleted: syncPicker()

  function syncPicker() {
    var hsv = Model.hexToHsv(currentColor)
    if (hsv.s > 0) hue = hsv.h
    sat = hsv.s
  }

  function pick(h, s) {
    hue = h
    sat = s
    service.setColor(target, Model.hsvToHex(h, s, 1))
  }

  readonly property string fontFamily: popup.bar ? popup.bar.fontFamily : Style.font.family
  readonly property color foreground: Color.popups.text
  readonly property color urgent: popup.bar ? popup.bar.urgent : Color.urgent
  readonly property color dimText: Qt.darker(Color.popups.text, 1.4)

  contentWidth: popup.fittedContentWidth(Style.space(320))
  contentHeight: popup.fittedContentHeight(column.implicitHeight)
  focusTarget: keyCatcher

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    blocked: !keyCatcher.activeFocus

    onCloseRequested: popup.escapePressed()
    onActivateRequested: if (!popup.devicesView && popup.devices.length > 0) popup.service.togglePower(popup.target)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.spacing.md

      // ---- Header ------------------------------------------------------
      Item {
        width: parent.width
        implicitHeight: Math.max(title.implicitHeight, headerActions.implicitHeight)

        PanelActionButton {
          id: backButton
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          visible: popup.devicesView
          iconText: Model.Glyph.back
          tooltipText: "Back"
          foreground: popup.foreground
          fontFamily: popup.fontFamily
          onClicked: popup.backRequested()
        }

        Text {
          id: title
          anchors.left: backButton.visible ? backButton.right : parent.left
          anchors.leftMargin: backButton.visible ? Style.spacing.xs : 0
          anchors.right: headerActions.left
          anchors.rightMargin: Style.spacing.sm
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: popup.devicesView ? "Strips"
            : (popup.target === "all" ? (popup.devices.length === 1 ? popup.devices[0].name : "LED strips")
              : (popup.lead ? popup.lead.name : ""))
          color: popup.foreground
          font.family: popup.fontFamily
          font.pixelSize: Style.font.subtitle
        }

        Row {
          id: headerActions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: popup.devicesView
            enabled: !popup.service.scanning
            iconText: Model.Glyph.scan
            tooltipText: "Scan for strips"
            foreground: popup.foreground
            fontFamily: popup.fontFamily
            onClicked: popup.service.scan()
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !popup.devicesView
            iconText: Model.Glyph.devices
            tooltipText: "Strips"
            foreground: popup.foreground
            fontFamily: popup.fontFamily
            onClicked: popup.devicesRequested()
          }

          ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            visible: !popup.devicesView && popup.devices.length > 0
            checked: popup.powered
            foreground: popup.foreground
            cursorRing: false
            onToggled: popup.service.setPower(popup.target, !popup.powered)
          }
        }
      }

      // ---- Controls ----------------------------------------------------
      Text {
        width: parent.width
        visible: !popup.devicesView && popup.devices.length > 0
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: popup.targeted.length === 1
          ? Model.connectionLabel(popup.lead)
          : popup.targeted.filter(function (d) { return d.connected }).length + " of " + popup.targeted.length + " connected"
        color: popup.dimText
        font.family: popup.fontFamily
        font.pixelSize: Style.font.caption
      }

      Dropdown {
        width: parent.width
        visible: !popup.devicesView && popup.devices.length > 1
        showLabel: false
        value: popup.target
        options: [{ value: "all", label: "All strips" }].concat(popup.devices.map(function (d) {
          return { value: d.mac, label: d.name }
        }))
        foreground: popup.foreground
        fontFamily: popup.fontFamily
        onChanged: function (value) { popup.targetRequested(value) }
      }

      Column {
        width: parent.width
        visible: !popup.devicesView && popup.devices.length === 0
        spacing: Style.spacing.md

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "No strips added yet."
          color: popup.foreground
          opacity: 0.7
          font.family: popup.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Button {
          text: "Find strips"
          iconText: Model.Glyph.scan
          foreground: popup.foreground
          fontFamily: popup.fontFamily
          bordered: true
          onClicked: {
            popup.devicesRequested()
            popup.service.scan()
          }
        }
      }

      Column {
        width: parent.width
        visible: !popup.devicesView && popup.devices.length > 0
        spacing: Style.spacing.md

        PanelSeparator { foreground: popup.foreground }

        PanelSectionHeader {
          text: "Color"
          foreground: popup.foreground
          fontFamily: popup.fontFamily
        }

        Row {
          id: swatches
          width: parent.width
          readonly property int count: Model.PRESETS.length
          readonly property real size: Math.floor((width - spacing * (count - 1)) / count)
          spacing: Style.spacing.sm

          Repeater {
            model: Model.PRESETS

            Rectangle {
              required property string modelData
              readonly property bool current: popup.currentEffect === "" && popup.currentColor === modelData
              width: swatches.size
              height: swatches.size
              radius: Style.cornerRadius > 0 ? width / 2 : 0
              color: modelData
              border.width: current || swatchMouse.containsMouse ? Math.max(2, Style.space(2)) : 1
              border.color: current ? popup.foreground : Qt.rgba(popup.foreground.r, popup.foreground.g, popup.foreground.b, 0.3)

              MouseArea {
                id: swatchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: popup.service.setColor(popup.target, modelData)
              }
            }
          }
        }

        HueBar {
          width: parent.width
          hue: popup.hue
          knobBorder: Color.popups.background
          onMoved: function (h) { popup.pick(h, popup.sat) }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.md

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(64)
            textFormat: Text.PlainText
            text: "Saturation"
            color: popup.dimText
            font.family: popup.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(64) - parent.spacing
            minimum: 0
            maximum: 100
            step: 5
            integer: true
            value: Math.round(popup.sat * 100)
            fillColor: popup.currentColor
            knobColor: popup.currentColor
            trackColor: Qt.rgba(popup.foreground.r, popup.foreground.g, popup.foreground.b, 0.18)
            onMoved: function (v) { popup.pick(popup.hue, v / 100) }
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.md

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: hexField.height
            height: hexField.height
            radius: Style.cornerRadius
            color: popup.currentColor
            border.width: 1
            border.color: Qt.rgba(popup.foreground.r, popup.foreground.g, popup.foreground.b, 0.3)
          }

          TextField {
            id: hexField
            width: parent.width - height - parent.spacing
            text: popup.currentColor
            foreground: popup.foreground
            font.family: popup.fontFamily
            onAccepted: {
              if (Model.isHex(text)) popup.service.setColor(popup.target, text)
              else text = popup.currentColor
              keyCatcher.forceActiveFocus()
            }
            Keys.onEscapePressed: {
              text = popup.currentColor
              keyCatcher.forceActiveFocus()
            }
          }
        }

        PanelSeparator { foreground: popup.foreground }

        PanelSectionHeader {
          text: "Brightness"
          foreground: popup.foreground
          fontFamily: popup.fontFamily
        }

        PanelSlider {
          width: parent.width
          minimum: 0
          maximum: 100
          step: 5
          integer: true
          value: popup.lead ? popup.lead.brightness : 100
          fillColor: popup.foreground
          knobColor: popup.foreground
          trackColor: Qt.rgba(popup.foreground.r, popup.foreground.g, popup.foreground.b, 0.18)
          onMoved: function (v) { popup.service.setBrightness(popup.target, v) }
        }

        PanelSeparator { foreground: popup.foreground }

        PanelSectionHeader {
          text: "Effect"
          foreground: popup.foreground
          fontFamily: popup.fontFamily
        }

        Dropdown {
          width: parent.width
          showLabel: false
          value: popup.currentEffect
          options: [{ value: "", label: "Solid color" }].concat(popup.service.effects.map(function (e) {
            return { value: e.id, label: e.label }
          }))
          foreground: popup.foreground
          fontFamily: popup.fontFamily
          onChanged: function (value) {
            if (value === "") popup.service.setColor(popup.target, popup.currentColor)
            else popup.service.setEffect(popup.target, value)
          }
        }

        Row {
          width: parent.width
          visible: popup.currentEffect !== ""
          spacing: Style.spacing.md

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(64)
            textFormat: Text.PlainText
            text: "Speed"
            color: popup.dimText
            font.family: popup.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(64) - parent.spacing
            minimum: 0
            maximum: 100
            step: 5
            integer: true
            value: popup.lead ? popup.lead.speed : 50
            fillColor: popup.foreground
            knobColor: popup.foreground
            trackColor: Qt.rgba(popup.foreground.r, popup.foreground.g, popup.foreground.b, 0.18)
            onMoved: function (v) { popup.service.setSpeed(popup.target, v) }
          }
        }
      }

      // ---- Devices -----------------------------------------------------
      Column {
        width: parent.width
        visible: popup.devicesView
        spacing: Style.spacing.md

        Repeater {
          model: popup.devicesView ? popup.devices : []

          Column {
            required property var modelData
            width: parent.width
            spacing: Style.spacing.xs

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              TextField {
                id: nameField
                width: parent.width - orderBox.width - removeButton.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                foreground: popup.foreground
                font.family: popup.fontFamily
                onAccepted: {
                  if (text.trim() !== "" && text.trim() !== modelData.name) popup.service.rename(modelData.mac, text.trim())
                  keyCatcher.forceActiveFocus()
                }
                Keys.onEscapePressed: {
                  text = modelData.name
                  keyCatcher.forceActiveFocus()
                }
              }

              Dropdown {
                id: orderBox
                width: Style.space(72)
                anchors.verticalCenter: parent.verticalCenter
                showLabel: false
                value: modelData.order
                options: Model.ORDERS.map(function (o) { return { value: o, label: o.toUpperCase() } })
                foreground: popup.foreground
                fontFamily: popup.fontFamily
                onChanged: function (value) { popup.service.setOrder(modelData.mac, value) }
              }

              PanelActionButton {
                id: removeButton
                anchors.verticalCenter: parent.verticalCenter
                iconText: Model.Glyph.remove
                tooltipText: "Remove"
                foreground: popup.foreground
                fontFamily: popup.fontFamily
                onClicked: popup.service.remove(modelData.mac)
              }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              elide: Text.ElideRight
              text: modelData.mac + "  ·  " + Model.connectionLabel(modelData)
              color: popup.dimText
              font.family: popup.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Text {
          width: parent.width
          visible: popup.devices.length > 0
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Channel order: switch it if red shows up as another color."
          color: popup.dimText
          font.family: popup.fontFamily
          font.pixelSize: Style.font.caption
        }

        PanelSeparator { foreground: popup.foreground }

        PanelSectionHeader {
          text: "Nearby"
          foreground: popup.foreground
          fontFamily: popup.fontFamily
        }

        Text {
          width: parent.width
          visible: popup.service.scanning || !popup.service.scanned || popup.service.scanResults.length === 0
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: popup.service.scanning ? "Scanning…"
            : (popup.service.scanned ? "No controllers found. Make sure the phone app is not connected to it."
              : "Press scan to look for controllers.")
          color: popup.foreground
          opacity: 0.7
          font.family: popup.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Repeater {
          model: popup.devicesView && !popup.service.scanning ? popup.service.scanResults : []

          Item {
            required property var modelData
            readonly property bool added: popup.devices.some(function (d) { return d.mac === modelData.mac })
            width: parent.width
            implicitHeight: Math.max(found.implicitHeight, addButton.implicitHeight)

            Column {
              id: found
              anchors.left: parent.left
              anchors.right: addButton.left
              anchors.rightMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: parent.width
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: modelData.name
                color: popup.foreground
                font.family: popup.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.mac
                color: popup.dimText
                font.family: popup.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              id: addButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              enabled: !parent.added
              text: parent.added ? "Added" : "Add"
              iconText: parent.added ? "" : Model.Glyph.add
              foreground: popup.foreground
              fontFamily: popup.fontFamily
              bordered: true
              onClicked: popup.service.add(modelData.mac, modelData.name)
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: popup.service.lastError
        color: popup.urgent
        font.family: popup.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
