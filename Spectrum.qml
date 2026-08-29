import QtQuick
import Quickshell.Io

// Shared audio-spectrum data source for the neon equalizers.
//
// Owns the single cava process; both the bar equalizer (BarVisualizer) and
// the popup histogram (Visualizer) read `levels` from here. cava reads the
// default audio sink monitor, so this reflects *system* audio rather than the
// selected MPRIS player specifically — there is no per-player spectrum
// available on Linux without capturing that stream directly.
//
// The cava process only runs while `active` is true and cava is installed.
// When cava is missing and `useCavaFallback` is set, a decorative idle
// animation fills `levels` while `active` so the equalizers still look alive
// — clearly synthetic, but never blank.
Item {
  id: root

  visible: false

  // True while any consumer wants spectrum data.
  property bool active: false
  // Number of bars the equalizers draw (must match cava's `bars` config).
  property int barCount: 9
  // Whether a synthetic idle animation may stand in when cava is absent.
  property bool useCavaFallback: true

  // One value per bar, normalised to 0..1. Cleared whenever the source stops.
  property var levels: []
  readonly property bool hasSignal: levels.length > 0

  // Detected once at startup; gates the real cava process.
  property bool cavaAvailable: false

  onActiveChanged: if (!root.active) root.levels = []
  onCavaAvailableChanged: if (root.active && root.cavaAvailable) root.levels = []

  // Presence probe, run once at startup.
  Process {
    id: cavaProbe
    command: ["sh", "-c", "command -v cava >/dev/null 2>&1 && echo yes || echo no"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.cavaAvailable = String(text || "").trim().toLowerCase() === "yes"
      }
    }
  }

  Process {
    id: cava
    running: root.active && root.cavaAvailable

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

  // Decorative fallback: smooth pseudo bars from a fixed sine-based formula,
  // so each band drifts at its own pace and the row looks alive.
  Timer {
    id: idleTimer
    interval: 90
    repeat: true
    triggeredOnStart: true
    running: root.active && !root.cavaAvailable && root.useCavaFallback
    onTriggered: root.levels = root.generateIdleLevels()
  }

  function generateIdleLevels() {
    var t = Date.now() / 1000
    var out = []
    for (var i = 0; i < root.barCount; i++) {
      var v = 0.22 + 0.30 * Math.sin(t * 2.1 + i * 0.85) + 0.18 * Math.sin(t * 4.7 + i * 0.35)
      out.push(Math.max(0.05, Math.min(1, v)))
    }
    return out
  }
}