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
  // cava refuses an odd bar count with stereo output, so the config always
  // uses the nearest even number and the display adapts to whatever arrives.
  readonly property int cavaBarCount: Math.max(2, 2 * Math.floor(root.barCount / 2))
  // Whether a synthetic idle animation may stand in when cava is absent.
  property bool useCavaFallback: true

  // One value per bar, normalised to 0..1. Cleared whenever the source stops.
  property var levels: []
  readonly property bool hasSignal: levels.length > 0

  // Per-band smoothed state for the idle fallback, so it behaves like a real
  // spectrum analyzer (peaks hit and decay) instead of a canned wave.
  property var idleState: []

  // Detected once at startup; gates the real cava process.
  property bool cavaAvailable: false

  onActiveChanged: {
    if (!root.active) {
      root.levels = []
      root.idleState = []
    }
  }
  onCavaAvailableChanged: if (root.active && root.cavaAvailable) root.levels = []

  // Presence probe, run once at startup. Must be started explicitly: a
  // Quickshell Process with no `running` binding does not auto-start (the
  // original plugin's window-title probe is kicked off the same way).
  Process {
    id: cavaProbe
    running: true
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
      "printf '%s\\n' '[general]' 'framerate = 30' 'bars = " + root.cavaBarCount + "' 'autosens = 1' " +
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

  // Decorative fallback: per-band "peak and decay" random walk, so the row
  // looks like a real spectrum analyzer rather than a traveling wave. Random
  // bands get struck with a peak (neighbours echo it), and every band decays
  // toward a slowly breathing floor.
  Timer {
    id: idleTimer
    interval: 90
    repeat: true
    triggeredOnStart: true
    running: root.active && !root.cavaAvailable && root.useCavaFallback
    onTriggered: root.levels = root.generateIdleLevels()
  }

  function generateIdleLevels() {
    // Prime per-band state on first use.
    if (root.idleState.length !== root.barCount) {
      var seed = []
      for (var s = 0; s < root.barCount; s++) seed.push(0.03 + Math.random() * 0.12)
      root.idleState = seed
    }

    // Occasionally strike a random band; neighbours echo it, the way audio
    // peaks bleed into adjacent spectrum bins.
    if (Math.random() < 0.18) {
      var hit = Math.floor(Math.random() * root.barCount)
      root.idleState[hit] = Math.min(1, root.idleState[hit] + 0.55 + Math.random() * 0.45)
      if (hit > 0) root.idleState[hit - 1] = Math.min(1, root.idleState[hit - 1] + 0.28 + Math.random() * 0.15)
      if (hit < root.barCount - 1) root.idleState[hit + 1] = Math.min(1, root.idleState[hit + 1] + 0.28 + Math.random() * 0.15)
    }

    // Decay every band toward a low floor; the floor breathes a little so the
    // bottom is never dead-still.
    var t = Date.now() / 1000
    var floor = 0.04 + 0.02 * Math.sin(t * 1.7)
    var out = []
    for (var i = 0; i < root.barCount; i++) {
      var v = root.idleState[i] * 0.84 + floor * 0.16
      v = Math.max(0.02, Math.min(1, v))
      root.idleState[i] = v
      out.push(v)
    }
    return out
  }
}