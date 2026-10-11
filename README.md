# RGB Strips

An [Omarchy](https://omarchy.org) bar widget that controls cheap BLE RGB LED
strip controllers directly over Bluetooth, without the vendor phone app.

It targets the **ELK-BLEDOM** family (shows up as `ELK-BLEDOM`, `ELK-BLEDDM`,
`MELK`, …; phone apps duoCo Strip, Lotus Lantern and similar): any controller
that advertises GATT service `fff0` and takes 9-byte commands on `fff3`.

- power, color (presets, hue, saturation, hex), brightness
- built-in effects with speed
- several strips: control one or all at once
- scroll on the icon for brightness, right-click for power, middle-click to
  resend the last state (after the strip lost power or the IR remote changed it)

## Requirements

- Omarchy 4.x with `omarchy-shell`
- `bluez` and `bluez-utils` (`bluetoothctl`), `busctl` (systemd), `jq`

All of these are part of the stock Omarchy install, so there is nothing extra
to set up.

No pairing is needed. The phone app must not be connected at the same time:
these controllers accept one connection.

## Install

```bash
omarchy plugin add https://github.com/rame0/omarchy-plugin-rgb-strip.git --enable
```

Then open the widget, press the gear, then **Scan for strips**, and add yours.

## Command line

The widget drives the strips through `rgbctl`, a script that ships with the
plugin in `bin/rgbctl`. It is not installed system-wide; to use it from a
terminal, keybindings or hooks, put it on your `PATH`:

```bash
ln -s ~/.config/omarchy/plugins/rame0.rgb/bin/rgbctl ~/.local/bin/rgbctl
```

```bash
rgbctl scan                 # nearby controllers, JSON
rgbctl add BE:27:C3:00:F2:95 Desk
rgbctl on | off | toggle [target]
rgbctl color ff8800 [target]
rgbctl brightness 40 [target]
rgbctl effect fade-7 [target]   # rgbctl effects lists ids
rgbctl speed 70 [target]
```

`target` is a MAC, a device name, or `all` (default). Devices live in
`~/.config/omarchy-rgb/devices.json`, last known state in
`~/.local/state/omarchy-rgb/state.json`. The controllers cannot report their
state, so a change made with the IR remote is not seen here.

If colors come out swapped (red shows as green, say), change the channel order
for that strip in the widget, or `rgbctl order <mac> grb`.

## Protocol

| Command    | Bytes                          |
|------------|--------------------------------|
| power on   | `7e 00 04 f0 00 01 ff 00 ef`   |
| power off  | `7e 00 04 00 00 00 ff 00 ef`   |
| color      | `7e 00 05 03 RR GG BB 00 ef`   |
| brightness | `7e 00 01 VV 00 00 00 00 ef` (0–100) |
| effect     | `7e 00 03 MM 03 00 00 00 ef` (`effects.json`) |
| speed      | `7e 00 02 VV 00 00 00 00 ef` (0–100) |

## License

[MIT](LICENSE)
