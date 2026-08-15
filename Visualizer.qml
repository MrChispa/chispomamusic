import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Spectrum histogram driven by cava.
//
// cava reads the default audio sink monitor, so this reflects *system* audio
// rather than the selected MPRIS player specifically. There is no per-player
// spectrum available on Linux without capturing that stream directly, so this
// is deliberately a system-wide visualiser — see the README.
//
// The process only runs while `active` is true (panel open and playing), and
// the whole component quietly disappears when cava is not installed.
Item {
  id: root

  property bool active: false
  property int barCount: 20
  property color barColor: Color.accent
  property real minBarHeight: Math.max(2, Style.space(2))

  // Populated from cava frames, each value normalised to 0..1.
  property var levels: []
  readonly property bool hasSignal: levels.length > 0

  visible: hasSignal
  implicitHeight: Style.space(26)

  onActiveChanged: if (!active) levels = []

  Process {
    id: cava
    running: root.active

    // cava needs a config file, so write a fixed one under the runtime dir
    // (cleaned up by the system on logout) instead of leaking temp files.
    command: ["sh", "-c",
      "command -v cava >/dev/null 2>&1 || exit 127; " +
      "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/omamusic-cava.conf\"; " +
      "printf '%s\\n' '[general]' 'framerate = 30' 'bars = " + root.barCount + "' 'autosens = 1' " +
      "'[smoothing]' 'noise_reduction = 40' " +
      "'[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' " +
      "'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' > \"$cfg\"; " +
      "exec cava -p \"$cfg\""
    ]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var parts = line.split(";")
        var next = []
        for (var i = 0; i < parts.length; i++) {
          if (parts[i] === "") continue
          var value = parseInt(parts[i], 10)
          next.push(isNaN(value) ? 0 : Math.max(0, Math.min(1, value / 100)))
        }
        if (next.length > 0) root.levels = next
      }
    }
  }

  Row {
    id: bars
    anchors.fill: parent
    spacing: Math.max(1, Style.space(2))

    Repeater {
      model: root.levels.length

      Rectangle {
        width: Math.max(1, (bars.width - bars.spacing * (root.levels.length - 1)) / root.levels.length)
        height: Math.max(root.minBarHeight, root.levels[index] * bars.height)
        anchors.bottom: parent.bottom
        radius: width / 2
        color: root.barColor
        // Louder bands read as more present without changing the palette.
        opacity: 0.35 + 0.65 * root.levels[index]

        Behavior on height {
          NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
        }
      }
    }
  }
}
