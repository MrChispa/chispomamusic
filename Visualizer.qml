import QtQuick
import QtQuick.Effects
import qs.Commons

// Neon histogram for the popup panel, driven by Spectrum's shared `levels`.
// Spectrum owns the cava process now — this component only renders.
Item {
  id: root

  property var levels: []
  property color neon: Color.accent
  property real minBarHeight: Math.max(2, Style.space(2))

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
    opacity: 0.15
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
        width: Math.max(1, (bars.width - bars.spacing * (root.levels.length - 1)) / root.levels.length)
        height: Math.max(root.minBarHeight, root.levels[index] * bars.height)
        anchors.bottom: parent.bottom
        radius: width / 2
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.lighter(root.neon, 1.3) }
          GradientStop { position: 1.0; color: Qt.darker(root.neon, 1.5) }
        }

        Behavior on height {
          NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
        }
      }
    }
  }
}