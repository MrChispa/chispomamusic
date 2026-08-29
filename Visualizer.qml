import QtQuick
import QtQuick.Effects
import qs.Commons

// Neon histogram for the popup panel, driven by Spectrum's shared `levels`.
// Spectrum owns the cava process now — this component only renders.
//
// Theming matches BarVisualizer: a single `neon` color, or a `colors`
// palette cycled per bar, with `glowStrength` scaling the glow.
Item {
  id: root

  property var levels: []
  property color neon: Color.accent
  property var colors: []
  property real glowStrength: 1.0
  property real minBarHeight: Math.max(2, Style.space(2))

  function barColor(index) {
    if (root.colors && root.colors.length > 0) return root.colors[index % root.colors.length]
    return root.neon
  }

  visible: levels.length > 0
  implicitHeight: Style.space(26)

  // ONE glow behind the whole row — cheaper than per-bar glow at panel size.
  Rectangle {
    id: glow
    anchors.centerIn: parent
    width: bars.implicitWidth + Style.space(12)
    height: parent.height + Style.space(8)
    radius: height / 2
    color: root.neon
    opacity: 0.15 * root.glowStrength
    layer.enabled: true
    layer.samples: 4
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 64
    }
  }

  Row {
    id: bars
    anchors.fill: parent
    spacing: Math.max(1, Style.space(2))

    Repeater {
      model: root.levels.length

      Rectangle {
        required property int index
        width: Math.max(1, (bars.width - bars.spacing * (root.levels.length - 1)) / root.levels.length)
        height: Math.max(root.minBarHeight, root.levels[index] * bars.height)
        anchors.bottom: parent.bottom
        radius: width / 2
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.lighter(root.barColor(index), 1.3) }
          GradientStop { position: 1.0; color: Qt.darker(root.barColor(index), 1.5) }
        }

        Behavior on height {
          NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
        }
      }
    }
  }
}